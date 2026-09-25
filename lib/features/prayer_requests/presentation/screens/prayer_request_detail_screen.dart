import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';

import '../providers/prayer_request_provider.dart';
import '../../domain/models/prayer_request.dart';

/// Tela de detalhes do pedido de oração
class PrayerRequestDetailScreen extends ConsumerStatefulWidget {
  final String prayerRequestId;

  const PrayerRequestDetailScreen({super.key, required this.prayerRequestId});

  @override
  ConsumerState<PrayerRequestDetailScreen> createState() =>
      _PrayerRequestDetailScreenState();
}

class _PrayerRequestDetailScreenState
    extends ConsumerState<PrayerRequestDetailScreen> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _markAsPrayed() async {
    try {
      final actions = ref.read(prayerRequestActionsProvider);

      await actions.markAsPrayed(
        prayerRequestId: widget.prayerRequestId,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      if (mounted) {
        _noteController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obrigado por orar! 🙏'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePrayerRequest() async {
    final currentMemberId = ref.read(currentMemberProvider).value?.id;
    final prayerRequest = ref
        .read(prayerRequestByIdProvider(widget.prayerRequestId))
        .value;
    final isAuthor = prayerRequest?.authorId == currentMemberId;
    final canDelete = await ref.read(
      currentUserHasPermissionProvider('prayer_requests.delete').future,
    );
    final canModerate = await ref.read(
      currentUserHasPermissionProvider('prayer_requests.moderate').future,
    );
    if (!isAuthor && !canDelete && !canModerate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para esta ação'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Pedido'),
        content: const Text(
          'Tem certeza que deseja deletar este pedido de oração?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final actions = ref.read(prayerRequestActionsProvider);
      await actions.deletePrayerRequest(widget.prayerRequestId);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayerRequestAsync = ref.watch(
      prayerRequestByIdProvider(widget.prayerRequestId),
    );
    final statsAsync = ref.watch(
      prayerRequestStatsProvider(widget.prayerRequestId),
    );
    final hasUserPrayedAsync = ref.watch(
      hasUserPrayedProvider(widget.prayerRequestId),
    );
    final currentMemberId = ref.watch(currentMemberProvider).value?.id;
    final canEditPermission = ref
        .watch(currentUserHasPermissionProvider('prayer_requests.edit'))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final canDeletePermission = ref
        .watch(currentUserHasPermissionProvider('prayer_requests.delete'))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final canModerate = ref
        .watch(currentUserHasPermissionProvider('prayer_requests.moderate'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Pedido de Oração',
          style: CommunityDesign.titleStyle(context),
        ),
        actions: [
          prayerRequestAsync.when(
            data: (prayerRequest) {
              if (prayerRequest == null) return const SizedBox.shrink();

              // Autor sempre pode agir sobre o próprio pedido; além disso,
              // quem tem a permissão de edição/exclusão/moderação também
              // pode agir sobre pedidos de qualquer pessoa.
              final isAuthor = prayerRequest.authorId == currentMemberId;
              final canEdit = isAuthor || canEditPermission || canModerate;
              final canDelete = isAuthor || canDeletePermission || canModerate;
              if (!canEdit && !canDelete) {
                return const SizedBox.shrink();
              }

              return PopupMenuButton(
                itemBuilder: (context) => [
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(AppIcons.edit),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                  if (canEdit && prayerRequest.status != PrayerStatus.answered)
                    const PopupMenuItem(
                      value: 'mark_answered',
                      child: Row(
                        children: [
                          Icon(AppIcons.checkCircle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Marcar como Respondido'),
                        ],
                      ),
                    ),
                  if (canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(AppIcons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Deletar'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    if (!canEdit) return;
                    context.push(
                      '/prayer-requests/${widget.prayerRequestId}/edit',
                    );
                  } else if (value == 'mark_answered') {
                    if (!canEdit) return;
                    final actions = ref.read(prayerRequestActionsProvider);
                    await actions.markAsAnswered(widget.prayerRequestId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Glória a Deus! Oração respondida! 🙏'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (value == 'delete') {
                    if (!canDelete) return;
                    _deletePrayerRequest();
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: prayerRequestAsync.when(
        data: (prayerRequest) {
          if (prayerRequest == null) {
            return const Center(child: Text('Pedido não encontrado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header com categoria, status e privacidade
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CommunityDesign.badge(
                            context,
                            prayerRequest.category.displayName,
                            Theme.of(context).colorScheme.primary,
                            icon: AppIcons.category,
                          ),
                          StatusBadge(
                            label: prayerRequest.status.displayName,
                            tone: _getStatusTone(prayerRequest.status),
                            icon: _getStatusIcon(prayerRequest.status),
                          ),
                          CommunityDesign.badge(
                            context,
                            prayerRequest.privacy.displayName,
                            Theme.of(context).colorScheme.outline,
                            icon: _getPrivacyIcon(prayerRequest.privacy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        prayerRequest.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prayerRequest.timeAgo,
                        style: CommunityDesign.metaStyle(context),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        prayerRequest.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Estatísticas
                statsAsync.when(
                  data: (stats) => GlassCard(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: AppIcons.favorite,
                              label: 'Orações',
                              value: stats.totalPrayers.toString(),
                              color: Colors.red,
                            ),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: AppIcons.groups,
                              label: 'Pessoas',
                              value: stats.uniquePrayers.toString(),
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Campo para adicionar nota ao orar
                GlassCard(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deixe uma mensagem de apoio (opcional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Estou orando por você!',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Erro ao carregar pedido: $error')),
      ),
      bottomNavigationBar: hasUserPrayedAsync.when(
        data: (hasUserPrayed) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _markAsPrayed,
              icon: const Icon(AppIcons.favorite),
              label: Text(hasUserPrayed ? 'Orar Novamente' : 'Eu Orei'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
              ),
            ),
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  AppStatusTone _getStatusTone(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
      case PrayerStatus.praying:
        return AppStatusTone.active;
      case PrayerStatus.answered:
        return AppStatusTone.done;
      case PrayerStatus.cancelled:
        return AppStatusTone.dropped;
    }
  }

  IconData _getStatusIcon(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
        return AppIcons.pending;
      case PrayerStatus.praying:
        return AppIcons.favorite;
      case PrayerStatus.answered:
        return AppIcons.checkCircle;
      case PrayerStatus.cancelled:
        return AppIcons.cancel;
    }
  }

  IconData _getPrivacyIcon(PrayerPrivacy privacy) {
    switch (privacy) {
      case PrayerPrivacy.public:
        return AppIcons.public;
      case PrayerPrivacy.membersOnly:
        return AppIcons.groups;
      case PrayerPrivacy.leadersOnly:
        return AppIcons.admin;
      case PrayerPrivacy.private:
        return AppIcons.lock;
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
