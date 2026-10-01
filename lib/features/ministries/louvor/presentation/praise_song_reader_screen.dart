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
import '../../../../core/widgets/app_tabs.dart';
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
import 'widgets/spontaneous_sheet.dart';

/// Leitor de cifra — tela interna, não aba
/// (`/ministries/:id/louvores/musicas/:songId`).
///
/// Trocar o tom aqui é só para tocar: transpõe na tela e não grava nada.
/// Versão nova só nasce no editor, de propósito.
class PraiseSongReaderScreen extends StatelessWidget {
  final String ministryId;
  final String songId;

  /// `?tom=G`: abre transposto (vem do Espontâneo).
  final String? initialKey;

  const PraiseSongReaderScreen({
    super.key,
    required this.ministryId,
    required this.songId,
    this.initialKey,
  });

  @override
  Widget build(BuildContext context) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) => _Reader(
        ministryId: ministryId,
        songId: songId,
        initialKey: initialKey,
      ),
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
  final String? initialKey;

  const _Reader({
    super.key,
    required this.ministryId,
    required this.songId,
    this.reading,
    this.initialKey,
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
  static const _fontSizePref = 'praise_reader_font_size';

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

  /// Painel de Ajustes fixo do lado no computador (canvas 13h) e o grupo
  /// aberto nele.
  bool _sidePanel = true;
  String? _sideOpen;
  static const _sidePanelPref = 'praise_reader_side_panel';

  /// Rolagem automática (contrato do leitor §8): para ao tocar na cifra.
  /// A velocidade (1–10) é do aparelho; em linhas por segundo, então não
  /// muda com o tamanho da letra.
  late final Ticker _autoScroll = createTicker(_autoTick);
  Duration _autoLast = Duration.zero;
  int _autoSpeed = 3;
  static const _autoSpeedPref = 'praise_reader_scroll_speed';

  /// Nulo = a versão mais recente.
  PraiseSongVersion? _picked;

  /// Estrela da Biblioteca, também pelo ⋮ (favoritas ficam no aparelho).
  bool _favorite = false;

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
    } else if (widget.initialKey case final key?) {
      // O Espontâneo abre da biblioteca já carregada: a versão mais recente.
      final from = ref
          .read(praiseSongsProvider)
          .valueOrNull
          ?.where((s) => s.id == widget.songId)
          .firstOrNull
          ?.latest
          ?.originalKey;
      if (from != null &&
          Chord.tryParse(from) != null &&
          Chord.tryParse(key) != null) {
        _semitones = Chord.interval(from, key);
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
        _sidePanel = prefs.getBool(_sidePanelPref) ?? true;
        _theme = Brightness.values.where((b) => b.name == theme).firstOrNull;
        if (layout != null && layout.length >= 2) {
          _columnCount = (int.tryParse(layout[0]) ?? 2).clamp(2, 3);
          _textWidth = (double.tryParse(layout[1]) ?? 1).clamp(0.5, 1.0);
        }
        _tuningDrop = (prefs.getInt(_tuningPref) ?? 0).clamp(0, 4);
        _autoSpeed = (prefs.getInt(_autoSpeedPref) ?? 3).clamp(1, 10);
        _fontSize = (prefs.getDouble(_fontSizePref) ?? 15).clamp(11, 26);
        _favorite = (prefs.getStringList(praiseFavoritesPref) ?? const [])
            .contains(widget.songId);
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
      await p.setDouble(_fontSizePref, _fontSize);
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
      _sidePanel = true;
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

  /// Painel fixo do lado só onde sobra tela para a cifra (canvas 13h).
  bool get _sideFits => MediaQuery.sizeOf(context).width >= 1100;

  /// Ajustes do leitor (§10.4 S8, canvas 13a–13h): Tom e capo direto na
  /// linha, o resto abre uma subtela. No celular é um sheet com subtelas; no
  /// computador, o botão mostra/esconde o painel do lado.
  void _openSettings() {
    if (_sideFits) {
      setState(() => _sidePanel = !_sidePanel);
      SharedPreferences.getInstance()
          .then((p) => p.setBool(_sidePanelPref, _sidePanel))
          .ignore();
      return;
    }
    String? open;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
            ),
            child: _settings(
              set: (f) {
                setState(f);
                setSheet(() {});
              },
              open: open,
              onOpen: (g) => setSheet(() => open = g),
              side: false,
              // Ferramenta flutuante não divide a tela com o sheet.
              close: () => Navigator.pop(sheet),
            ),
          ),
        ),
      ),
    );
  }

  /// Tom [semitones] acima de [original], com a grafia do tom (Bb, não A#).
  String? _keyAt(String? original, int semitones) {
    final key = original == null ? null : Chord.tryParse(original);
    final shifted = key?.transpose(semitones);
    if (shifted == null) return null;
    return shifted
        .transpose(0, preferFlats: Chord.keyPrefersFlats(shifted.toString()))
        .toString();
  }

  /// A lista dos Ajustes. [open] = grupo aberto: no celular vira a subtela,
  /// no painel do lado abre no lugar (acordeão).
  Widget _settings({
    required void Function(VoidCallback) set,
    required String? open,
    required ValueChanged<String?> onOpen,
    required bool side,
    VoidCallback? close,
  }) {
    final v = _shown?.version;
    final baseCapo = _item?.capo ?? v?.capo ?? 0;
    final capo = _capoOverride ?? baseCapo;
    final original = v?.originalKey;
    final keyNow = _keyAt(original, _semitones);
    final bpm = _item == null ? v?.bpm : _item!.bpm;
    final meta = CommunityDesign.metaStyle(context);
    final selectedBg = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.06);
    // Só o que vale para o instrumento aparece (canvas 13a).
    final hasCapo = _instrument.tuning != null && !_instrument.isBass;
    final hasTuning = _instrument.tuning != null;
    final hasDiagrams = !_instrument.isDrums;

    void refresh() => set(() {});
    void save(VoidCallback f) {
      set(f);
      _savePrefs();
    }

    String pct(double x) => '${(x * 100).round()}%';
    double step(double x, double d, double min, double max) =>
        ((x + d) * 10).round().clamp(min * 10, max * 10) / 10;

    Widget group(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: meta.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );

    Widget control(String title, Widget trailing, {String? subtitle}) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle, style: meta),
          trailing: trailing,
        );

    Widget toggle(String title, bool value, ValueChanged<bool>? onChanged) =>
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(title),
          value: value,
          onChanged: onChanged,
        );

    Widget scaleStepper(
      double value,
      ValueChanged<double>? onChanged, {
      double min = 0.7,
      double max = 1.6,
    }) => PillStepper(
      onMinus: onChanged == null || value <= min
          ? null
          : () => onChanged(step(value, -0.1, min, max)),
      onPlus: onChanged == null || value >= max
          ? null
          : () => onChanged(step(value, 0.1, min, max)),
      minusTooltip: 'Diminuir',
      plusTooltip: 'Aumentar',
      child: Text(pct(value)),
    );

    Widget hint(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(text, style: meta),
    );

    List<Widget> page(String id) => switch (id) {
      'instrument' => [
        RadioGroup<PraiseInstrument>(
          groupValue: _instrument.chip,
          onChanged: (i) {
            if (i == null) return;
            _setInstrument(i);
            refresh();
          },
          child: Column(
            children: [
              for (final i in [
                ...PraiseInstrument.pickable,
                PraiseInstrument.bateria,
              ]) ...[
                RadioListTile<PraiseInstrument>(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: i,
                  title: Text(i.label),
                  subtitle: Text(switch (i) {
                    PraiseInstrument.violao =>
                      'Diagrama de 6 cordas, com capotraste e afinação',
                    PraiseInstrument.teclado => 'Teclas de cada acorde',
                    PraiseInstrument.bateria =>
                      'Grade de ritmo no lugar dos acordes',
                    _ => 'Nota do baixo de cada acorde (em D/F#, o F#)',
                  }, style: meta),
                ),
                if (i == PraiseInstrument.baixo && _instrument.isBass)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(68, 0, 20, 8),
                    child: AppTabs(
                      tabs: const [
                        AppTab(label: '4 cordas'),
                        AppTab(label: '5 cordas'),
                      ],
                      selectedIndex: _instrument == PraiseInstrument.baixo5
                          ? 1
                          : 0,
                      onChanged: (x) {
                        _setBass(
                          x == 1
                              ? PraiseInstrument.baixo5
                              : PraiseInstrument.baixo,
                        );
                        refresh();
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
        hint('Vale para todas as músicas neste aparelho.'),
      ],
      'tuning' => [
        RadioGroup<int>(
          groupValue: _tuningDrop,
          onChanged: (d) => save(() => _tuningDrop = d ?? 0),
          child: Column(
            children: [
              for (final t in praiseTunings)
                RadioListTile<int>(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: t.drop,
                  title: Text(_tuningName(t)),
                  secondary: Text(
                    _tuningNotes(t),
                    style: meta.copyWith(fontFamily: 'monospace'),
                  ),
                ),
            ],
          ),
        ),
        hint(
          'Afinação não é tom: o tom muda o nome dos acordes para todos; a '
          'afinação muda só o desenho para quem afinou o instrumento mais '
          'baixo.',
        ),
      ],
      'diagrams' => [
        group('FAIXA DE ACORDES'),
        toggle(
          'No início',
          _diagramsStart,
          (x) => save(() => _diagramsStart = x),
        ),
        toggle('No fim', _diagramsEnd, (x) => save(() => _diagramsEnd = x)),
        toggle(
          'Fixar no topo ao rolar',
          _diagramsPinned,
          (x) => save(() => _diagramsPinned = x),
        ),
        control(
          'Tamanho',
          scaleStepper(_diagramScale, (x) => save(() => _diagramScale = x)),
        ),
        group('NO CORPO DA CIFRA'),
        toggle(
          'Ao lado de cada acorde',
          _diagramsInline,
          (x) => save(() => _diagramsInline = x),
        ),
        control(
          'Tamanho no corpo',
          scaleStepper(
            _inlineScale,
            _diagramsInline ? (x) => save(() => _inlineScale = x) : null,
          ),
        ),
      ],
      'strums' => [
        RadioGroup<StrumDisplay>(
          groupValue: _strums,
          onChanged: (s) {
            save(() => _strums = s ?? _strums);
            WidgetsBinding.instance.addPostFrameCallback((_) => _trackStrum());
          },
          child: Column(
            children: [
              for (final s in StrumDisplay.values)
                RadioListTile<StrumDisplay>(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: s,
                  title: Text(s.label),
                ),
            ],
          ),
        ),
        hint('A batida é escrita no editor. Música sem batida não muda.'),
      ],
      'display' => [
        group('TEXTO'),
        control(
          'Tamanho do texto',
          PillStepper(
            onMinus: _fontSize > 11 ? () => save(() => _fontSize--) : null,
            onPlus: _fontSize < 26 ? () => save(() => _fontSize++) : null,
            minusTooltip: 'Diminuir letra',
            plusTooltip: 'Aumentar letra',
            child: Text(pct(_fontSize / 15)),
          ),
        ),
        control(
          'Largura do texto',
          scaleStepper(
            _textWidth,
            (x) => save(() => _textWidth = x),
            min: 0.5,
            max: 1,
          ),
        ),
        group('TEMA DO LEITOR'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: AppTabs(
            tabs: const [
              AppTab(label: 'Do app'),
              AppTab(label: 'Claro'),
              AppTab(label: 'Escuro'),
            ],
            selectedIndex: switch (_theme) {
              null => 0,
              Brightness.light => 1,
              Brightness.dark => 2,
            },
            onChanged: (i) => save(
              () => _theme = const [null, Brightness.light, Brightness.dark][i],
            ),
          ),
        ),
        group('TELA'),
        toggle('Tela cheia', _fullscreen, (x) {
          _setFullscreen(x);
          refresh();
        }),
        toggle(
          'Mostrar tablaturas',
          _showTabs,
          (x) => save(() => _showTabs = x),
        ),
        // Colunas só onde cabem.
        if (MediaQuery.sizeOf(context).width >=
            ChordProView.twoColumnWidth) ...[
          toggle('Dividir em colunas', _twoColumns, (x) {
            _setTwoColumns(x);
            refresh();
          }),
          if (_twoColumns)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: AppTabs(
                tabs: const [
                  AppTab(label: '2 colunas'),
                  AppTab(label: '3 colunas'),
                ],
                selectedIndex: _columnCount - 2,
                onChanged: (i) => save(() => _columnCount = i + 2),
              ),
            ),
        ] else
          const ListTile(
            enabled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 20),
            title: Text('Dividir em colunas'),
            trailing: Text('Só no computador'),
          ),
      ],
      _ => const [],
    };

    const titles = {
      'instrument': 'Instrumento',
      'tuning': 'Afinação',
      'diagrams': 'Diagramas',
      'strums': 'Batidas',
      'display': 'Exibição',
    };

    // Linha com o valor atual: abre a subtela (celular) ou o grupo no lugar.
    List<Widget> nav(String id, IconData icon, String value) {
      final isOpen = side && open == id;
      return [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          tileColor: isOpen ? selectedBg : null,
          leading: Icon(icon),
          title: Text(titles[id]!),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value,
                  style: meta,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(isOpen ? AppIcons.expandLess : AppIcons.chevronRight),
            ],
          ),
          onTap: () => onOpen(isOpen ? null : id),
        ),
        if (isOpen)
          ColoredBox(
            color: selectedBg,
            child: Column(children: page(id)),
          ),
      ];
    }

    ListTile tool(IconData icon, String title, String value, VoidCallback on) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(icon),
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: meta),
              const SizedBox(width: 4),
              const Icon(AppIcons.floatingPanel),
            ],
          ),
          onTap: () {
            close?.call();
            setState(on);
          },
        );

    final diagramsValue = !_diagramsStart && !_diagramsEnd && !_diagramsInline
        ? 'Ocultos'
        : '${_diagramsStart
              ? 'No início'
              : _diagramsEnd
              ? 'No fim'
              : 'No corpo'} · ${pct(_diagramScale)}';

    final List<Widget> rows = !side && open != null
        ? page(open)
        : [
            group('RÁPIDO'),
            control(
              'Tom',
              PillStepper(
                onMinus: () => set(() => _semitones--),
                onPlus: () => set(() => _semitones++),
                minusTooltip: 'Meio tom abaixo',
                plusTooltip: 'Meio tom acima',
                child: Text(
                  keyNow ??
                      (_semitones == 0
                          ? 'Original'
                          : (_semitones > 0 ? '+$_semitones' : '$_semitones')),
                ),
              ),
              subtitle: original == null ? null : 'Original: $original',
            ),
            if (hasCapo)
              control(
                'Capotraste',
                PillStepper(
                  onMinus: capo > 0
                      ? () => set(() => _capoOverride = capo - 1)
                      : null,
                  onPlus: capo < 11
                      ? () => set(() => _capoOverride = capo + 1)
                      : null,
                  minusTooltip: 'Casa abaixo',
                  plusTooltip: 'Casa acima',
                  child: Text(capo == 0 ? 'Sem capo' : '$capoª casa'),
                ),
                subtitle: capo > 0 && keyNow != null
                    ? 'Toca em ${_keyAt(original, _semitones - capo)} · '
                          'soa em $keyNow'
                    : 'Muda o desenho; o som continua no tom.',
              ),
            ...nav(
              'instrument',
              AppIcons.instrument,
              _instrument.isBass
                  ? 'Baixo · ${_instrument == PraiseInstrument.baixo5 ? 5 : 4} cordas'
                  : _instrument.label,
            ),
            group('CIFRA'),
            if (hasTuning)
              ...nav(
                'tuning',
                AppIcons.tuning,
                _tuningName(
                  praiseTunings.firstWhere((t) => t.drop == _tuningDrop),
                ),
              ),
            if (hasDiagrams)
              ...nav('diagrams', AppIcons.chordGrid, diagramsValue),
            ...nav('strums', AppIcons.strum, _strums.label),
            ...nav(
              'display',
              AppIcons.textFields,
              'Texto ${pct(_fontSize / 15)} · ${switch (_theme) {
                null => 'Tema do app',
                Brightness.light => 'Claro',
                Brightness.dark => 'Escuro',
              }}',
            ),
            group('FERRAMENTAS'),
            tool(
              AppIcons.metronome,
              'Metrônomo',
              bpm == null ? '' : '$bpm BPM',
              () => _metronome = true,
            ),
            tool(
              AppIcons.microphone,
              'Afinador',
              'Lá = 440 Hz',
              () => _tuner = true,
            ),
          ];

    final header = !side && open != null
        ? Row(
            children: [
              TextButton.icon(
                icon: const Icon(AppIcons.chevronLeft),
                label: const Text('Ajustes'),
                onPressed: () => onOpen(null),
              ),
              Expanded(
                child: Text(
                  titles[open]!,
                  textAlign: TextAlign.center,
                  style: CommunityDesign.titleStyle(context),
                ),
              ),
              // Contrapeso do botão, para o título ficar no meio.
              const SizedBox(width: 100),
            ],
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ajustes',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 18),
                  ),
                ),
                if (side)
                  IconButton(
                    tooltip: 'Esconder ajustes',
                    icon: const Icon(AppIcons.chevronRight),
                    onPressed: _openSettings,
                  ),
              ],
            ),
          );

    final list = ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: rows,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const Divider(height: 1),
        side ? Expanded(child: list) : Flexible(child: list),
        if (side || open == null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(AppIcons.refresh),
                  label: const Text('Restaurar padrões'),
                  onPressed: () async {
                    await _resetPrefs();
                    close?.call();
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Volta só as preferências do leitor neste aparelho. A '
                  'música e o repertório não mudam.',
                  style: meta,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "1/2 tom abaixo (Eb Ab ...)" → "1/2 tom abaixo" e "Eb Ab ...".
  String _tuningLabel(({String label, String bassLabel, int drop}) t) =>
      _instrument.isBass ? t.bassLabel : t.label;
  String _tuningName(({String label, String bassLabel, int drop}) t) =>
      _tuningLabel(t).split(' (').first;
  String _tuningNotes(({String label, String bassLabel, int drop}) t) {
    final l = _tuningLabel(t);
    return l.substring(l.indexOf('(') + 1, l.length - 1);
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
                if (!(widget.reading?.base.contains('/recebidos/') ?? false))
                  TextButton(
                    onPressed: () => showSpontaneousSheet(
                      context,
                      ministryId: widget.ministryId,
                      ministerId: _item?.ministerId,
                    ),
                    child: const Text('Espontâneo'),
                  ),
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
                        case 'favorite':
                          setState(() => _favorite = !_favorite);
                          togglePraiseFavorite(widget.songId).ignore();
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
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          _favorite ? 'Tirar das favoritas' : 'Favoritar',
                        ),
                      ),
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
    // AppTabs ocupa a largura toda: no Wrap da barra ele divide a linha.
    final lyricsToggle = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: AppTabs(
        tabs: const [
          AppTab(label: 'Cifra'),
          AppTab(label: 'Simplificada'),
          AppTab(label: 'Só letra'),
        ],
        selectedIndex: _lyricsOnly
            ? 2
            : _simplified
            ? 1
            : 0,
        onChanged: (i) {
          _simplified = i == 1;
          _setLyricsOnly(i == 2);
          _savePrefs();
        },
      ),
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
          PillStepper(
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
              PillStepper(
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
            // No repertório, capo/BPM/observação são os do culto.
            if (!_lyricsOnly && capo > 0)
              ActionChip(
                shape: const StadiumBorder(),
                label: Text('Capo $capo'),
                onPressed: () => _openSettings(),
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
                onPressed: () => _openSettings(),
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

    final reader = LayoutBuilder(
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
    if (!_sideFits || !_sidePanel || _fullscreen) return reader;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: reader),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 360,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: _settings(
              set: setState,
              open: _sideOpen,
              onOpen: (g) => setState(() => _sideOpen = g),
              side: true,
            ),
          ),
        ),
      ],
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

/// Faixa dos acordes da música (referência CifraClub §1.3): um cartão por
/// acorde, refeita quando o tom ou o instrumento mudam. Toque abre o painel.
class _ChordStrip extends StatefulWidget {
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
  State<_ChordStrip> createState() => _ChordStripState();
}

class _ChordStripState extends State<_ChordStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ChordStrip(:chords, :instrument, :onTap, :shapeOf, :scale) = widget;
    if (chords.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // Barra sempre à mostra: sem ela não se vê que a faixa rola para o lado
    // (no computador não há gesto de arrastar). Só aparece se não couber.
    return SizedBox(
      height: (instrument == PraiseInstrument.teclado ? 56 : 84) * scale + 48,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.only(bottom: 12),
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
            // Sem anterior/próxima não fica botão vazio (§10.4 S11).
            Expanded(
              child: prev == null
                  ? const SizedBox.shrink()
                  : OutlinedButton.icon(
                      icon: const Icon(AppIcons.chevronLeft),
                      label: const Text('Anterior'),
                      onPressed: () => _go(context, prev),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: next == null
                  ? Text(
                      'Última música do repertório',
                      textAlign: TextAlign.center,
                      style: CommunityDesign.metaStyle(context),
                    )
                  : OutlinedButton(
                      onPressed: () => _go(context, next),
                      child: Row(
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
