import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../praise/domain/chord.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'providers/praise_providers.dart';
import 'widgets/chordpro_view.dart';

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

class _Reader extends ConsumerStatefulWidget {
  final String ministryId;
  final String songId;

  const _Reader({required this.ministryId, required this.songId});

  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

class _ReaderState extends ConsumerState<_Reader> {
  int _semitones = 0;
  double _fontSize = 15;

  /// Nulo = a versão mais recente.
  PraiseSongVersion? _picked;

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
        title: Text(songAsync.valueOrNull?.title ?? 'Louvor'),
        actions: [
          IconButton(
            tooltip: 'Versões',
            icon: const Icon(AppIcons.history),
            onPressed: _pickVersion,
          ),
          if (canManage && songAsync.valueOrNull != null)
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
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Não deu para abrir a música.\n$e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (song) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      children: [
        if (song.artist != null && song.artist!.isNotEmpty)
          Text(song.artist!, style: meta),
        if (_picked != null && _picked!.id != song.latest?.id)
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
            IconButton.outlined(
              tooltip: 'Meio tom abaixo',
              icon: const Icon(AppIcons.remove),
              onPressed: () => setState(() => _semitones--),
            ),
            GestureDetector(
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
            IconButton.outlined(
              tooltip: 'Meio tom acima',
              icon: const Icon(AppIcons.add),
              onPressed: () => setState(() => _semitones++),
            ),
            if (version.capo > 0) Chip(label: Text('Capo ${version.capo}')),
            if (version.bpm != null) Chip(label: Text('${version.bpm} BPM')),
            IconButton(
              tooltip: 'Diminuir letra',
              icon: const Icon(AppIcons.zoomOut),
              onPressed: _fontSize > 11
                  ? () => setState(() => _fontSize--)
                  : null,
            ),
            IconButton(
              tooltip: 'Aumentar letra',
              icon: const Icon(AppIcons.zoomIn),
              onPressed: _fontSize < 26
                  ? () => setState(() => _fontSize++)
                  : null,
            ),
          ],
        ),
        if (_semitones % 12 != 0 && keyLabel != null)
          Text(
            'Original em ${version.originalKey}. Trocar o tom aqui não altera a música.',
            style: meta,
          ),
        const SizedBox(height: 16),
        ChordProView(
          source: version.chordpro,
          semitones: _semitones,
          preferFlats: flats,
          fontSize: _fontSize,
        ),
      ],
    );
  }
}
