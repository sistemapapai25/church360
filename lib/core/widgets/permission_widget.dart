// =====================================================
// CHURCH 360 - WIDGET DE PERMISSÃO
// =====================================================
// Mostra/oculta conteúdo baseado no nível de acesso

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/access_levels/domain/models/access_level.dart';
import '../../features/access_levels/presentation/providers/access_level_provider.dart';

/// Widget que mostra conteúdo apenas se o usuário tiver permissão
class PermissionWidget extends ConsumerWidget {
  final AccessLevelType requiredLevel;
  final Widget child;
  final Widget? fallback;

  const PermissionWidget({
    super.key,
    required this.requiredLevel,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(
      hasPermissionProvider(requiredLevel),
    );

    return hasPermissionAsync.when(
      data: (hasPermission) {
        if (hasPermission) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que mostra conteúdo apenas para admins
class AdminOnlyWidget extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const AdminOnlyWidget({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (isAdmin) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que mostra conteúdo apenas para coordenadores ou superior
class CoordinatorOnlyWidget extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const CoordinatorOnlyWidget({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);

    return isCoordinatorAsync.when(
      data: (isCoordinator) {
        if (isCoordinator) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que mostra conteúdo apenas para líderes ou superior
class LeaderOnlyWidget extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const LeaderOnlyWidget({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeaderAsync = ref.watch(isLeaderOrAboveProvider);

    return isLeaderAsync.when(
      data: (isLeader) {
        if (isLeader) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que mostra conteúdo apenas para membros ou superior
class MemberOnlyWidget extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const MemberOnlyWidget({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMemberAsync = ref.watch(isMemberOrAboveProvider);

    return isMemberAsync.when(
      data: (isMember) {
        if (isMember) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que mostra o nível de acesso atual do usuário
class UserAccessLevelBadge extends ConsumerWidget {
  final bool showLabel;
  final double iconSize;

  const UserAccessLevelBadge({
    super.key,
    this.showLabel = true,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessLevelAsync = ref.watch(currentUserAccessLevelProvider);

    return accessLevelAsync.when(
      data: (accessLevel) {
        if (accessLevel == null) {
          return const SizedBox.shrink();
        }

        final level = accessLevel.accessLevel;
        final color = _getLevelColor(level);

        if (!showLabel) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              level.icon,
              style: TextStyle(fontSize: iconSize),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level.icon,
                style: TextStyle(fontSize: iconSize),
              ),
              const SizedBox(width: 8),
              Text(
                level.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
}

/// Widget que mostra informações detalhadas do nível do usuário
class UserAccessLevelCard extends ConsumerWidget {
  const UserAccessLevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessLevelAsync = ref.watch(currentUserAccessLevelProvider);

    return accessLevelAsync.when(
      data: (accessLevel) {
        if (accessLevel == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Nível de acesso não definido',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final level = accessLevel.accessLevel;
        final color = _getLevelColor(level);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Text(
                        level.icon,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                          ),
                          Text(
                            'Nível ${accessLevel.accessLevelNumber}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  level.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (accessLevel.promotedAt != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Promovido em: ${_formatDate(accessLevel.promotedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro: $error'),
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
