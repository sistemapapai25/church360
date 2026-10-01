import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../praise/domain/chord.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
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
        final rev = [
          s?.published,
          s?.draft,
        ].where((r) => r?.items.any((i) => i.id == itemId) ?? false).firstOrNull;
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

  /// Nulo = a versão mais recente.
  PraiseSongVersion? _picked;

  PraiseSetlistItem? get _item {
    final r = widget.reading;
    return r == null ? null : r.revision.items[r.index];
  }

  @override
  void initState() {
    super.initState();
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
        title: widget.reading == null
            ? Text(songAsync.valueOrNull?.title ?? 'Louvor')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_item!.songTitle),
                  Text(
                    '${widget.reading!.revision.title} · '
                    '${widget.reading!.index + 1} de '
                    '${widget.reading!.revision.items.length}',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
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
          : _SetlistNav(ministryId: widget.ministryId, reading: widget.reading!),
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

    return ListView(
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
            // No repertório, capo/BPM/observação são os do culto.
            if ((_item?.capo ?? version.capo) > 0)
              Chip(label: Text('Capo ${_item?.capo ?? version.capo}')),
            if ((_item == null ? version.bpm : _item!.bpm) != null)
              Chip(
                label: Text('${_item == null ? version.bpm : _item!.bpm} BPM'),
              ),
            if (_item?.notes != null) Chip(label: Text(_item!.notes!)),
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
        if (_item == null && _semitones % 12 != 0 && keyLabel != null)
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

/// Anterior / próxima do repertório (contrato do leitor §3.2). Troca a rota
/// no lugar, para o voltar levar direto ao repertório.
class _SetlistNav extends StatelessWidget {
  final String ministryId;
  final _SetlistReading reading;

  const _SetlistNav({required this.ministryId, required this.reading});

  void _go(BuildContext context, PraiseSetlistItem item) =>
      context.pushReplacement(
        '/ministries/$ministryId/louvores/repertorios/'
        '${reading.setlistId}/itens/${item.id}',
      );

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
