import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../praise/domain/chord.dart';
import '../../data/praise_repository.dart';
import '../providers/praise_providers.dart';

/// Folha "Adicionar ao repertório" (canvas, tela 7). Com [initial], edita o
/// item. Devolve o item montado; quem chama decide quando salvar.
Future<PraiseSetlistItem?> showSetlistItemSheet(
  BuildContext context, {
  PraiseSetlistItem? initial,
}) => showModalBottomSheet<PraiseSetlistItem>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SetlistItemSheet(initial: initial),
);

/// Mesmo formato do CHECK `praise_setlist_item_key_shape`.
final _keyShape = RegExp(r'^[A-G][#b]?m?$');

class _SetlistItemSheet extends ConsumerStatefulWidget {
  final PraiseSetlistItem? initial;

  const _SetlistItemSheet({this.initial});

  @override
  ConsumerState<_SetlistItemSheet> createState() => _SetlistItemSheetState();
}

class _SetlistItemSheetState extends ConsumerState<_SetlistItemSheet> {
  String? _songId;
  PraiseSongVersion? _version;
  int _semitones = 0;
  final _capo = TextEditingController();
  final _bpm = TextEditingController();
  final _notes = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _songId = i.version.songId;
      _version = i.version;
      final from = i.version.originalKey;
      if (from != null &&
          i.selectedKey != null &&
          Chord.tryParse(from) != null) {
        _semitones = Chord.interval(from, i.selectedKey!);
      }
      _capo.text = '${i.capo}';
      _bpm.text = i.bpm?.toString() ?? '';
      _notes.text = i.notes ?? '';
    }
  }

  @override
  void dispose() {
    _capo.dispose();
    _bpm.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Capo e BPM vêm da versão; mudar aqui vale só para este culto.
  void _useVersion(PraiseSongVersion v) {
    setState(() {
      _version = v;
      _semitones = 0;
      _capo.text = '${v.capo}';
      _bpm.text = v.bpm?.toString() ?? '';
    });
  }

  String? get _selectedKey {
    final from = _version?.originalKey;
    if (from == null) return null;
    final k = Chord.shiftKey(from, _semitones);
    return k != null && _keyShape.hasMatch(k) ? k : null;
  }

  void _submit(PraiseSong song) {
    final v = _version;
    if (v == null) return;
    final capo = int.tryParse(_capo.text.trim()) ?? 0;
    final bpmText = _bpm.text.trim();
    final bpm = bpmText.isEmpty ? null : int.tryParse(bpmText);
    if (capo < 0 || capo > 11) {
      setState(() => _error = 'Capo vai de 0 a 11.');
      return;
    }
    if (bpmText.isNotEmpty && (bpm == null || bpm < 20 || bpm > 400)) {
      setState(() => _error = 'BPM vai de 20 a 400.');
      return;
    }
    final notes = _notes.text.trim();
    Navigator.pop(
      context,
      PraiseSetlistItem(
        id: widget.initial?.id,
        version: v,
        songTitle: song.title,
        artist: song.artist,
        selectedKey: _selectedKey,
        capo: capo,
        bpm: bpm,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(praiseSongsProvider).valueOrNull ?? const [];
    final i = widget.initial;
    final withChords = [
      for (final s in songs)
        if (s.latest != null) s,
      // Música arquivada depois de entrar no repertório: some da biblioteca,
      // mas o item continua editável.
      if (i != null && !songs.any((s) => s.id == i.version.songId))
        PraiseSong(id: i.version.songId, title: i.songTitle, artist: i.artist),
    ];
    final song = withChords.where((s) => s.id == _songId).firstOrNull;
    final versions = _songId == null
        ? const <PraiseSongVersion>[]
        : ref.watch(praiseVersionsProvider(_songId!)).valueOrNull ?? const [];
    final meta = CommunityDesign.metaStyle(context);
    final original = _version?.originalKey;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null
                  ? 'Adicionar ao repertório'
                  : 'Música do repertório',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _songId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Música'),
              items: [
                for (final s in withChords)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.artist == null || s.artist!.isEmpty
                          ? s.title
                          : '${s.title} — ${s.artist}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final s = withChords.firstWhere((s) => s.id == id);
                setState(() => _songId = id);
                if (s.latest != null) _useVersion(s.latest!);
              },
            ),
            if (song != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // A chave muda com a música: sem ela o campo guarda o valor
                // da música anterior.
                key: ValueKey('versions-$_songId-${versions.length}'),
                initialValue: _version?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Versão da cifra'),
                items: [
                  for (final v in versions.isEmpty ? [_version!] : versions)
                    DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        'Versão ${v.versionNumber}'
                        '${v.id == song.latest?.id ? ' (mais recente)' : ''}'
                        '${v.originalKey == null ? '' : ' · original ${v.originalKey}'}',
                      ),
                    ),
                ],
                onChanged: (id) =>
                    _useVersion(versions.firstWhere((v) => v.id == id)),
              ),
              const SizedBox(height: 12),
              if (original != null && Chord.tryParse(original) != null) ...[
                Text('Tom neste culto', style: meta),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Meio tom abaixo',
                      icon: const Icon(AppIcons.remove),
                      onPressed: () => setState(() => _semitones--),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _selectedKey ?? original,
                        textAlign: TextAlign.center,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Meio tom acima',
                      icon: const Icon(AppIcons.add),
                      onPressed: () => setState(() => _semitones++),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _semitones % 12 == 0
                            ? 'tom original'
                            : 'original $original',
                        style: meta,
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  'Esta versão não tem tom cadastrado: o leitor mostra a cifra '
                  'como está.',
                  style: meta,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _capo,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Capo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bpm,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'BPM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Vêm preenchidos da versão. Mudar aqui vale só para este culto.',
                style: meta,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  hintText: 'Ex.: entrar só no refrão',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _submit(song),
                child: Text(widget.initial == null ? 'Adicionar' : 'Salvar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
