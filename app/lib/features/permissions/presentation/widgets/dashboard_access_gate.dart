import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/permissions_providers.dart';

/// Widget: DashboardAccessGate
/// Controla o acesso ao Dashboard baseado no nível de acesso do usuário
/// 
/// Usuários com nível 0-1 (Visitante/Frequentador) NÃO podem acessar
/// Usuários com nível 2+ (Membro+) podem acessar
/// 
/// Uso:
/// ```dart
/// DashboardAccessGate(
///   child: DashboardScreen(),
/// )
/// ```
class DashboardAccessGate extends ConsumerWidget {
  /// Widget do Dashboard a ser protegido
  final Widget child;
  
  /// Se true, redireciona para home se não tiver acesso
  /// Se false, exibe a tela de acesso negado
  final bool redirectOnDenied;
  
  /// Rota para redirecionar se não tiver acesso
  final String redirectRoute;
  
  /// Widget customizado para acesso negado
  final Widget? accessDeniedWidget;

  const DashboardAccessGate({
    super.key,
    required this.child,
    this.redirectOnDenied = false,
    this.redirectRoute = '/',
    this.accessDeniedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccessAsync = ref.watch(currentUserCanAccessDashboardProvider);

    return canAccessAsync.when(
      data: (canAccess) {
        if (canAccess) {
          return child;
        } else {
          // Usuário não tem acesso
          if (redirectOnDenied) {
            // Redireciona após o build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go(redirectRoute);
              }
            });
            return const SizedBox.shrink();
          } else {
            // Exibe tela de acesso negado
            return accessDeniedWidget ?? _buildAccessDeniedScreen(context);
          }
        }
      },
      loading: () => _buildLoadingScreen(),
      error: (error, stack) {
        debugPrint('DashboardAccessGate error: $error');
        return _buildErrorScreen(context, error.toString());
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando permissões...'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Negado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Acesso Restrito',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Você não tem permissão para acessar o Dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas membros e líderes podem acessar esta área.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Voltar para Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Erro ao Verificar Permissões',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ocorreu um erro ao verificar suas permissões.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Voltar para Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget: DashboardMenuItem
/// Item de menu que só aparece se o usuário tiver acesso ao Dashboard
/// 
/// Uso:
/// ```dart
/// DashboardMenuItem(
///   icon: Icons.dashboard,
///   title: 'Dashboard',
///   onTap: () => context.push('/dashboard'),
/// )
/// ```
class DashboardMenuItem extends ConsumerWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const DashboardMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccessAsync = ref.watch(currentUserCanAccessDashboardProvider);

    return canAccessAsync.when(
      data: (canAccess) {
        debugPrint('🎯 [DashboardMenuItem] canAccess: $canAccess');
        if (!canAccess) {
          debugPrint('❌ [DashboardMenuItem] Sem acesso - retornando SizedBox.shrink()');
          return const SizedBox.shrink();
        }

        debugPrint('✅ [DashboardMenuItem] Com acesso - mostrando ListTile');
        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: trailing,
          onTap: onTap,
        );
      },
      loading: () {
        debugPrint('⏳ [DashboardMenuItem] Loading...');
        return const SizedBox.shrink();
      },
      error: (error, stack) {
        debugPrint('❌ [DashboardMenuItem] ERRO: $error');
        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget: ConditionalDashboardAccess
/// Builder pattern para acesso condicional ao Dashboard
/// 
/// Uso:
/// ```dart
/// ConditionalDashboardAccess(
///   builder: (context, canAccess) {
///     if (canAccess) {
///       return DashboardButton();
///     } else {
///       return UpgradeButton();
///     }
///   },
/// )
/// ```
class ConditionalDashboardAccess extends ConsumerWidget {
  final Widget Function(BuildContext context, bool canAccess) builder;
  final Widget? loadingWidget;

  const ConditionalDashboardAccess({
    super.key,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccessAsync = ref.watch(currentUserCanAccessDashboardProvider);

    return canAccessAsync.when(
      data: (canAccess) {
        debugPrint('🎯 [ConditionalDashboardAccess] canAccess: $canAccess');
        return builder(context, canAccess);
      },
      loading: () {
        debugPrint('⏳ [ConditionalDashboardAccess] Loading...');
        return loadingWidget ??
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
      },
      error: (error, stack) {
        debugPrint('❌ [ConditionalDashboardAccess] ERRO: $error');
        return builder(context, false);
      },
    );
  }
}
