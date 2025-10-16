import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/prayer_request_provider.dart';
import '../../domain/models/prayer_request.dart';

/// Tela de detalhes do pedido de oração
class PrayerRequestDetailScreen extends ConsumerStatefulWidget {
  final String prayerRequestId;

  const PrayerRequestDetailScreen({
    super.key,
    required this.prayerRequestId,
  });

  @override
  ConsumerState<PrayerRequestDetailScreen> createState() => _PrayerRequestDetailScreenState();
}

class _PrayerRequestDetailScreenState extends ConsumerState<PrayerRequestDetailScreen> {
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
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePrayerRequest() async {
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
    final prayerRequestAsync = ref.watch(prayerRequestByIdProvider(widget.prayerRequestId));
    final statsAsync = ref.watch(prayerRequestStatsProvider(widget.prayerRequestId));
    final hasUserPrayedAsync = ref.watch(hasUserPrayedProvider(widget.prayerRequestId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido de Oração'),
        actions: [
          prayerRequestAsync.when(
            data: (prayerRequest) {
              if (prayerRequest == null) return const SizedBox.shrink();
              
              // Apenas o autor pode editar/deletar
              if (prayerRequest.authorId != currentUserId) {
                return const SizedBox.shrink();
              }

              return PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  if (prayerRequest.status != PrayerStatus.answered)
                    const PopupMenuItem(
                      value: 'mark_answered',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Marcar como Respondido'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Deletar'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push('/prayer-requests/${widget.prayerRequestId}/edit');
                  } else if (value == 'mark_answered') {
                    final actions = ref.read(prayerRequestActionsProvider);
                    await actions.markAsAnswered(widget.prayerRequestId);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Glória a Deus! Oração respondida! 🙏'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else if (value == 'delete') {
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
            return const Center(
              child: Text('Pedido não encontrado'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com categoria, status e privacidade
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      icon: prayerRequest.category.icon,
                      label: prayerRequest.category.displayName,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    _Badge(
                      icon: prayerRequest.status.icon,
                      label: prayerRequest.status.displayName,
                      color: _getStatusColor(prayerRequest.status).withValues(alpha: 0.2),
                      textColor: _getStatusColor(prayerRequest.status),
                    ),
                    _Badge(
                      icon: _getPrivacyIcon(prayerRequest.privacy),
                      label: prayerRequest.privacy.displayName,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  prayerRequest.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Data
                Text(
                  prayerRequest.timeAgo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Descrição
                Text(
                  prayerRequest.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Estatísticas
                statsAsync.when(
                  data: (stats) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: Icons.favorite,
                              label: 'Orações',
                              value: stats.totalPrayers.toString(),
                              color: Colors.red,
                            ),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.people,
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
        error: (error, stack) => Center(
          child: Text('Erro ao carregar pedido: $error'),
        ),
      ),
      bottomNavigationBar: hasUserPrayedAsync.when(
        data: (hasUserPrayed) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _markAsPrayed,
              icon: const Icon(Icons.favorite),
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

  Color _getStatusColor(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
        return Colors.orange;
      case PrayerStatus.praying:
        return Colors.blue;
      case PrayerStatus.answered:
        return Colors.green;
      case PrayerStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getPrivacyIcon(PrayerPrivacy privacy) {
    switch (privacy) {
      case PrayerPrivacy.public:
        return '🌍';
      case PrayerPrivacy.membersOnly:
        return '👥';
      case PrayerPrivacy.leadersOnly:
        return '👑';
      case PrayerPrivacy.private:
        return '🔒';
    }
  }
}

class _Badge extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final Color? textColor;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon is IconData ? '' : icon),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

