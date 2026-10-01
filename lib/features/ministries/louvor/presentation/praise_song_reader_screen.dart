import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../praise/domain/chord.dart';
import '../../../praise/domain/chord_shapes.dart';
import '../../../praise/domain/chordpro.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'providers/praise_providers.dart';
import 'widgets/chord_diagram.dart';
import 'widgets/chordpro_view.dart';
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
class PraiseSetlistItemReaderScreen extends ConsumerWidget {
  final String ministryId;
  final String setlistId;
  final String itemId;

  const PraiseSetlistItemReaderScreen({
    super.key,
    required this.ministryId,
    required this.setlistId,
    required this.itemId,
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
          reading: (setlistId: setlistId, revision: rev, index: index),
        );
      },
    );
  }
}

String _itemRoute(String ministryId, String setlistId, String? itemId) =>
    '/ministries/$ministryId/louvores/repertorios/$setlistId/itens/$itemId';

typedef _SetlistReading = ({
  String setlistId,
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

class _ReaderState extends ConsumerState<_Reader> {
  int _semitones = 0;
  double _fontSize = 15;

  /// Preferência do aparelho (plano §12.4), não da música nem do repertório.
  PraiseInstrument _instrument = PraiseInstrument.violao;
  static const _instrumentPref = 'praise_reader_instrument';

  /// "Dividir em colunas" do CifraClub: escolha do usuário, salva no aparelho.
  bool _twoColumns = false;
  static const _columnsPref = 'praise_reader_two_columns';

  /// Afinação do violão (semitons abaixo da padrão), também do aparelho.
  int _tuningDrop = 0;
  static const _tuningPref = 'praise_reader_tuning_drop';

  /// Faixa de diagramas (print 10): no início, no fim e tamanho.
  bool _diagramsStart = true;
  bool _diagramsEnd = false;
  double _diagramScale = 1;
  static const _diagramsPref = 'praise_reader_diagrams';

  /// Capo só desta tela. Nulo = o do repertório ou da versão.
  int? _capoOverride;

  bool _metronome = false;
  bool _tuner = false;

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

  Future<void> _loadInstrument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_instrumentPref);
      final saved = PraiseInstrument.values.where((i) => i.name == name);
      final diagrams = prefs.getStringList(_diagramsPref);
      if (!mounted) return;
      setState(() {
        if (saved.isNotEmpty) _instrument = saved.first;
        _twoColumns = prefs.getBool(_columnsPref) ?? false;
        _tuningDrop = (prefs.getInt(_tuningPref) ?? 0).clamp(0, 4);
        if (diagrams != null && diagrams.length == 3) {
          _diagramsStart = diagrams[0] == 'true';
          _diagramsEnd = diagrams[1] == 'true';
          _diagramScale = (double.tryParse(diagrams[2]) ?? 1).clamp(0.7, 1.6);
        }
      });
    } catch (_) {
      // Sem preferência salva o leitor fica no violão.
    }
  }

  void _setInstrument(PraiseInstrument i) {
    setState(() => _instrument = i);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_instrumentPref, i.name))
        .ignore();
  }

  void _setTwoColumns(bool v) {
    setState(() => _twoColumns = v);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_columnsPref, v))
        .ignore();
  }

  void _savePrefs() {
    SharedPreferences.getInstance().then((p) async {
      await p.setInt(_tuningPref, _tuningDrop);
      await p.setStringList(_diagramsPref, [
        '$_diagramsStart',
        '$_diagramsEnd',
        '$_diagramScale',
      ]);
    }).ignore();
  }

  /// Desenho que soa como [chord] com o capo e a afinação da tela. A
  /// afinação é a do violão; o capo vale para todo instrumento de braço.
  Chord _shapeOf(Chord chord, PraiseInstrument i, int capo) => i.tuning == null
      ? chord
      : shapeChord(
          chord,
          drop: i == PraiseInstrument.violao ? _tuningDrop : 0,
          capo: capo,
        );

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
                        for (final i in PraiseInstrument.values)
                          ChoiceChip(
                            shape: const StadiumBorder(),
                            label: Text(i.label),
                            selected: i == _instrument,
                            onSelected: (_) {
                              _setInstrument(i);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                    if (_instrument == PraiseInstrument.violao) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _tuningDrop,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Afinação',
                        ),
                        items: [
                          for (final t in praiseTunings)
                            DropdownMenuItem(
                              value: t.drop,
                              child: Text(t.label),
                            ),
                        ],
                        onChanged: (v) {
                          set(() => _tuningDrop = v ?? 0);
                          _savePrefs();
                        },
                      ),
                    ],
                    if (_instrument.tuning != null) ...[
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
                    Row(
                      children: [
                        const Text('Tamanho'),
                        Expanded(
                          child: Slider(
                            value: _diagramScale,
                            min: 0.7,
                            max: 1.6,
                            divisions: 9,
                            label: '${(_diagramScale * 100).round()}%',
                            onChanged: (v) => set(() => _diagramScale = v),
                            onChangeEnd: (_) => _savePrefs(),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  // Duas colunas só onde cabem.
                  if (wide)
                    card('Exibição', [
                      toggle('Dividir em colunas', _twoColumns, (v) {
                        _setTwoColumns(v);
                        setSheet(() {});
                      }),
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
      context.pushReplacement(
        _itemRoute(widget.ministryId, reading.setlistId, picked.id),
      );
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

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
        ),
        title: widget.reading == null
            ? Text(songAsync.valueOrNull?.title ?? 'Louvor')
            : InkWell(
                borderRadius: BorderRadius.circular(AppTheme.controlRadius),
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
          if (canManage &&
              widget.reading == null &&
              songAsync.valueOrNull != null)
            PopupMenuButton<String>(
              icon: const Icon(AppIcons.more),
              onSelected: (v) {
                if (v == 'edit') {
                  context.push(
                    '/ministries/${widget.ministryId}/louvores/musicas/${widget.songId}/editar',
                  );
                } else {
                  _archive(songAsync.value!);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar (gera nova versão)'),
                ),
                PopupMenuItem(value: 'archive', child: Text('Arquivar')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: widget.reading == null
          ? null
          : _SetlistNav(
              ministryId: widget.ministryId,
              reading: widget.reading!,
            ),
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
    final strip = _ChordStrip(
      chords: _uniqueChords(version.chordpro, flats),
      instrument: _instrument,
      shapeOf: (c) => _shapeOf(c, _instrument, capo),
      scale: _diagramScale,
      onTap: (c) => _openChord(c, capo),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
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
            // Controles pequenos em pílula (referência CifraClub §1.6).
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
            if (capo > 0)
              ActionChip(
                shape: const StadiumBorder(),
                label: Text('Capo $capo'),
                onPressed: () => _openSettings(baseCapo),
              ),
            if (bpm != null)
              ActionChip(
                shape: const StadiumBorder(),
                label: Text('$bpm BPM'),
                onPressed: () => setState(() => _metronome = true),
              ),
            if (_item?.notes != null)
              Chip(shape: const StadiumBorder(), label: Text(_item!.notes!)),
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
        if (_diagramsStart) ...[strip, const SizedBox(height: 12)],
        ChordProView(
          source: version.chordpro,
          semitones: _semitones,
          preferFlats: flats,
          fontSize: _fontSize,
          onChordTap: (c) => _openChord(c, capo),
          twoColumns: _twoColumns,
        ),
        if (_diagramsEnd) ...[const SizedBox(height: 16), strip],
      ],
    );

    if (!_metronome && !_tuner) return list;
    return Stack(
      children: [
        list,
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_tuner)
                TunerPanel(onClose: () => setState(() => _tuner = false)),
              if (_tuner && _metronome) const SizedBox(height: 8),
              if (_metronome)
                MetronomePanel(
                  initialBpm: bpm ?? 80,
                  onClose: () => setState(() => _metronome = false),
                ),
            ],
          ),
        ),
      ],
    );
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

  void _go(BuildContext context, PraiseSetlistItem item) => context
      .pushReplacement(_itemRoute(ministryId, reading.setlistId, item.id));

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
