import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/banners_provider.dart';
import '../../domain/models/banner.dart';

/// Tela de listagem de banners da Home
class BannersListScreen extends ConsumerStatefulWidget {
  const BannersListScreen({super.key});

  @override
  ConsumerState<BannersListScreen> createState() => _BannersListScreenState();
}

class _BannersListScreenState extends ConsumerState<BannersListScreen> {
  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(allBannersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banners da Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/home/banners/new');
            },
            tooltip: 'Adicionar Banner',
          ),
        ],
      ),
      body: bannersAsync.when(
        data: (banners) {
          if (banners.isEmpty) {
            return _buildEmptyState();
          }
          return _buildBannersList(banners);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar banners: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(allBannersProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum banner cadastrado',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione banners para exibir na tela inicial do app',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/home/banners/new');
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Primeiro Banner'),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersList(List<HomeBanner> banners) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: banners.length,
      onReorder: (oldIndex, newIndex) {
        _onReorder(banners, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final banner = banners[index];
        return _BannerCard(
          key: ValueKey(banner.id),
          banner: banner,
          onToggleActive: () => _toggleBannerActive(banner),
          onEdit: () => context.push('/home/banners/${banner.id}/edit'),
          onDelete: () => _deleteBanner(banner),
        );
      },
    );
  }

  Future<void> _onReorder(List<HomeBanner> banners, int oldIndex, int newIndex) async {
    // Ajustar índice se necessário
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Reordenar localmente
    final item = banners.removeAt(oldIndex);
    banners.insert(newIndex, item);

    // Atualizar no banco
    final repo = ref.read(bannersRepositoryProvider);
    final bannerIds = banners.map((b) => b.id).toList();
    
    try {
      await repo.updateBannersOrder(bannerIds);
      // Atualizar a lista
      ref.invalidate(allBannersProvider);
      ref.invalidate(activeBannersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordem atualizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar ordem: $e')),
        );
      }
    }
  }

  Future<void> _toggleBannerActive(HomeBanner banner) async {
    final repo = ref.read(bannersRepositoryProvider);
    
    try {
      await repo.toggleBannerActive(banner.id, !banner.isActive);
      ref.invalidate(allBannersProvider);
      ref.invalidate(activeBannersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              banner.isActive
                  ? 'Banner desativado com sucesso!'
                  : 'Banner ativado com sucesso!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar banner: $e')),
        );
      }
    }
  }

  Future<void> _deleteBanner(HomeBanner banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o banner "${banner.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(bannersRepositoryProvider);
    
    try {
      await repo.deleteBanner(banner.id);
      ref.invalidate(allBannersProvider);
      ref.invalidate(activeBannersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner excluído com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir banner: $e')),
        );
      }
    }
  }
}

/// Card de banner individual
class _BannerCard extends StatelessWidget {
  final HomeBanner banner;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerCard({
    super.key,
    required this.banner,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _getLinkTypeIcon(String linkType) {
    switch (linkType) {
      case 'event':
        return Icons.event;
      case 'reading_plan':
        return Icons.book;
      case 'course':
        return Icons.school;
      case 'message':
        return Icons.mic;
      case 'external':
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de arrastar
            Icon(
              Icons.drag_handle,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            // Miniatura da imagem
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                banner.imageUrl,
                width: 60,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 40,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image, size: 20),
                  );
                },
              ),
            ),
          ],
        ),
        title: Text(banner.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner.description != null)
              Text(
                banner.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getLinkTypeIcon(banner.linkType),
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  banner.linkTypeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge de status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: banner.isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                banner.isActive ? 'Ativo' : 'Inativo',
                style: TextStyle(
                  fontSize: 12,
                  color: banner.isActive ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Menu de ações
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'toggle':
                    onToggleActive();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        banner.isActive ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(banner.isActive ? 'Desativar' : 'Ativar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

