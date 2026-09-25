import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/quick_news_provider.dart';
import '../../domain/models/quick_news.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de listagem e gerenciamento de avisos rápidos (Fique por Dentro)
class QuickNewsListScreen extends ConsumerWidget {
  const QuickNewsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(allQuickNewsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Fique por Dentro'),
        centerTitle: true,
      ),
      floatingActionButton: PermissionGate(
        permission: 'quick_news.create',
        child: PearlFab(
          onPressed: () => context.push('/home/quick-news/new'),
          icon: AppIcons.add,
          label: 'Novo Aviso',
        ),
      ),
      body: newsAsync.when(
        data: (newsList) {
          if (newsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.newReleases, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum aviso cadastrado',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para criar o primeiro aviso',
                    style: CommunityDesign.contentStyle(
                      context,
                    ).copyWith(color: Colors.grey[500]),
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
              const Icon(AppIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar avisos',
                style: CommunityDesign.titleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: CommunityDesign.metaStyle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(allQuickNewsProvider),
                icon: const Icon(AppIcons.refresh),
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
    final canEdit = ref
        .watch(currentUserHasPermissionProvider('quick_news.edit'))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final canDelete = ref
        .watch(currentUserHasPermissionProvider('quick_news.delete'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: canEdit
            ? () => context.push('/home/quick-news/${news.id}/edit')
            : null,
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
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
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
              style: CommunityDesign.contentStyle(context),
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
                    Icon(AppIcons.flag, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Prioridade: ${news.priority}',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),

                // Data de criação
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.calendar, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(news.createdAt),
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),

                // Data de expiração (se houver)
                if (news.expiresAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.eventBusy,
                        size: 16,
                        color: news.isExpired ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Expira: ${dateFormat.format(news.expiresAt!)}',
                        style: CommunityDesign.metaStyle(context).copyWith(
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
                if (canEdit) ...[
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/home/quick-news/${news.id}/edit'),
                    icon: const Icon(AppIcons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                ],

                // Botão Deletar
                if (canDelete)
                  TextButton.icon(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: const Icon(AppIcons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
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
              final hasPermission = await ref.read(
                currentUserHasPermissionProvider('quick_news.delete').future,
              );
              if (!hasPermission) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Você não tem permissão para esta ação'),
                    ),
                  );
                }
                return;
              }
              try {
                final repo = ref.read(quickNewsRepositoryProvider);
                await repo.deleteNews(news.id);
                ref.invalidate(allQuickNewsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aviso excluído com sucesso!'),
                    ),
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
    if (!news.isActive) {
      return const StatusBadge(
        label: 'Inativo',
        tone: AppStatusTone.dropped,
        icon: AppIcons.visibilityOff,
      );
    }
    if (news.isExpired) {
      return const StatusBadge(
        label: 'Expirado',
        tone: AppStatusTone.dropped,
        icon: AppIcons.eventBusy,
      );
    }
    return const StatusBadge(
      label: 'Ativo',
      tone: AppStatusTone.active,
      icon: AppIcons.visibility,
    );
  }
}
