import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'praise_setlists_view.dart';
import 'providers/praise_providers.dart';

/// Repertórios que outro ministério mandou para [ministryId] (canvas, tela
/// 11). Só leitura: sem Biblioteca e sem "Novo repertório" — o destinatário
/// não tem `praise_can_view()`, a RLS só abre o que foi recebido.
class PraiseReceivedView extends ConsumerWidget {
  final String ministryId;

  const PraiseReceivedView({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(praiseReceivedProvider(ministryId));
    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PraiseMessage(
        title: 'Não deu para carregar os repertórios recebidos',
        message: praiseErrorText(e),
        onRetry: () => ref.invalidate(praiseReceivedProvider(ministryId)),
      ),
      data: (all) {
        final now = DateTime.now();
        bool upcoming(PraiseSetlist s) =>
            s.eventStart != null &&
            PraiseSetlistsView.isUpcoming(s.eventStart!, now);
        // Próximos primeiro (do mais perto), depois o resto (mais recente).
        final list = [...all]
          ..sort((a, b) {
            if (upcoming(a) != upcoming(b)) return upcoming(a) ? -1 : 1;
            if (upcoming(a)) return a.eventStart!.compareTo(b.eventStart!);
            final pa = a.published?.publishedAt ?? DateTime(0);
            final pb = b.published?.publishedAt ?? DateTime(0);
            return pb.compareTo(pa);
          });
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(praiseReceivedProvider(ministryId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  'REPERTÓRIOS RECEBIDOS',
                  style: CommunityDesign.metaStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
              if (list.isEmpty)
                const PraiseMessage(
                  title: 'Nenhum repertório recebido',
                  message:
                      'Quando um ministério de louvor publicar um repertório '
                      'para este ministério, ele aparece aqui.',
                ),
              for (final s in list)
                _ReceivedCard(ministryId: ministryId, setlist: s),
            ],
          ),
        );
      },
    );
  }
}

class _ReceivedCard extends ConsumerWidget {
  final String ministryId;
  final PraiseSetlist setlist;

  const _ReceivedCard({required this.ministryId, required this.setlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rev = setlist.published!;
    final meta = CommunityDesign.metaStyle(context);
    final by = ref.watch(praisePublisherNameProvider(rev.id)).valueOrNull;
    final when = setlist.eventStart == null
        ? null
        : DateFormat('EEE dd/MM · HH:mm', 'pt_BR').format(setlist.eventStart!);
    final count =
        '${rev.itemCount} ${rev.itemCount == 1 ? 'música' : 'músicas'}';
    final from = [
      'Enviado por ${setlist.ministryName ?? 'outro ministério'}',
      if (rev.publishedAt != null)
        'publicado em '
            '${DateFormat('dd/MM', 'pt_BR').format(rev.publishedAt!.toLocal())}'
            '${by == null ? '' : ' por $by'}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => context.push(
          '/ministries/$ministryId/louvores/recebidos/${setlist.id}',
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        rev.title,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 15),
                      ),
                      if (rev.number > 1)
                        SetlistStatusChip(
                          label: 'Atualizado · rev. ${rev.number}',
                          published: true,
                        ),
                    ],
                  ),
                  Text([?when, count].join(' · '), style: meta),
                  Text(from, style: meta.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(AppIcons.forward, size: 18),
          ],
        ),
      ),
    );
  }
}
