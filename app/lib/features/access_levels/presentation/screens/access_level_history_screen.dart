// =====================================================
// CHURCH 360 - TELA DE HISTÓRICO DE NÍVEIS DE ACESSO
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/access_level.dart';
import '../providers/access_level_provider.dart';

class AccessLevelHistoryScreen extends ConsumerWidget {
  final String? userId;

  const AccessLevelHistoryScreen({
    super.key,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = userId != null
        ? ref.watch(userAccessLevelHistoryProvider(userId!))
        : ref.watch(allAccessLevelHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userId != null
              ? 'Histórico do Usuário'
              : 'Histórico de Promoções',
        ),
      ),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nenhum histórico encontrado'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryCard(context, item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar histórico: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, AccessLevelHistory item) {
    final isPromotion = item.isPromotion;
    final isDemotion = item.isDemotion;
    final isInitial = item.fromLevel == null;

    Color cardColor;
    IconData icon;

    if (isInitial) {
      cardColor = Colors.blue.shade50;
      icon = Icons.add_circle;
    } else if (isPromotion) {
      cardColor = Colors.green.shade50;
      icon = Icons.arrow_upward;
    } else if (isDemotion) {
      cardColor = Colors.red.shade50;
      icon = Icons.arrow_downward;
    } else {
      cardColor = Colors.grey.shade50;
      icon = Icons.info;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Icon(icon, color: _getIconColor(isInitial, isPromotion, isDemotion)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.changeDescription,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Detalhes da mudança
            if (!isInitial) ...[
              Row(
                children: [
                  // Nível anterior
                  Expanded(
                    child: _buildLevelBadge(
                      context,
                      item.fromLevel!,
                      'De:',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    isPromotion ? Icons.arrow_forward : Icons.arrow_back,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  // Novo nível
                  Expanded(
                    child: _buildLevelBadge(
                      context,
                      item.toLevel,
                      'Para:',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              _buildLevelBadge(context, item.toLevel, 'Nível inicial:'),
              const SizedBox(height: 12),
            ],

            // Motivo
            if (item.reason != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.reason!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Informações adicionais
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                if (item.promotedBy != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Por: ${item.promotedBy!.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(
    BuildContext context,
    AccessLevelType level,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getLevelColor(level).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getLevelColor(level)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                level.icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  level.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getIconColor(bool isInitial, bool isPromotion, bool isDemotion) {
    if (isInitial) return Colors.blue;
    if (isPromotion) return Colors.green;
    if (isDemotion) return Colors.red;
    return Colors.grey;
  }

  Color _getLevelColor(AccessLevelType level) {
    switch (level) {
      case AccessLevelType.visitor:
        return Colors.grey;
      case AccessLevelType.attendee:
        return Colors.green;
      case AccessLevelType.member:
        return Colors.blue;
      case AccessLevelType.leader:
        return Colors.orange;
      case AccessLevelType.coordinator:
        return Colors.purple;
      case AccessLevelType.admin:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora mesmo';
        }
        return '${difference.inMinutes} min atrás';
      }
      return '${difference.inHours}h atrás';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
