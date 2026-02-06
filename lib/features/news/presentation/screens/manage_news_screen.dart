import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../events/domain/models/event.dart';

class ManageNewsScreen extends ConsumerWidget {
  const ManageNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(allEventsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Gerenciar Notícias',
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/news/admin/new'),
            tooltip: 'Nova notícia',
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final news = events.where(_isNews).toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          if (news.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma notícia cadastrada',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crie uma notícia para aparecer no app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/news/admin/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Criar primeira notícia'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allEventsProvider);
              ref.invalidate(activeEventsProvider);
              ref.invalidate(upcomingEventsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: news.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = news[index];
                final cs = Theme.of(context).colorScheme;
                return Container(
                  decoration: CommunityDesign.overlayDecoration(cs),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.article,
                        color: cs.primary,
                      ),
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(item.startDate),
                            style: CommunityDesign.metaStyle(context),
                          ),
                          if (item.description != null &&
                              item.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CommunityDesign.contentStyle(context)
                                  .copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(
                            item.status == 'published'
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                          tooltip: item.status == 'published'
                              ? 'Despublicar'
                              : 'Publicar',
                          onPressed: () async {
                            final repo = ref.read(eventsRepositoryProvider);
                            try {
                              await repo.updateEvent(
                                item.id,
                                {
                                  'status': item.status == 'published'
                                      ? 'draft'
                                      : 'published',
                                },
                              );
                              ref.invalidate(allEventsProvider);
                              ref.invalidate(activeEventsProvider);
                              ref.invalidate(upcomingEventsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      item.status == 'published'
                                          ? 'Notícia despublicada!'
                                          : 'Notícia publicada!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao atualizar: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Editar',
                          onPressed: () {
                            context.push('/news/admin/${item.id}/edit');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Excluir',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmar exclusão'),
                                content: Text(
                                  'Deseja realmente excluir a notícia "${item.name}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            final repo = ref.read(eventsRepositoryProvider);
                            try {
                              await repo.deleteEvent(item.id);
                              ref.invalidate(allEventsProvider);
                              ref.invalidate(activeEventsProvider);
                              ref.invalidate(upcomingEventsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notícia excluída!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao excluir: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () => context.push('/news/admin/${item.id}/edit'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allEventsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNews(Event e) {
    return (e.eventType ?? '').trim().toLowerCase() == 'news';
  }

  String _formatDateTime(DateTime dt) {
    final date = DateFormat('dd/MM/yyyy', 'pt_BR').format(dt);
    final time = DateFormat('HH:mm', 'pt_BR').format(dt);
    return '$date • $time';
  }
}

