import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../praise/domain/chord_shapes.dart';
import '../../../praise/domain/chordpro.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'providers/praise_providers.dart';
import 'widgets/chordpro_view.dart';

const _keys = [
  'C',
  'C#',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'F#',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
  'Cm',
  'C#m',
  'Dm',
  'D#m',
  'Ebm',
  'Em',
  'Fm',
  'F#m',
  'Gm',
  'G#m',
  'Am',
  'Bbm',
  'Bm',
];

/// Cadastro e edição de louvor. Salvar uma edição grava uma VERSÃO NOVA —
/// o repertório que aponta para a anterior continua igual.
///
/// A cifra pode ser colada no formato "acordes em cima da letra" (o que se
/// copia de site): ela é convertida para ChordPro na prévia e ao salvar.
class PraiseSongEditorScreen extends StatelessWidget {
  final String ministryId;

  /// Nulo = música nova.
  final String? songId;

  const PraiseSongEditorScreen({
    super.key,
    required this.ministryId,
    this.songId,
  });

  @override
  Widget build(BuildContext context) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) => _Editor(ministryId: ministryId, songId: songId),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  final String ministryId;
  final String? songId;

  const _Editor({required this.ministryId, this.songId});

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _source = TextEditingController();
  final _chords = TextEditingController();
  final _bpm = TextEditingController();
  final _note = TextEditingController();
  String? _key;
  int _capo = 0;
  bool _preview = false;
  bool _saving = false;

  /// Carregado uma vez, para comparar no salvar.
  PraiseSong? _original;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.songId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final song = await ref.read(praiseSongProvider(widget.songId!).future);
    if (!mounted) return;
    final v = song?.latest;
    setState(() {
      _original = song;
      _title.text = song?.title ?? '';
      _artist.text = song?.artist ?? '';
      _source.text = song?.sourceUrl ?? '';
      _chords.text = v?.chordpro ?? '';
      _bpm.text = v?.bpm?.toString() ?? '';
      _key = _keys.contains(v?.originalKey) ? v!.originalKey : null;
      _capo = v?.capo ?? 0;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _artist, _source, _chords, _bpm, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _trimOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    // Na prévia o campo da cifra não está montado e o validator não roda.
    if (_chords.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A cifra não pode ficar vazia.')),
      );
      return;
    }
    if (_original == null && !await _confirmNotDuplicate()) return;
    final repo = ref.read(praiseRepositoryProvider);
    final draft = PraiseVersionDraft(
      chordpro: chordsOverLyricsToChordPro(_chords.text.trim()),
      originalKey: _key,
      capo: _capo,
      bpm: int.tryParse(_bpm.text.trim()),
      changeNote: _trimOrNull(_note),
    );

    setState(() => _saving = true);
    try {
      String songId;
      if (_original == null) {
        songId = await repo.createSong(
          title: _title.text.trim(),
          artist: _trimOrNull(_artist),
          sourceUrl: _trimOrNull(_source),
          fromMinistryId: widget.ministryId,
          version: draft,
        );
      } else {
        songId = _original!.id;
        final infoChanged =
            _title.text.trim() != _original!.title ||
            _trimOrNull(_artist) != _original!.artist ||
            _trimOrNull(_source) != _original!.sourceUrl;
        final v = _original!.latest;
        final versionChanged =
            v == null ||
            draft.chordpro != v.chordpro ||
            draft.originalKey != v.originalKey ||
            draft.capo != v.capo ||
            draft.bpm != v.bpm;
        if (!infoChanged && !versionChanged) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Nada mudou.')));
          }
          return;
        }
        if (infoChanged) {
          await repo.updateSongInfo(
            songId,
            title: _title.text.trim(),
            artist: _trimOrNull(_artist),
            sourceUrl: _trimOrNull(_source),
          );
        }
        if (versionChanged) await repo.addVersion(songId, draft);
      }
      invalidatePraise(ref, songId);
      if (!mounted) return;
      if (_original == null) {
        context.pushReplacement(
          '/ministries/${widget.ministryId}/louvores/musicas/$songId',
        );
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Plano §8: música nova com o mesmo título (sem acento/caixa) de outra
  /// da biblioteca. Nunca sobrescreve: abrir a existente ou criar mesmo assim.
  Future<bool> _confirmNotDuplicate() async {
    final List<PraiseSong> songs;
    try {
      songs = await ref.read(praiseSongsProvider.future);
    } catch (_) {
      return true; // sem a lista, não trava o cadastro
    }
    final title = foldTitle(_title.text);
    final artist = foldTitle(_artist.text);
    final same = songs.where(
      (s) =>
          foldTitle(s.title) == title &&
          (artist.isEmpty ||
              s.artist == null ||
              foldTitle(s.artist!) == artist),
    );
    if (same.isEmpty || !mounted) return true;
    final song = same.first;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Música já cadastrada'),
        content: Text(
          '"${song.title}"${song.artist == null ? '' : ' — ${song.artist}'} '
          'já está na biblioteca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'open'),
            child: const Text('Abrir a existente'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'create'),
            child: const Text('Criar mesmo assim'),
          ),
        ],
      ),
    );
    if (choice == 'open' && mounted) {
      context.pushReplacement(
        '/ministries/${widget.ministryId}/louvores/musicas/${song.id}',
      );
    }
    return choice == 'create';
  }

  /// Arquivo .txt / .cho / .pro (plano §3): o texto entra no campo da cifra
  /// como se tivesse sido colado. Título e artista vêm do `{title}` e do
  /// `{artist}` quando os campos estão vazios.
  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'cho',
        'pro',
        'chordpro',
        'chopro',
        'crd',
      ],
      withData: true,
    );
    final bytes = picked?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (_chords.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trocar a cifra?'),
          content: const Text(
            'O texto do arquivo substitui o que está no campo da cifra.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final doc = parseChordPro(text);
    setState(() {
      _chords.text = text;
      if (_title.text.trim().isEmpty) _title.text = doc.meta('title') ?? '';
      if (_artist.text.trim().isEmpty) {
        _artist.text = doc.meta('artist') ?? doc.meta('subtitle') ?? '';
      }
    });
  }

  /// Monta a batida com botões e põe `{batida: ...}` numa linha própria,
  /// antes da linha onde está o cursor (de preferência logo abaixo do título
  /// da seção). Ninguém digita código.
  Future<void> _insertStrum() async {
    final pattern = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _StrumBuilderSheet(),
    );
    if (pattern == null || pattern.isEmpty) return;
    _insertLine('{batida: ${pattern.join(' ')}}');
  }

  /// Grade da bateria da seção, montada tocando nos quadrados.
  Future<void> _insertDrums() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _DrumBuilderSheet(),
    );
    if (value == null || value.isEmpty) return;
    _insertLine('{bateria: $value}');
  }

  /// Linha própria antes da linha do cursor.
  void _insertLine(String directive) {
    final text = _chords.text;
    final cursor = _chords.selection.isValid
        ? _chords.selection.start.clamp(0, text.length)
        : text.length;
    final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    final line = '$directive\n';
    setState(() {
      _chords.value = TextEditingValue(
        text: text.replaceRange(lineStart, lineStart, line),
        selection: TextSelection.collapsed(offset: lineStart + line.length),
      );
    });
  }

  /// Correção da linha do cursor para um instrumento (§9.5): vira
  /// `{baixo: G - F#}` logo abaixo dela e vale só para quem lê com ele.
  Future<void> _insertFix() async {
    final text = _chords.text;
    final cursor = _chords.selection.isValid
        ? _chords.selection.start.clamp(0, text.length)
        : text.length;
    final at = instrumentFixAt(text, cursor);
    if (at.chords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponha o cursor numa linha com acordes.')),
      );
      return;
    }
    final fix = await showModalBottomSheet<(PraiseInstrument, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _FixSheet(chords: at.chords),
    );
    if (fix == null || fix.$2.trim().isEmpty) return;
    final line = '\n{${fix.$1.name}: ${fix.$2.trim()}}';
    setState(() {
      _chords.value = TextEditingValue(
        text: text.replaceRange(at.offset, at.offset, line),
        selection: TextSelection.collapsed(offset: at.offset + line.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref
        .watch(praiseAccessProvider)
        .maybeWhen(data: (a) => a.canManage, orElse: () => false);
    final editing = widget.songId != null;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(editing ? 'Editar música' : 'Nova música'),
        actions: [
          if (canManage)
            TextButton(
              onPressed: _saving || !_loaded ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        // §10.4 S3: em tela larga o conteúdo não estica de ponta a ponta.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: !canManage
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Cadastrar e editar músicas exige a permissão "Gerenciar louvores".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : !_loaded
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Informe o título'
                            : null,
                      ),
                      TextFormField(
                        controller: _artist,
                        decoration: const InputDecoration(
                          labelText: 'Artista / ministério',
                        ),
                      ),
                      TextFormField(
                        controller: _source,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Link da cifra original (referência)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<String?>(
                              initialValue: _key,
                              decoration: const InputDecoration(
                                labelText: 'Tom',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('—'),
                                ),
                                for (final k in _keys)
                                  DropdownMenuItem(value: k, child: Text(k)),
                              ],
                              onChanged: (v) => setState(() => _key = v),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<int>(
                              initialValue: _capo,
                              decoration: const InputDecoration(
                                labelText: 'Capo',
                              ),
                              items: [
                                for (var i = 0; i <= 11; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(i == 0 ? 'Sem' : '$i'),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _capo = v ?? 0),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: _bpm,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'BPM',
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return null;
                                final n = int.tryParse(t);
                                return n == null || n < 20 || n > 400
                                    ? '20 a 400'
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTabs(
                        tabs: const [
                          AppTab(label: 'Cifra'),
                          AppTab(label: 'Prévia'),
                        ],
                        selectedIndex: _preview ? 1 : 0,
                        onChanged: (i) => setState(() => _preview = i == 1),
                      ),
                      const SizedBox(height: 8),
                      if (_preview)
                        ChordProView(
                          source: chordsOverLyricsToChordPro(_chords.text),
                        )
                      else ...[
                        Text(
                          'Cole a cifra como vem do site (acordes em cima da letra) '
                          'ou em ChordPro. Rótulos como [Refrão] viram título de seção.',
                          style: CommunityDesign.metaStyle(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _chords,
                          minLines: 12,
                          maxLines: null,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'A cifra não pode ficar vazia'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(AppIcons.upload),
                              label: const Text('Importar arquivo'),
                              onPressed: _importFile,
                            ),
                            OutlinedButton.icon(
                              icon: const Text('↓↑'),
                              label: const Text('Inserir batida'),
                              onPressed: _insertStrum,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(AppIcons.drums),
                              label: const Text('Inserir bateria'),
                              onPressed: _insertDrums,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(AppIcons.edit),
                              label: const Text(
                                'Corrigir linha p/ instrumento',
                              ),
                              onPressed: _insertFix,
                            ),
                          ],
                        ),
                      ],
                      if (editing) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _note,
                          decoration: const InputDecoration(
                            labelText: 'O que mudou nesta versão (opcional)',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Montador da batida: ↓, ↑ e pausa, com a prévia igual à do leitor.
class _StrumBuilderSheet extends StatefulWidget {
  const _StrumBuilderSheet();

  @override
  State<_StrumBuilderSheet> createState() => _StrumBuilderSheetState();
}

class _StrumBuilderSheetState extends State<_StrumBuilderSheet> {
  final _pattern = <String>[];

  @override
  Widget build(BuildContext context) {
    Widget add(String label, String code, String tooltip) => Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        onPressed: _pattern.length < 32
            ? () => setState(() => _pattern.add(code))
            : null,
        child: Text(label),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batida', style: CommunityDesign.titleStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Cada toque é uma colcheia (1 & 2 & ...). Use a pausa onde não '
              'há ataque.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(8),
              decoration: CommunityDesign.overlayDecoration(
                Theme.of(context).colorScheme,
              ),
              child: _pattern.isEmpty
                  ? Text(
                      'Toque nos botões abaixo.',
                      style: CommunityDesign.metaStyle(context),
                    )
                  : StrumView(pattern: _pattern),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                add('↓', 'D', 'Para baixo'),
                add('↑', 'U', 'Para cima'),
                add('pausa', '.', 'Sem ataque'),
                IconButton(
                  tooltip: 'Apagar o último',
                  icon: const Icon(AppIcons.backspace),
                  onPressed: _pattern.isEmpty
                      ? null
                      : () => setState(() => _pattern.removeLast()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _pattern.isEmpty
                    ? null
                    : () => Navigator.pop(context, _pattern),
                child: const Text('Inserir na cifra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instrumento + acordes da linha como ele deve tocar. Começa com os acordes
/// da própria linha; `-` mantém o gerado daquele acorde.
class _FixSheet extends StatefulWidget {
  final String chords;

  const _FixSheet({required this.chords});

  @override
  State<_FixSheet> createState() => _FixSheetState();
}

class _FixSheetState extends State<_FixSheet> {
  var _instrument = PraiseInstrument.baixo;
  late final _text = TextEditingController(text: widget.chords);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Corrigir linha', style: CommunityDesign.titleStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Só quem lê com este instrumento vê a troca. Um acorde por '
              'posição, na ordem da linha; "-" mantém o original.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in PraiseInstrument.pickable)
                  ChoiceChip(
                    label: Text(i.label),
                    selected: _instrument == i,
                    onSelected: (_) => setState(() => _instrument = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Acordes para ${_instrument.label.toLowerCase()}',
                helperText: 'Original: ${widget.chords}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (_instrument, _text.text)),
                child: const Text('Inserir na cifra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Montador da grade de bateria: 8 ou 16 toques por compasso, uma linha por
/// peça, com a prévia igual à do leitor.
class _DrumBuilderSheet extends StatefulWidget {
  const _DrumBuilderSheet();

  @override
  State<_DrumBuilderSheet> createState() => _DrumBuilderSheetState();
}

class _DrumBuilderSheetState extends State<_DrumBuilderSheet> {
  var _steps = 8;
  final _grid = {for (final v in drumVoices.keys) v: List.filled(16, false)};

  Map<String, List<bool>> get _value => {
    for (final e in _grid.entries) e.key: e.value.sublist(0, _steps),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = drumsToValue(_value).isEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bateria', style: CommunityDesign.titleStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Um compasso. Toque nos quadrados de cada peça.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            // §10.4 S1: pílula do sistema, não SegmentedButton.
            AppTabs(
              tabs: const [
                AppTab(label: '8 (colcheias)'),
                AppTab(label: '16 (semicolcheias)'),
              ],
              selectedIndex: _steps == 8 ? 0 : 1,
              onChanged: (i) => setState(() => _steps = i == 0 ? 8 : 16),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final MapEntry(key: v, value: label)
                      in drumVoices.entries)
                    Row(
                      children: [
                        SizedBox(width: 72, child: Text(label)),
                        for (var i = 0; i < _steps; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: (i + 1) % (_steps > 8 ? 4 : 2) == 0
                                  ? 8
                                  : 2,
                              bottom: 4,
                            ),
                            child: Semantics(
                              label: '$label ${i + 1}',
                              toggled: _grid[v]![i],
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => setState(
                                  () => _grid[v]![i] = !_grid[v]![i],
                                ),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: _grid[v]![i]
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: empty
                    ? null
                    : () => Navigator.pop(context, drumsToValue(_value)),
                child: const Text('Inserir na cifra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
