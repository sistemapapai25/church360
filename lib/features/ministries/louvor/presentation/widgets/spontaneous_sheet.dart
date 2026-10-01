import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/praise_repository.dart';
import '../louvores_tab.dart';
import '../providers/praise_providers.dart';

/// "Espontâneo": no meio do culto entra um louvor fora do repertório. Busca
/// na biblioteca e mostra em que tom o ministrante já cantou cada música,
/// tirado dos repertórios publicados. Só consulta: não mexe no repertório.
/// [ministerId] = quem já vem marcado (o do item aberto).
Future<void> showSpontaneousSheet(
  BuildContext context, {
  required String ministryId,
  String? ministerId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _SpontaneousSheet(ministryId: ministryId, ministerId: ministerId),
);

class _SpontaneousSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final String? ministerId;

  const _SpontaneousSheet({required this.ministryId, this.ministerId});

  @override
  ConsumerState<_SpontaneousSheet> createState() => _SpontaneousSheetState();
}

class _SpontaneousSheetState extends ConsumerState<_SpontaneousSheet> {
  late String? _minister = widget.ministerId;
  String _query = '';

  void _open(PraiseSong song, String? key) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(
      Uri(
        path: '/ministries/${widget.ministryId}/louvores/musicas/${song.id}',
        queryParameters: key == null ? null : {'tom': key},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final songs = [
      for (final s in ref.watch(praiseSongsProvider).valueOrNull ?? const [])
        if (s.latest != null && praiseSongMatches(s, _query)) s,
    ];
    final members =
        ref.watch(ministryMembersProvider(widget.ministryId)).valueOrNull ??
        const [];
    final name = members
        .where((m) => m.memberId == _minister)
        .firstOrNull
        ?.memberName;
    final history = _minister == null
        ? null
        : ref.watch(praiseMinisterKeysProvider(_minister!));
    final keys = history?.valueOrNull ?? const {};

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Espontâneo',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Em que tom o ministrante já cantou, pelos repertórios '
              'publicados.',
              style: meta,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Recria quando a lista chega; quem saiu do ministério abre vazio.
              key: ValueKey('minister-${members.length}'),
              initialValue: name == null ? null : _minister,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ministrante'),
              items: [
                for (final m in members)
                  DropdownMenuItem(
                    value: m.memberId,
                    child: Text(m.memberName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _minister = id),
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(AppIcons.search),
                hintText: 'Buscar por título, artista ou trecho',
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
            if (history?.isLoading ?? false)
              const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text('Nenhuma música encontrada.', style: meta),
                    )
                  : ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, i) {
                        final s = songs[i];
                        return _SongTile(
                          song: s,
                          uses: keys[s.id],
                          ministerName: name,
                          onOpen: (key) => _open(s, key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final PraiseSong song;
  final List<PraiseKeyUse>? uses;
  final String? ministerName;
  final ValueChanged<String?> onOpen;

  const _SongTile({
    required this.song,
    required this.uses,
    required this.ministerName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final original = song.latest?.originalKey;
    final latest = uses == null ? null : praiseLatestKey(uses!);
    final date = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        onTap: () => onOpen(latest?.key),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                song.title,
                if (song.artist?.isNotEmpty ?? false) song.artist,
              ].join(' — '),
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
            ),
            if (latest != null) ...[
              Text(
                '$ministerName · último tom ${latest.key} em '
                '${date.format(latest.last)}',
                style: meta,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final u in uses!)
                    ActionChip(
                      label: Text('${u.key} · ${u.times}x'),
                      tooltip: 'Abrir em ${u.key}',
                      onPressed: () => onOpen(u.key),
                    ),
                ],
              ),
            ] else ...[
              if (ministerName != null)
                Text('Nenhum histórico de tom para $ministerName', style: meta),
              const SizedBox(height: 6),
              ActionChip(
                label: Text(
                  original == null ? 'Abrir cifra' : 'Tom original · $original',
                ),
                onPressed: () => onOpen(null),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
