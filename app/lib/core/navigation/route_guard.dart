// =====================================================
// CHURCH 360 - ROUTE GUARD
// =====================================================
// Proteção de rotas baseada em níveis de acesso

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/access_levels/domain/models/access_level.dart';
import '../../features/access_levels/presentation/providers/access_level_provider.dart';

/// Tela de acesso negado
class AccessDeniedScreen extends StatelessWidget {
  final AccessLevelType requiredLevel;

  const AccessDeniedScreen({
    super.key,
    required this.requiredLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Negado'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 100,
                color: Colors.red[300],
              ),
              const SizedBox(height: 24),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Você não tem permissão para acessar esta página.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Nível necessário: ${requiredLevel.displayName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  context.go('/');
                },
                icon: const Icon(Icons.home),
                label: const Text('Voltar ao Início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que protege uma rota baseado no nível de acesso
class RouteGuard extends ConsumerWidget {
  final AccessLevelType requiredLevel;
  final Widget child;

  const RouteGuard({
    super.key,
    required this.requiredLevel,
    required this.child,
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
        return AccessDeniedScreen(requiredLevel: requiredLevel);
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao verificar permissões: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que protege uma rota apenas para admins
class AdminOnlyRoute extends ConsumerWidget {
  final Widget child;

  const AdminOnlyRoute({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (isAdmin) {
          return child;
        }
        return const AccessDeniedScreen(
          requiredLevel: AccessLevelType.admin,
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao verificar permissões: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que protege uma rota apenas para coordenadores ou superior
class CoordinatorOnlyRoute extends ConsumerWidget {
  final Widget child;

  const CoordinatorOnlyRoute({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);

    return isCoordinatorAsync.when(
      data: (isCoordinator) {
        if (isCoordinator) {
          return child;
        }
        return const AccessDeniedScreen(
          requiredLevel: AccessLevelType.coordinator,
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao verificar permissões: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que protege uma rota apenas para líderes ou superior
class LeaderOnlyRoute extends ConsumerWidget {
  final Widget child;

  const LeaderOnlyRoute({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeaderAsync = ref.watch(isLeaderOrAboveProvider);

    return isLeaderAsync.when(
      data: (isLeader) {
        if (isLeader) {
          return child;
        }
        return const AccessDeniedScreen(
          requiredLevel: AccessLevelType.leader,
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao verificar permissões: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que protege uma rota apenas para membros ou superior
class MemberOnlyRoute extends ConsumerWidget {
  final Widget child;

  const MemberOnlyRoute({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMemberAsync = ref.watch(isMemberOrAboveProvider);

    return isMemberAsync.when(
      data: (isMember) {
        if (isMember) {
          return child;
        }
        return const AccessDeniedScreen(
          requiredLevel: AccessLevelType.member,
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao verificar permissões: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

