import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/testimony_provider.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/models/testimony.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de listagem e gerenciamento de testemunhos (ADMIN)
class TestimoniesListScreen extends ConsumerWidget {
  const TestimoniesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testimoniesAsync = ref.watch(allTestimoniesProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        title: Text('Testemunhos', style: CommunityDesign.titleStyle(context)),
        centerTitle: true,
      ),
      floatingActionButton: PermissionGate(
        permission: 'testimonies.create',
        child: PearlFab(
          onPressed: () => context.push('/home/testimonies/new'),
          icon: AppIcons.add,
          label: 'Novo Testemunho',
        ),
      ),
      body: testimoniesAsync.when(
        data: (testimonies) {
          if (testimonies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.microphone, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum testemunho cadastrado',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para criar o primeiro testemunho',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTestimoniesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: testimonies.length,
              itemBuilder: (context, index) {
                final testimony = testimonies[index];
                return _TestimonyCard(testimony: testimony);
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
                'Erro ao carregar testemunhos',
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
                onPressed: () => ref.invalidate(allTestimoniesProvider),
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
// WIDGET: Card de Testemunho
// =====================================================

class _TestimonyCard extends ConsumerWidget {
  final Testimony testimony;

  const _TestimonyCard({required this.testimony});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final hasEditPermission = ref
        .watch(currentUserHasPermissionProvider('testimonies.edit'))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final hasDeletePermission = ref
        .watch(currentUserHasPermissionProvider('testimonies.delete'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: hasEditPermission
            ? () => context.push('/home/testimonies/${testimony.id}/edit')
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
                    testimony.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge de visibilidade
                _VisibilityBadge(isPublic: testimony.isPublic),
              ],
            ),
            const SizedBox(height: 8),

            // Descrição
            Text(
              testimony.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Informações adicionais
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                // Data de criação
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.calendar, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(testimony.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),

                // Contato WhatsApp
                if (testimony.allowWhatsappContact)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.phoneInTalk,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Permite contato',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
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
                if (hasEditPermission) ...[
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/home/testimonies/${testimony.id}/edit'),
                    icon: const Icon(AppIcons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                ],

                // Botão Deletar
                if (hasDeletePermission)
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
        title: const Text('Excluir Testemunho'),
        content: Text(
          'Deseja realmente excluir o testemunho "${testimony.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final hasPermission = await ref.read(
                currentUserHasPermissionProvider('testimonies.delete').future,
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
                final repo = ref.read(testimonyRepositoryProvider);
                await repo.deleteTestimony(testimony.id);
                ref.invalidate(allTestimoniesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Testemunho excluído com sucesso!'),
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
// WIDGET: Badge de Visibilidade
// =====================================================

class _VisibilityBadge extends StatelessWidget {
  final bool isPublic;

  const _VisibilityBadge({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: isPublic ? 'Público' : 'Privado',
      tone: isPublic ? AppStatusTone.active : AppStatusTone.dropped,
      icon: isPublic ? AppIcons.public : AppIcons.lock,
    );
  }
}
