import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_download.dart';
import '../../../praise/domain/chord.dart';
import '../../../praise/domain/chord_shapes.dart';
import '../../../praise/domain/chordpro.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'providers/praise_providers.dart';
import 'widgets/chord_diagram.dart';
import 'widgets/chordpro_view.dart';
import 'widgets/reader_fullscreen.dart';
import 'widgets/reader_tools.dart';

/// Leitor de cifra — tela interna, não aba
/// (`/ministries/:id/louvores/musicas/:songId`).
///
/// Trocar o tom aqui é só para tocar: transpõe na tela e não grava nada.
/// Versão nova só nasce no editor, de propósito.
class PraiseSongReaderScreen extends StatelessWidget {
  final String ministryId;
  final String songId;

  const PraiseSongReaderScreen({
    super.key,
    required this.ministryId,
    required this.songId,
  });

  @override
  Widget build(BuildContext context) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) => _Reader(ministryId: ministryId, songId: songId),
    );
  }
}

/// Leitor de uma música do repertório, no tom do item (canvas, tela 9):
/// `/ministries/:id/louvores/repertorios/:setlistId/itens/:itemId`.
/// Mexer no tom aqui também vale só na tela.
///
/// [received]: o mesmo leitor para o ministério destinatário
/// (`.../louvores/recebidos/...`, tela 12b). [ministryId] é o dele.
class PraiseSetlistItemReaderScreen extends ConsumerWidget {
  final String ministryId;
  final String setlistId;
  final String itemId;
  final bool received;

  const PraiseSetlistItemReaderScreen({
    super.key,
    required this.ministryId,
    required this.setlistId,
    required this.itemId,
    this.received = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) {
        final setlist = ref.watch(praiseSetlistProvider(setlistId));
        final s = setlist.valueOrNull;
        final rev = [s?.published, s?.draft]
            .where((r) => r?.items.any((i) => i.id == itemId) ?? false)
            .firstOrNull;
        if (rev == null) {
          return Scaffold(
            appBar: AppBar(),
            body: setlist.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const PraiseMessage(
                    title: 'Música fora do repertório',
                    message: 'O repertório mudou ou você não tem acesso.',
                  ),
          );
        }
        final index = rev.items.indexWhere((i) => i.id == itemId);
        return _Reader(
          // Trocar de item recria o estado (tom e versão do novo item).
          key: ValueKey(itemId),
          ministryId: ministryId,
          songId: rev.items[index].version.songId,
          reading: (
            base:
                '/ministries/$ministryId/louvores/'
                '${received ? 'recebidos' : 'repertorios'}/$setlistId',
            revision: rev,
            index: index,
          ),
        );
      },
    );
  }
}

/// [base] = rota do repertório (do dono ou do recebido).
typedef _SetlistReading = ({
  String base,
  PraiseSetlistRevision revision,
  int index,
});

class _Reader extends ConsumerStatefulWidget {
  final String ministryId;
  final String songId;
  final _SetlistReading? reading;

  const _Reader({
    super.key,
    required this.ministryId,
    required this.songId,
    this.reading,
  });

  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

class _ReaderState extends ConsumerState<_Reader>
    with SingleTickerProviderStateMixin {
  /// Seção no player (índice de [chordProSections]); nulo = fechado.
  int? _playingSection;
  List<GlobalKey> _sectionKeys = const [];

  int _semitones = 0;
  double _fontSize = 15;

  /// Preferência do aparelho (plano §12.4), não da música nem do repertório.
  PraiseInstrument _instrument = PraiseInstrument.violao;
  static const _instrumentPref = 'praise_reader_instrument';

  /// Baixo de 4 ou 5 cordas: o chip "Baixo" volta sempre no último escolhido.
  PraiseInstrument _bass = PraiseInstrument.baixo;
  static const _bassPref = 'praise_reader_bass';

  /// "Dividir em colunas" do CifraClub: escolha do usuário, salva no aparelho.
  bool _twoColumns = false;
  static const _columnsPref = 'praise_reader_two_columns';

  /// Quantas colunas (2 ou 3) e largura do texto (% da tela, print 05).
  int _columnCount = 2;
  double _textWidth = 1;
  static const _layoutPref = 'praise_reader_layout';

  /// Simplificada (C7M → C) e blocos de tablatura.
  bool _simplified = false;
  bool _showTabs = true;
  static const _simplifiedPref = 'praise_reader_simplified';
  static const _tabsPref = 'praise_reader_tabs';

  /// Tema só do leitor: nulo = o do app.
  Brightness? _theme;
  static const _themePref = 'praise_reader_theme';

  /// Afinação (semitons abaixo da padrão) do violão e do baixo, também do
  /// aparelho. Uma só: cada pessoa usa um instrumento no próprio celular.
  int _tuningDrop = 0;
  static const _tuningPref = 'praise_reader_tuning_drop';

  /// Faixa de diagramas (print 10): no início, no fim, tamanho, fixa no
  /// topo ao rolar e "no corpo da cifra" (com tamanho próprio).
  bool _diagramsStart = true;
  bool _diagramsEnd = false;
  double _diagramScale = 1;
  bool _diagramsPinned = false;
  bool _diagramsInline = false;
  double _inlineScale = 1;
  static const _diagramsPref = 'praise_reader_diagrams';

  /// Batidas (print 12): sempre, nunca ou só a da seção na tela.
  StrumDisplay _strums = StrumDisplay.always;
  static const _strumsPref = 'praise_reader_strums';

  /// Uma chave por `{batida}` da cifra, para saber qual está no topo.
  List<GlobalKey> _strumKeys = const [];
  int _currentStrum = -1;
  final _scroll = ScrollController();
  final _listKey = GlobalKey();

  /// "Só letra": sem acordes, diagramas nem batidas — para a Mídia projetar
  /// e para quem canta. Preferência do aparelho.
  bool _lyricsOnly = false;
  static const _lyricsOnlyPref = 'praise_reader_lyrics_only';

  /// Tela cheia: sem barra do app nem navegação do repertório.
  bool _fullscreen = false;

  /// Capo só desta tela. Nulo = o do repertório ou da versão.
  int? _capoOverride;

  bool _metronome = false;
  bool _tuner = false;

  /// Rolagem automática (contrato do leitor §8): para ao tocar na cifra.
  /// A velocidade (1–10) é do aparelho; em linhas por segundo, então não
  /// muda com o tamanho da letra.
  late final Ticker _autoScroll = createTicker(_autoTick);
  Duration _autoLast = Duration.zero;
  int _autoSpeed = 3;
  static const _autoSpeedPref = 'praise_reader_scroll_speed';

  /// Nulo = a versão mais recente.
  PraiseSongVersion? _picked;

  PraiseSetlistItem? get _item {
    final r = widget.reading;
    return r == null ? null : r.revision.items[r.index];
  }

  @override
  void initState() {
    super.initState();
    _loadInstrument();
    _scroll.addListener(_trackStrum);
    rememberRecentSong(widget.songId);
    final item = _item;
    if (item != null) {
      // A versão e o tom do repertório, não os da biblioteca.
      _picked = item.version;
      final from = item.version.originalKey;
      if (from != null &&
          item.selectedKey != null &&
          Chord.tryParse(from) != null) {
        _semitones = Chord.interval(from, item.selectedKey!);
      }
    }
  }

  @override
  void dispose() {
    if (_autoScroll.isActive) WakelockPlus.disable().ignore();
    _autoScroll.dispose();
    _scroll.dispose();
    if (_fullscreen) setReaderFullscreen(false);
    super.dispose();
  }

  void _autoTick(Duration elapsed) {
    final dt = (elapsed - _autoLast).inMicroseconds / 1e6;
    _autoLast = elapsed;
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent) return _setAutoScroll(false);
    final step = _autoSpeed * 0.15 * _fontSize * 1.35 * dt;
    _scroll.jumpTo(math.min(p.pixels + step, p.maxScrollExtent));
  }

  void _setAutoScroll(bool on) {
    if (on == _autoScroll.isActive) return;
    if (on) {
      _autoLast = Duration.zero;
      _autoScroll.start();
    } else {
      _autoScroll.stop();
    }
    // Tela acesa só enquanto rola: no palco ninguém toca no celular.
    WakelockPlus.toggle(enable: on).ignore();
    if (mounted) setState(() {});
  }

  /// Pedal bluetooth e teclado: o pedal manda tecla (seta ou PageDown).
  /// ↓/PageDown e ↑/PageUp viram uma tela; → e ← trocam de música no
  /// repertório (fora dele, também viram uma tela); espaço liga a rolagem.
  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + direction * p.viewportDimension * 0.8).clamp(
        0,
        p.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _step(int delta) {
    final r = widget.reading;
    if (r == null) return _page(delta);
    final i = r.index + delta;
    if (i < 0 || i >= r.revision.items.length) return;
    context.pushReplacement('${r.base}/itens/${r.revision.items[i].id}');
  }

  late final _keys = <ShortcutActivator, VoidCallback>{
    const SingleActivator(LogicalKeyboardKey.pageDown): () => _page(1),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () => _page(1),
    const SingleActivator(LogicalKeyboardKey.pageUp): () => _page(-1),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => _page(-1),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
    const SingleActivator(LogicalKeyboardKey.space): () =>
        _setAutoScroll(!_autoScroll.isActive),
  };

  void _setAutoSpeed(int v) {
    setState(() => _autoSpeed = v);
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_autoSpeedPref, v))
        .ignore();
  }

  void _setFullscreen(bool on) {
    setState(() => _fullscreen = on);
    setReaderFullscreen(on);
  }

  /// A batida "atual" é a última cujo lugar já passou do primeiro terço da
  /// tela.
  void _trackStrum() {
    if (_strums != StrumDisplay.current || !mounted) return;
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (list == null || !list.attached) return;
    final line = list.localToGlobal(Offset.zero).dy + list.size.height / 3;
    var current = -1;
    for (final (i, k) in _strumKeys.indexed) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.attached &&
          box.localToGlobal(Offset.zero).dy <= line) {
        current = i;
      }
    }
    if (current != _currentStrum) setState(() => _currentStrum = current);
  }

  Future<void> _loadInstrument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_instrumentPref);
      final saved = PraiseInstrument.values.where((i) => i.name == name);
      final layout = prefs.getStringList(_layoutPref);
      final theme = prefs.getString(_themePref);
      final bass = prefs.getString(_bassPref);
      final diagrams = prefs.getStringList(_diagramsPref);
      if (!mounted) return;
      setState(() {
        if (saved.isNotEmpty) _instrument = saved.first;
        if (bass == PraiseInstrument.baixo5.name) {
          _bass = PraiseInstrument.baixo5;
        }
        _twoColumns = prefs.getBool(_columnsPref) ?? false;
        _lyricsOnly = prefs.getBool(_lyricsOnlyPref) ?? false;
        _simplified = prefs.getBool(_simplifiedPref) ?? false;
        _showTabs = prefs.getBool(_tabsPref) ?? true;
        _theme = Brightness.values.where((b) => b.name == theme).firstOrNull;
        if (layout != null && layout.length >= 2) {
          _columnCount = (int.tryParse(layout[0]) ?? 2).clamp(2, 3);
          _textWidth = (double.tryParse(layout[1]) ?? 1).clamp(0.5, 1.0);
        }
        _tuningDrop = (prefs.getInt(_tuningPref) ?? 0).clamp(0, 4);
        _autoSpeed = (prefs.getInt(_autoSpeedPref) ?? 3).clamp(1, 10);
        if (diagrams != null && diagrams.length >= 3) {
          _diagramsStart = diagrams[0] == 'true';
          _diagramsEnd = diagrams[1] == 'true';
          _diagramScale = (double.tryParse(diagrams[2]) ?? 1).clamp(0.7, 1.6);
        }
        // Até a B2.2 a lista tinha só os 3 primeiros.
        if (diagrams != null && diagrams.length >= 6) {
          _diagramsPinned = diagrams[3] == 'true';
          _diagramsInline = diagrams[4] == 'true';
          _inlineScale = (double.tryParse(diagrams[5]) ?? 1).clamp(0.7, 1.6);
        }
        _strums = StrumDisplay.values.firstWhere(
          (s) => s.name == prefs.getString(_strumsPref),
          orElse: () => StrumDisplay.always,
        );
      });
    } catch (_) {
      // Sem preferência salva o leitor fica no violão.
    }
  }

  /// Devolve o instrumento de fato (o chip "Baixo" vira o de 4/5 salvo).
  PraiseInstrument _setInstrument(PraiseInstrument chip) {
    final i = chip.isBass ? _bass : chip;
    setState(() => _instrument = i);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_instrumentPref, i.name))
        .ignore();
    return i;
  }

  void _setBass(PraiseInstrument bass) {
    _bass = bass;
    _setInstrument(bass);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_bassPref, bass.name))
        .ignore();
  }

  void _setTwoColumns(bool v) {
    setState(() => _twoColumns = v);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_columnsPref, v))
        .ignore();
  }

  void _setLyricsOnly(bool v) {
    setState(() => _lyricsOnly = v);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_lyricsOnlyPref, v))
        .ignore();
  }

  void _savePrefs() {
    SharedPreferences.getInstance().then((p) async {
      await p.setInt(_tuningPref, _tuningDrop);
      await p.setStringList(_diagramsPref, [
        '$_diagramsStart',
        '$_diagramsEnd',
        '$_diagramScale',
        '$_diagramsPinned',
        '$_diagramsInline',
        '$_inlineScale',
      ]);
      await p.setString(_strumsPref, _strums.name);
      await p.setBool(_simplifiedPref, _simplified);
      await p.setBool(_tabsPref, _showTabs);
      await p.setStringList(_layoutPref, ['$_columnCount', '$_textWidth']);
      if (_theme == null) {
        await p.remove(_themePref);
      } else {
        await p.setString(_themePref, _theme!.name);
      }
    }).ignore();
  }

  /// "Restaurar padrões" (§1.5 item 16): apaga as preferências do leitor
  /// neste aparelho e volta tudo ao começo. Tom e capo desta tela ficam.
  Future<void> _resetPrefs() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('praise_reader_'))) {
      await p.remove(k);
    }
    _setAutoScroll(false);
    if (_fullscreen) _setFullscreen(false);
    if (!mounted) return;
    setState(() {
      _instrument = PraiseInstrument.violao;
      _bass = PraiseInstrument.baixo;
      _twoColumns = false;
      _columnCount = 2;
      _textWidth = 1;
      _simplified = false;
      _showTabs = true;
      _theme = null;
      _tuningDrop = 0;
      _diagramsStart = true;
      _diagramsEnd = false;
      _diagramScale = 1;
      _diagramsPinned = false;
      _diagramsInline = false;
      _inlineScale = 1;
      _strums = StrumDisplay.always;
      _lyricsOnly = false;
      _autoSpeed = 3;
      _fontSize = 15;
    });
  }

  /// O texto da versão, como está gravado (ChordPro).
  Future<void> _copy(PraiseSongVersion v) async {
    await Clipboard.setData(ClipboardData(text: v.chordpro));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cifra copiada.')));
    }
  }

  /// Arquivo `.cho` (ChordPro), que outros apps de cifra abrem.
  void _export(String title, PraiseSongVersion v) {
    final name = '${title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim()}.cho';
    final text = v.chordpro.contains(RegExp(r'\{\s*(t|title)\s*:'))
        ? v.chordpro
        : '{title: $title}\n${v.chordpro}';
    if (kIsWeb) {
      downloadText(name, text);
    } else {
      Share.share(text, subject: title).ignore();
    }
  }

  /// Desenho que soa como [chord] com o capo e a afinação da tela. O capo
  /// vale para o violão, não para o baixo (baixista toca a nota que soa).
  Chord _shapeOf(Chord chord, PraiseInstrument i, int capo) => i.tuning == null
      ? chord
      : shapeChord(chord, drop: _tuningDrop, capo: i.isBass ? 0 : capo);

  void _openChord(Chord chord, int capo) => showChordSheet(
    context,
    chord: chord,
    instrument: _instrument,
    onInstrument: _setInstrument,
    shapeOf: (c, i) => _shapeOf(c, i, capo),
  );

  /// Ajustes do leitor em cartões, como o menu lateral do CifraClub (prints
  /// 01/02). Tudo vale na hora; só o capo é desta música.
  void _openSettings(int capo) {
    final wide =
        MediaQuery.sizeOf(context).width >= ChordProView.twoColumnWidth;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void set(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          Widget card(String title, List<Widget> children) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CommunityDesign.titleStyle(context)),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          );

          SwitchListTile toggle(
            String label,
            bool value,
            ValueChanged<bool> onChanged,
          ) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: value,
            onChanged: onChanged,
          );

          Widget sizeSlider(
            double value,
            ValueChanged<double> onChanged, {
            String label = 'Tamanho',
            double min = 0.7,
            double max = 1.6,
          }) => Row(
            children: [
              Text(label),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: ((max - min) * 10).round(),
                  label: '${(value * 100).round()}%',
                  onChanged: onChanged,
                  onChangeEnd: (_) => _savePrefs(),
                ),
              ),
            ],
          );

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  card('Instrumento', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in [
                          ...PraiseInstrument.pickable,
                          PraiseInstrument.bateria,
                        ])
                          ChoiceChip(
                            shape: const StadiumBorder(),
                            label: Text(i.label),
                            selected: i == _instrument.chip,
                            onSelected: (_) {
                              _setInstrument(i);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                    if (_instrument.tuning != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('tuning-${_instrument.isBass}'),
                        initialValue: _tuningDrop,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Afinação',
                        ),
                        items: [
                          for (final t in praiseTunings)
                            DropdownMenuItem(
                              value: t.drop,
                              child: Text(
                                _instrument.isBass ? t.bassLabel : t.label,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          set(() => _tuningDrop = v ?? 0);
                          _savePrefs();
                        },
                      ),
                    ],
                    if (_instrument.isBass) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<PraiseInstrument>(
                        segments: const [
                          ButtonSegment(
                            value: PraiseInstrument.baixo,
                            label: Text('4 cordas'),
                          ),
                          ButtonSegment(
                            value: PraiseInstrument.baixo5,
                            label: Text('5 cordas'),
                          ),
                        ],
                        selected: {_instrument},
                        onSelectionChanged: (v) {
                          _setBass(v.first);
                          setSheet(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'O desenho mostra a nota do baixo de cada acorde '
                        '(em D/F#, o F#).',
                        style: CommunityDesign.metaStyle(context),
                      ),
                    ],
                    if (_instrument.tuning != null && !_instrument.isBass) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _capoOverride ?? capo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Capotraste',
                          helperText: 'Muda o desenho; o som continua no tom.',
                        ),
                        items: [
                          for (var c = 0; c <= 11; c++)
                            DropdownMenuItem(
                              value: c,
                              child: Text(
                                c == 0 ? 'Sem capotraste' : '$cª casa',
                              ),
                            ),
                        ],
                        onChanged: (v) => set(() => _capoOverride = v),
                      ),
                    ],
                  ]),
                  card('Diagramas', [
                    toggle('No início', _diagramsStart, (v) {
                      set(() => _diagramsStart = v);
                      _savePrefs();
                    }),
                    toggle('No fim', _diagramsEnd, (v) {
                      set(() => _diagramsEnd = v);
                      _savePrefs();
                    }),
                    toggle('Fixar no topo ao rolar', _diagramsPinned, (v) {
                      set(() => _diagramsPinned = v);
                      _savePrefs();
                    }),
                    sizeSlider(
                      _diagramScale,
                      (v) => set(() => _diagramScale = v),
                    ),
                    toggle('No corpo da cifra', _diagramsInline, (v) {
                      set(() => _diagramsInline = v);
                      _savePrefs();
                    }),
                    if (_diagramsInline)
                      sizeSlider(
                        _inlineScale,
                        (v) => set(() => _inlineScale = v),
                        label: 'Tamanho no corpo',
                      ),
                  ]),
                  card('Batidas', [
                    RadioGroup<StrumDisplay>(
                      groupValue: _strums,
                      onChanged: (v) {
                        set(() => _strums = v ?? _strums);
                        _savePrefs();
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _trackStrum(),
                        );
                      },
                      child: Column(
                        children: [
                          for (final s in StrumDisplay.values)
                            RadioListTile<StrumDisplay>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(s.label),
                              value: s,
                            ),
                        ],
                      ),
                    ),
                  ]),
                  card('Exibição', [
                    toggle('Tela cheia', _fullscreen, (v) {
                      _setFullscreen(v);
                      setSheet(() {});
                    }),
                    toggle('Mostrar tablaturas', _showTabs, (v) {
                      set(() => _showTabs = v);
                      _savePrefs();
                    }),
                    const SizedBox(height: 8),
                    const Text('Tema do leitor'),
                    const SizedBox(height: 6),
                    SegmentedButton<Brightness?>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: null, label: Text('Do app')),
                        ButtonSegment(
                          value: Brightness.light,
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: Brightness.dark,
                          label: Text('Escuro'),
                        ),
                      ],
                      selected: {_theme},
                      onSelectionChanged: (v) {
                        set(() => _theme = v.first);
                        _savePrefs();
                      },
                    ),
                    const SizedBox(height: 8),
                    sizeSlider(
                      _textWidth,
                      (v) => set(() => _textWidth = v),
                      label: 'Largura do texto',
                      min: 0.5,
                      max: 1,
                    ),
                    // Colunas só onde cabem.
                    if (wide) ...[
                      toggle('Dividir em colunas', _twoColumns, (v) {
                        _setTwoColumns(v);
                        setSheet(() {});
                      }),
                      if (_twoColumns)
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 2, label: Text('2 colunas')),
                            ButtonSegment(value: 3, label: Text('3 colunas')),
                          ],
                          selected: {_columnCount},
                          onSelectionChanged: (v) {
                            set(() => _columnCount = v.first);
                            _savePrefs();
                          },
                        ),
                    ],
                  ]),
                  card('Ferramentas', [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(AppIcons.metronome),
                      title: const Text('Metrônomo'),
                      onTap: () {
                        setState(() => _metronome = true);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(AppIcons.microphone),
                      title: const Text('Afinador'),
                      onTap: () {
                        setState(() => _tuner = true);
                        Navigator.pop(context);
                      },
                    ),
                  ]),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('Restaurar padrões'),
                    onPressed: () async {
                      await _resetPrefs();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Lista do repertório para pular direto (toque em "1 de 6").
  Future<void> _pickItem() async {
    final reading = widget.reading!;
    final picked = await showModalBottomSheet<PraiseSetlistItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, item) in reading.revision.items.indexed)
              ListTile(
                selected: i == reading.index,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(item.songTitle),
                trailing: Text(
                  item.selectedKey ?? item.version.originalKey ?? '',
                ),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted && picked.id != _item!.id) {
      context.pushReplacement('${reading.base}/itens/${picked.id}');
    }
  }

  Future<void> _pickVersion() async {
    final versions = await ref.read(
      praiseVersionsProvider(widget.songId).future,
    );
    if (!mounted) return;
    final picked = await showModalBottomSheet<PraiseSongVersion>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final v in versions)
              ListTile(
                title: Text(
                  'Versão ${v.versionNumber}${v.originalKey == null ? '' : ' · ${v.originalKey}'}',
                ),
                subtitle: Text(
                  [
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(v.createdAt.toLocal()),
                    if (v.changeNote != null && v.changeNote!.isNotEmpty)
                      v.changeNote!,
                  ].join(' — '),
                ),
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _picked = picked;
        _semitones = 0;
        _capoOverride = null;
      });
    }
  }

  Future<void> _archive(PraiseSong song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivar música?'),
        content: Text(
          '"${song.title}" sai da biblioteca. As versões continuam guardadas '
          'para os repertórios que já usaram esta música.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(praiseRepositoryProvider).archive(song.id);
      invalidatePraise(ref, song.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(praiseSongProvider(widget.songId));
    final canManage = ref
        .watch(praiseAccessProvider)
        .maybeWhen(data: (a) => a.canManage, orElse: () => false);

    final scaffold = Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: CommunityDesign.headerColor(context),
              leading: IconButton(
                icon: const Icon(AppIcons.back),
                onPressed: () => context.pop(),
              ),
              title: widget.reading == null
                  ? Text(songAsync.valueOrNull?.title ?? 'Louvor')
                  : InkWell(
                      borderRadius: BorderRadius.circular(
                        AppTheme.controlRadius,
                      ),
                      onTap: _pickItem,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_item!.songTitle),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${widget.reading!.revision.title} · '
                                  '${widget.reading!.index + 1} de '
                                  '${widget.reading!.revision.items.length}',
                                  style: CommunityDesign.metaStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                AppIcons.expand,
                                size: 16,
                                color: CommunityDesign.metaStyle(context).color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
              actions: [
                // No repertório a versão é a do item: sem histórico nem edição.
                if (widget.reading == null)
                  IconButton(
                    tooltip: 'Versões',
                    icon: const Icon(AppIcons.history),
                    onPressed: _pickVersion,
                  ),
                if (_shown != null)
                  PopupMenuButton<String>(
                    icon: const Icon(AppIcons.more),
                    onSelected: (v) {
                      final shown = _shown!;
                      switch (v) {
                        case 'copy':
                          _copy(shown.version);
                        case 'export':
                          _export(shown.title, shown.version);
                        case 'edit':
                          context.push(
                            '/ministries/${widget.ministryId}/louvores/musicas/${widget.songId}/editar',
                          );
                        case 'archive':
                          _archive(songAsync.value!);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Copiar cifra'),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('Exportar ChordPro (.cho)'),
                      ),
                      if (canManage &&
                          widget.reading == null &&
                          songAsync.valueOrNull != null) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar (gera nova versão)'),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Arquivar'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
      bottomNavigationBar: widget.reading == null || _fullscreen
          ? null
          : _SetlistNav(
              ministryId: widget.ministryId,
              reading: widget.reading!,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: _fullscreen
          ? SafeArea(
              child: IconButton.filledTonal(
                tooltip: 'Sair da tela cheia',
                icon: const Icon(AppIcons.fullscreenExit),
                onPressed: () => _setFullscreen(false),
              ),
            )
          : null,
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Não deu para abrir a música.\n$e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (song) {
          // Música arquivada continua tocável pelo repertório: a versão
          // veio no item.
          if (song == null && _item != null) {
            return _body(
              PraiseSong(
                id: widget.songId,
                title: _item!.songTitle,
                artist: _item!.artist,
              ),
              _item!.version,
            );
          }
          if (song == null) {
            return const Center(
              child: Text('Música não encontrada ou sem acesso.'),
            );
          }
          final version = _picked ?? song.latest;
          if (version == null) {
            return const Center(
              child: Text('Esta música ainda não tem cifra.'),
            );
          }
          return _body(song, version);
        },
      ),
    );
    final themed = _theme == null
        ? scaffold
        : Theme(
            data: _theme == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
            child: scaffold,
          );
    return CallbackShortcuts(
      bindings: _keys,
      child: Focus(autofocus: true, child: themed),
    );
  }

  /// Música e versão na tela (para copiar/exportar no ⋮). No repertório
  /// [_picked] já é a versão do item.
  ({String title, PraiseSongVersion version})? get _shown {
    final song = ref.read(praiseSongProvider(widget.songId)).valueOrNull;
    final v = _picked ?? song?.latest;
    final title = song?.title ?? _item?.songTitle;
    return v == null || title == null ? null : (title: title, version: v);
  }

  Widget _body(PraiseSong song, PraiseSongVersion version) {
    final key = version.originalKey == null
        ? null
        : Chord.tryParse(version.originalKey!);
    final shifted = key?.transpose(_semitones);
    final flats = shifted == null
        ? null
        : Chord.keyPrefersFlats(shifted.toString());
    final keyLabel = shifted?.transpose(0, preferFlats: flats).toString();
    final meta = CommunityDesign.metaStyle(context);
    final baseCapo = _item?.capo ?? version.capo;
    final capo = _capoOverride ?? baseCapo;
    final bpm = _item == null ? version.bpm : _item!.bpm;
    // Correção da música para o instrumento escolhido (§9.5).
    final fixed = forInstrument(version.chordpro, _instrument.chip.name);
    final chordpro = _simplified ? simplifyChordPro(fixed) : fixed;
    final strip = _ChordStrip(
      chords: _uniqueChords(chordpro, flats),
      instrument: _instrument,
      shapeOf: (c) => _shapeOf(c, _instrument, capo),
      scale: _diagramScale,
      onTap: (c) => _openChord(c, capo),
    );

    final source = parseChordPro(chordpro);
    final patterns = [
      for (final l in source.lines)
        if (l is DirectiveLine && l.name == 'batida') parseStrum(l.value),
    ];
    final sections = chordProSections(source);
    if (_sectionKeys.length != sections.length) {
      _sectionKeys = [for (final _ in sections) GlobalKey()];
      _playingSection = null;
    }
    if (_strumKeys.length != patterns.length) {
      _strumKeys = [for (final _ in patterns) GlobalKey()];
      _currentStrum = -1;
    }
    if (_strums == StrumDisplay.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _trackStrum());
    }
    // Bateria lê a letra com a grade de cada seção, sem acorde.
    final noChords = _lyricsOnly || _instrument.isDrums;
    final pinned = !noChords && _diagramsStart && _diagramsPinned;
    // Principal / Simplificada / Letra (CifraClub §1.2).
    final lyricsToggle = SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 0, label: Text('Cifra')),
        ButtonSegment(value: 1, label: Text('Simplificada')),
        ButtonSegment(value: 2, label: Text('Só letra')),
      ],
      selected: {
        _lyricsOnly
            ? 2
            : _simplified
            ? 1
            : 0,
      },
      onSelectionChanged: (v) {
        _simplified = v.first == 1;
        _setLyricsOnly(v.first == 2);
        _savePrefs();
      },
    );

    final scrolling = _autoScroll.isActive;
    final autoScrollBar = Material(
      shape: const StadiumBorder(),
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: scrolling ? 'Pausar rolagem' : 'Rolagem automática',
            icon: Icon(scrolling ? AppIcons.pause : AppIcons.playArrow),
            onPressed: () => _setAutoScroll(!scrolling),
          ),
          _PillStepper(
            onMinus: _autoSpeed > 1
                ? () => _setAutoSpeed(_autoSpeed - 1)
                : null,
            onPlus: _autoSpeed < 10
                ? () => _setAutoSpeed(_autoSpeed + 1)
                : null,
            minusTooltip: 'Mais devagar',
            plusTooltip: 'Mais rápido',
            child: Text(
              '$_autoSpeed',
              semanticsLabel: 'Velocidade $_autoSpeed',
            ),
          ),
        ],
      ),
    );

    final list = ListView(
      key: _listKey,
      controller: _scroll,
      // Espaço para a barra da rolagem não cobrir o fim da cifra.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (song.artist != null && song.artist!.isNotEmpty)
          Text(song.artist!, style: meta),
        if (_item != null)
          Text(
            'Tom do repertório ('
            '${version.originalKey == null ? '' : 'original ${version.originalKey}, '}'
            'versão ${version.versionNumber}). Mudar aqui vale só nesta tela.',
            style: meta,
          )
        else if (_picked != null && _picked!.id != song.latest?.id)
          Text(
            'Versão ${version.versionNumber} (não é a mais recente)',
            style: meta.copyWith(fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            lyricsToggle,
            // Controles pequenos em pílula (referência CifraClub §1.6).
            if (!_lyricsOnly)
              _PillStepper(
                onMinus: () => setState(() => _semitones--),
                onPlus: () => setState(() => _semitones++),
                minusTooltip: 'Meio tom abaixo',
                plusTooltip: 'Meio tom acima',
                child: GestureDetector(
                  onTap: () => setState(() => _semitones = 0),
                  child: Text(
                    keyLabel != null
                        ? 'Tom: $keyLabel'
                        : 'Tom ${_semitones == 0 ? 'original' : (_semitones > 0 ? '+$_semitones' : '$_semitones')}',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 16),
                  ),
                ),
              ),
            _PillStepper(
              onMinus: _fontSize > 11
                  ? () => setState(() => _fontSize--)
                  : null,
              onPlus: _fontSize < 26 ? () => setState(() => _fontSize++) : null,
              minusTooltip: 'Diminuir letra',
              plusTooltip: 'Aumentar letra',
              minusIcon: AppIcons.zoomOut,
              plusIcon: AppIcons.zoomIn,
            ),
            // No repertório, capo/BPM/observação são os do culto.
            if (!_lyricsOnly && capo > 0)
              ActionChip(
                shape: const StadiumBorder(),
                label: Text('Capo $capo'),
                onPressed: () => _openSettings(baseCapo),
              ),
            if (!_lyricsOnly && bpm != null)
              ActionChip(
                shape: const StadiumBorder(),
                label: Text('$bpm BPM'),
                onPressed: () => setState(() => _metronome = true),
              ),
            if (_item?.notes != null)
              Chip(shape: const StadiumBorder(), label: Text(_item!.notes!)),
            if (!_lyricsOnly)
              ActionChip(
                shape: const StadiumBorder(),
                avatar: const Icon(AppIcons.tune, size: 16),
                label: Text('Ajustes · ${_instrument.label}'),
                onPressed: () => _openSettings(baseCapo),
              ),
          ],
        ),
        if (_item == null && _semitones % 12 != 0 && keyLabel != null)
          Text(
            'Original em ${version.originalKey}. Trocar o tom aqui não altera a música.',
            style: meta,
          ),
        const SizedBox(height: 12),
        if (!noChords && _diagramsStart && !pinned) ...[
          strip,
          const SizedBox(height: 12),
        ],
        FractionallySizedBox(
          alignment: Alignment.topLeft,
          widthFactor: _textWidth,
          child: ChordProView(
            source: chordpro,
            semitones: _semitones,
            preferFlats: flats,
            fontSize: _fontSize,
            onChordTap: (c) => _openChord(c, capo),
            twoColumns: _twoColumns,
            columnCount: _columnCount,
            showTabs: _showTabs,
            lyricsOnly: noChords,
            drums: _instrument.isDrums,
            strums: noChords ? StrumDisplay.hidden : _strums,
            strumKeys: _strumKeys,
            sectionKeys: _sectionKeys,
            onPlaySection: (i) {
              _setAutoScroll(false);
              setState(() => _playingSection = i);
            },
            diagramFor: _diagramsInline && !noChords
                ? (c) => ChordDiagram(
                    chord: _shapeOf(c, _instrument, capo),
                    instrument: _instrument,
                    width: 40 * _inlineScale,
                  )
                : null,
          ),
        ),
        if (!noChords && _diagramsEnd) ...[const SizedBox(height: 16), strip],
      ],
    );

    final current =
        !noChords &&
            _strums == StrumDisplay.current &&
            _currentStrum >= 0 &&
            _currentStrum < patterns.length
        ? patterns[_currentStrum]
        : null;
    // Tocar na cifra pausa a rolagem (para olhar ou voltar um trecho).
    final touchList = Listener(
      onPointerDown: (_) => _setAutoScroll(false),
      child: list,
    );
    // Faixa fixa e batida da seção ficam fora da rolagem.
    final body = !pinned && current == null
        ? touchList
        : Column(
            children: [
              Material(
                color: CommunityDesign.scaffoldBackgroundColor(context),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pinned) strip,
                      if (current != null)
                        Row(
                          children: [
                            Text('Batida', style: meta),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StrumView(
                                pattern: current,
                                fontSize: _fontSize,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: touchList),
            ],
          );

    return LayoutBuilder(
      builder: (context, c) {
        final area = c.biggest;
        // Lado a lado se couber; senão o afinador abre em cima do metrônomo.
        final tunerAt = !_metronome
            ? const Offset(12, 12)
            : area.width >= 620
            ? const Offset(312, 12)
            : const Offset(12, 380);
        return Stack(
          children: [
            body,
            if (_playingSection == null)
              Positioned(right: 12, bottom: 12, child: autoScrollBar)
            else
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SectionPlayerBar(
                      // Outra seção = player novo, do começo.
                      key: ValueKey(_playingSection),
                      label: sections[_playingSection!].label,
                      bpm: sections[_playingSection!].bpm ?? bpm ?? 80,
                      meter: source.meta('time'),
                      lines: sections[_playingSection!].lines,
                      scroll: _scroll,
                      start: () => _sectionOffset(_playingSection!),
                      end: () => _playingSection! + 1 < _sectionKeys.length
                          ? _sectionOffset(_playingSection! + 1)
                          : _scroll.position.maxScrollExtent,
                      onClose: () => setState(() => _playingSection = null),
                    ),
                  ),
                ),
              ),
            if (_tuner)
              FloatingTool(
                area: area,
                initial: tunerAt,
                prefsKey: 'praise_reader_tuner_pos',
                child: TunerPanel(
                  onClose: () => setState(() => _tuner = false),
                ),
              ),
            if (_metronome)
              FloatingTool(
                area: area,
                initial: const Offset(12, 12),
                prefsKey: 'praise_reader_metronome_pos',
                child: MetronomePanel(
                  initialBpm: bpm ?? 80,
                  initialMeter: source.meta('time'),
                  onClose: () => setState(() => _metronome = false),
                ),
              ),
          ],
        );
      },
    );
  }

  /// `offset` da rolagem que põe o título da seção [i] no topo da lista.
  double _sectionOffset(int i) {
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    final box =
        _sectionKeys[i].currentContext?.findRenderObject() as RenderBox?;
    if (list == null || box == null || !_scroll.hasClients) return 0;
    return _scroll.offset +
        box.localToGlobal(Offset.zero).dy -
        list.localToGlobal(Offset.zero).dy -
        8;
  }

  /// Acordes da música na ordem em que aparecem, sem repetir, já no tom da
  /// tela.
  List<Chord> _uniqueChords(String chordpro, bool? flats) {
    final seen = <String>{};
    final out = <Chord>[];
    for (final line in parseChordPro(chordpro).lines.whereType<LyricLine>()) {
      for (final s in line.segments) {
        final c = s.chord == null ? null : Chord.tryParse(s.chord!);
        if (c == null) continue;
        final shown = _semitones % 12 == 0
            ? c
            : c.transpose(_semitones, preferFlats: flats);
        if (seen.add('$shown')) out.add(shown);
      }
    }
    return out;
  }
}

/// [−] conteúdo [+] num contorno de pílula.
class _PillStepper extends StatelessWidget {
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String minusTooltip;
  final String plusTooltip;
  final IconData minusIcon;
  final IconData plusIcon;
  final Widget? child;

  const _PillStepper({
    required this.onMinus,
    required this.onPlus,
    required this.minusTooltip,
    required this.plusTooltip,
    this.minusIcon = AppIcons.remove,
    this.plusIcon = AppIcons.add,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: minusTooltip,
            icon: Icon(minusIcon),
            onPressed: onMinus,
          ),
          ?child,
          IconButton(
            tooltip: plusTooltip,
            icon: Icon(plusIcon),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}

/// Faixa dos acordes da música (referência CifraClub §1.3): um cartão por
/// acorde, refeita quando o tom ou o instrumento mudam. Toque abre o painel.
class _ChordStrip extends StatelessWidget {
  final List<Chord> chords;
  final PraiseInstrument instrument;
  final ValueChanged<Chord> onTap;

  /// Desenho com capo/afinação; o nome em cima continua o do som.
  final Chord Function(Chord) shapeOf;
  final double scale;

  const _ChordStrip({
    required this.chords,
    required this.instrument,
    required this.onTap,
    required this.shapeOf,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (chords.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: (instrument == PraiseInstrument.teclado ? 56 : 84) * scale + 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chords.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => InkWell(
          borderRadius: BorderRadius.circular(CommunityDesign.radius),
          onTap: () => onTap(chords[i]),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: CommunityDesign.overlayDecoration(scheme),
            child: Column(
              children: [
                Text(
                  '${chords[i]}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ChordDiagram(
                  chord: shapeOf(chords[i]),
                  instrument: instrument,
                  width: 56 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Anterior / próxima do repertório (contrato do leitor §3.2). Troca a rota
/// no lugar, para o voltar levar direto ao repertório.
class _SetlistNav extends StatelessWidget {
  final String ministryId;
  final _SetlistReading reading;

  const _SetlistNav({required this.ministryId, required this.reading});

  void _go(BuildContext context, PraiseSetlistItem item) =>
      context.pushReplacement('${reading.base}/itens/${item.id}');

  @override
  Widget build(BuildContext context) {
    final items = reading.revision.items;
    final i = reading.index;
    final prev = i > 0 ? items[i - 1] : null;
    final next = i + 1 < items.length ? items[i + 1] : null;
    final nextKey = next?.selectedKey ?? next?.version.originalKey;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(AppIcons.chevronLeft),
                label: const Text('Anterior'),
                onPressed: prev == null ? null : () => _go(context, prev),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: next == null ? null : () => _go(context, next),
                child: next == null
                    ? const Text('Última música')
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nextKey == null
                                      ? 'Próxima'
                                      : 'Próxima · $nextKey',
                                  style: CommunityDesign.metaStyle(
                                    context,
                                  ).copyWith(fontSize: 11),
                                ),
                                Text(
                                  next.songTitle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(AppIcons.forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
