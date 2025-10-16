import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';

/// Widget: Badge de notificações não lidas
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        return IconButton(
          icon: Badge(
            label: count > 0 ? Text('$count') : null,
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications),
          ),
          onPressed: () {
            context.push('/notifications');
          },
        );
      },
      loading: () => IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {
          context.push('/notifications');
        },
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {
          context.push('/notifications');
        },
      ),
    );
  }
}

/// Widget: Badge de notificações (versão simples sem navegação)
class NotificationBadgeSimple extends ConsumerWidget {
  final VoidCallback? onTap;

  const NotificationBadgeSimple({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        return InkWell(
          onTap: onTap,
          child: Badge(
            label: count > 0 ? Text('$count') : null,
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications),
          ),
        );
      },
      loading: () => InkWell(
        onTap: onTap,
        child: const Icon(Icons.notifications),
      ),
      error: (_, __) => InkWell(
        onTap: onTap,
        child: const Icon(Icons.notifications),
      ),
    );
  }
}

/// Widget: Indicador de notificação não lida (ponto vermelho)
class UnreadNotificationIndicator extends ConsumerWidget {
  const UnreadNotificationIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            shape: BoxShape.circle,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

