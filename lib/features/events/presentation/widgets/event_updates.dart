import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_update.dart';
import '../providers/events_provider.dart';

/// Seção "Atualizações" da aba Informações: até 2 itens, sem cabeçalho de
/// dia, e "Ver todas as atualizações" para a tela empilhada. Sem conteúdo
/// (ou sem acesso, ou erro), não aparece. Notícia não tem feed.
class EventUpdatesSummary extends ConsumerWidget {
  final Event event;

  const EventUpdatesSummary({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.eventType == 'news') return const SizedBox.shrink();
    final updates = ref.watch(eventUpdatesProvider(event.id)).valueOrNull;
    if (updates == null || updates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Atualizações', style: CommunityDesign.titleStyle(context)),
        const SizedBox(height: 12),
        for (final u in updates.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventUpdateCard(update: u),
          ),
        if (updates.length > 2)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => context.push('/events/${event.id}/updates'),
              child: Text('Ver todas as atualizações (${updates.length})'),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Tela "Ver todas as atualizações", agrupada por HOJE/ONTEM/data.
class EventUpdatesScreen extends ConsumerWidget {
  final String eventId;

  const EventUpdatesScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventUpdatesProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizações')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const _Vazio('Não foi possível carregar as atualizações.'),
        data: (updates) {
          if (updates.isEmpty) {
            return const _Vazio('Nenhuma atualização ainda.');
          }
          final children = <Widget>[];
          String? dia;
          for (final u in updates) {
            final h = eventUpdateDayHeader(u.createdAt);
            if (h != dia) {
              dia = h;
              children.add(
                Padding(
                  padding: EdgeInsets.only(
                    top: children.isEmpty ? 0 : 12,
                    bottom: 8,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      h,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventUpdateCard(update: u),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(eventUpdatesProvider(eventId).future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          );
        },
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  final String texto;

  const _Vazio(this.texto);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// Cartão de um item do feed. Aviso = megafone azul + "Aviso"; mudança =
/// relógio âmbar (tom escuro no claro, para contraste) + "Mudança".
class EventUpdateCard extends StatelessWidget {
  final EventUpdate update;

  const EventUpdateCard({super.key, required this.update});

  static const _maxLinhas = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cor = update.isNotice
        ? CommunityDesign.accentForeground(context, AppTheme.primaryColor)
        : (dark ? AppTheme.warningColor : const Color(0xFFB45309));
    final rotulo = update.isNotice ? 'Aviso' : 'Mudança';
    final quando = eventUpdateTimeAgo(update.createdAt);

    final String titulo;
    final List<String> linhas;
    if (update.isNotice) {
      titulo = (update.title?.trim().isNotEmpty ?? false)
          ? update.title!.trim()
          : 'Aviso';
      linhas = [update.body ?? ''];
    } else if (update.changes.length == 1) {
      titulo = update.changeTitle;
      linhas = [update.changes.first.fromTo];
    } else {
      titulo = update.changeTitle;
      linhas = [
        for (final c in update.changes.take(_maxLinhas))
          '${c.fieldLabel}: ${c.fromTo}',
        if (update.changes.length > _maxLinhas)
          '+${update.changes.length - _maxLinhas} '
              '${update.changes.length - _maxLinhas == 1 ? 'alteração' : 'alterações'}',
      ];
    }

    return Semantics(
      container: true,
      label: '$rotulo, $quando. $titulo. ${linhas.join('. ')}',
      child: ExcludeSemantics(
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  update.isNotice ? Icons.campaign_outlined : Icons.schedule,
                  size: 20,
                  color: cor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rotulo.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: cor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          quando,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final l in linhas) ...[
                      const SizedBox(height: 4),
                      Text(l, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
