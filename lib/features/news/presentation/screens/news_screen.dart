import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../events/presentation/providers/events_provider.dart';
import '../../../events/domain/models/event.dart';
import '../../../../core/design/community_design.dart';

/// Tela de Notícias (usa os mesmos dados de Eventos)
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(allEventsProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          toolbarHeight: 60,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          backgroundColor: CommunityDesign.headerColor(context),
          surfaceTintColor: Colors.transparent,
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.article_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Notícias', style: CommunityDesign.titleStyle(context)),
                  const SizedBox(height: 2),
                  Text(
                    'Fique por dentro das novidades',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              final cs = Theme.of(context).colorScheme;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    decoration: CommunityDesign.overlayDecoration(cs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 56,
                          color: cs.primary.withValues(alpha: 0.28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma notícia no momento',
                          style: CommunityDesign.titleStyle(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'As notícias aparecerão aqui quando forem publicadas',
                          style: CommunityDesign.contentStyle(context).copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Ordenar eventos por data (mais recentes primeiro)
            final sortedEvents = [...events]
              ..sort((a, b) => b.startDate.compareTo(a.startDate));

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allEventsProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: sortedEvents.length,
                itemBuilder: (context, index) {
                  final event = sortedEvents[index];
                  return _NewsCard(event: event);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: cs.error.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Erro ao carregar notícias',
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ocorreu um problema ao buscar as notícias. Tente novamente.',
                          style: CommunityDesign.contentStyle(context).copyWith(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            ref.invalidate(allEventsProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Card de Notícia
class _NewsCard extends StatelessWidget {
  final Event event;

  const _NewsCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final timeFormat = DateFormat('HH:mm', 'pt_BR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(cs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/events/${event.id}');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem
                if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 6,
                    child: Image.network(
                      event.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 64,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 6,
                    child: Container(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(
                          Icons.event,
                          size: 64,
                          color: cs.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),

                // Conteúdo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Text(
                        event.name,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 18, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Data e Hora com chips
                      Row(
                        children: [
                          Expanded(
                            child: CommunityDesign.badge(
                              context,
                              dateFormat.format(event.startDate),
                              cs.primary,
                              icon: Icons.calendar_today,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommunityDesign.badge(
                              context,
                              timeFormat.format(event.startDate),
                              cs.secondary,
                              icon: Icons.access_time,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Descrição
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        Text(
                          event.description!,
                          style: CommunityDesign.contentStyle(context).copyWith(
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Local
                      if (event.location != null &&
                          event.location!.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: CommunityDesign.authorStyle(context)
                                    .copyWith(
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ] else
                        const SizedBox(height: 4),

                      // Botão "Ler mais"
                      TextButton(
                        onPressed: () {
                          context.push('/events/${event.id}');
                        },
                        style: CommunityDesign.pillButtonStyle(
                          context,
                          cs.primary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'LER NOTÍCIA COMPLETA',
                              style: CommunityDesign.contentStyle(context).copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: cs.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
