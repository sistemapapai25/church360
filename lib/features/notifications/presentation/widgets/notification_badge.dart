import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';

/// Widget: Badge de notificações não lidas
///
/// O toque é o gesto que o navegador exige para pedir permissão de push:
/// se ainda não foi decidida, pede e registra o aparelho antes de abrir a
/// lista. Se o navegador bloqueia, avisa uma vez por sessão como liberar.
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({super.key});

  static bool _blockedHintShown = false;

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final push = ref.read(pushRegistrationServiceProvider);
    try {
      final status = await push.permissionStatus();
      if (status == AuthorizationStatus.notDetermined ||
          status == AuthorizationStatus.authorized) {
        // Já autorizado: re-sincroniza o token (barato e idempotente).
        final result = await push.registerCurrentDevice();
        if (!result.success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 10), content: Text(result.message)),
          );
        }
      } else if (status == AuthorizationStatus.denied &&
          kIsWeb &&
          !_blockedHintShown &&
          context.mounted) {
        _blockedHintShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(
              'As notificações estão bloqueadas neste navegador. No Chrome: '
              'Configurações > Privacidade e segurança > Configurações do site > '
              'Notificações, e permita este site.',
            ),
          ),
        );
      }
    } catch (e) {
      // Navegador sem suporte a push: segue só com o sino.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 10), content: Text('Push indisponivel: $e')),
        );
      }
    }
    if (context.mounted) context.push('/notifications');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return IconButton(
      icon: Badge(
        label: count > 0 ? Text('$count') : null,
        isLabelVisible: count > 0,
        child: const Icon(Icons.notifications),
      ),
      onPressed: () => _onPressed(context, ref),
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

