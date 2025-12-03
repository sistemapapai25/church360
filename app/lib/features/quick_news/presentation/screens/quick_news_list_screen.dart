import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/quick_news_provider.dart';
import '../../domain/models/quick_news.dart';

/// Tela de listagem e gerenciamento de avisos rápidos (Fique por Dentro)
class QuickNewsListScreen extends ConsumerWidget {
  const QuickNewsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(allQuickNewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fique por Dentro'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/quick-news/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Aviso'),
      ),
      body: newsAsync.when(
        data: (newsList) {
          if (newsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum aviso cadastrado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para criar o primeiro aviso',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allQuickNewsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: newsList.length,
              itemBuilder: (context, index) {
                final news = newsList[index];
                return _NewsCard(news: news);
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
              Text(
                'Erro ao carregar avisos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(allQuickNewsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card de Aviso
// =====================================================

class _NewsCard extends ConsumerWidget {
  final QuickNews news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/home/quick-news/${news.id}/edit'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Título + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      news.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge de status
                  _StatusBadge(news: news),
                ],
              ),
              const SizedBox(height: 8),

              // Descrição
              Text(
                news.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Informações adicionais
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  // Prioridade
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Prioridade: ${news.priority}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  // Data de criação
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(news.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  // Data de expiração (se houver)
                  if (news.expiresAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 16,
                          color: news.isExpired ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expira: ${dateFormat.format(news.expiresAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: news.isExpired ? Colors.red : Colors.orange,
                              ),
                        ),
                      ],
                    ),
                ],
              ),

              // Ações
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botão Editar
                  TextButton.icon(
                    onPressed: () => context.push('/home/quick-news/${news.id}/edit'),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),

                  // Botão Deletar
                  TextButton.icon(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Aviso'),
        content: Text('Deseja realmente excluir o aviso "${news.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(quickNewsRepositoryProvider);
                await repo.deleteNews(news.id);
                ref.invalidate(allQuickNewsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aviso excluído com sucesso!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// WIDGET: Badge de Status
// =====================================================

class _StatusBadge extends StatelessWidget {
  final QuickNews news;

  const _StatusBadge({required this.news});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (!news.isActive) {
      label = 'Inativo';
      color = Colors.grey;
    } else if (news.isExpired) {
      label = 'Expirado';
      color = Colors.red;
    } else {
      label = 'Ativo';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
