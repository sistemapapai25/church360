import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permissions_providers.dart';

/// Widget: PermissionGate
/// Controla a exibição de widgets baseado em permissões do usuário
/// 
/// Uso:
/// ```dart
/// PermissionGate(
///   permission: 'members.create',
///   child: ElevatedButton(...),
///   fallback: Text('Sem permissão'),
/// )
/// ```
class PermissionGate extends ConsumerWidget {
  /// Código da permissão necessária (ex: 'members.create')
  final String permission;
  
  /// Widget a ser exibido se o usuário tiver a permissão
  final Widget child;
  
  /// Widget a ser exibido se o usuário NÃO tiver a permissão
  /// Se null, não exibe nada
  final Widget? fallback;
  
  /// Se true, exibe um loading enquanto verifica a permissão
  final bool showLoading;
  
  /// Widget de loading customizado
  final Widget? loadingWidget;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.showLoading = true,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(
      currentUserHasPermissionProvider(permission),
    );

    return hasPermissionAsync.when(
      data: (hasPermission) {
        if (hasPermission) {
          return child;
        } else {
          return fallback ?? const SizedBox.shrink();
        }
      },
      loading: () {
        if (!showLoading) {
          return const SizedBox.shrink();
        }
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
        // Em caso de erro, não exibe o widget por segurança
        debugPrint('PermissionGate error: $error');
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget: MultiPermissionGate
/// Controla a exibição baseado em múltiplas permissões
/// 
/// Uso:
/// ```dart
/// MultiPermissionGate(
///   permissions: ['members.create', 'members.edit'],
///   requireAll: false, // OR logic
///   child: ElevatedButton(...),
/// )
/// ```
class MultiPermissionGate extends ConsumerWidget {
  /// Lista de códigos de permissões
  final List<String> permissions;
  
  /// Se true, requer TODAS as permissões (AND logic)
  /// Se false, requer PELO MENOS UMA permissão (OR logic)
  final bool requireAll;
  
  /// Widget a ser exibido se o usuário tiver as permissões
  final Widget child;
  
  /// Widget a ser exibido se o usuário NÃO tiver as permissões
  final Widget? fallback;
  
  /// Se true, exibe um loading enquanto verifica as permissões
  final bool showLoading;

  const MultiPermissionGate({
    super.key,
    required this.permissions,
    required this.child,
    this.requireAll = true,
    this.fallback,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Busca todas as permissões
    final permissionChecks = permissions.map((permission) {
      return ref.watch(currentUserHasPermissionProvider(permission));
    }).toList();

    // Verifica se alguma ainda está carregando
    final isLoading = permissionChecks.any((check) => check.isLoading);
    if (isLoading && showLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Verifica se alguma teve erro
    final hasError = permissionChecks.any((check) => check.hasError);
    if (hasError) {
      debugPrint('MultiPermissionGate error');
      return fallback ?? const SizedBox.shrink();
    }

    // Extrai os valores booleanos
    final hasPermissions = permissionChecks
        .map((check) => check.value ?? false)
        .toList();

    // Aplica a lógica AND ou OR
    final bool shouldShow = requireAll
        ? hasPermissions.every((has) => has) // AND: todas true
        : hasPermissions.any((has) => has);  // OR: pelo menos uma true

    if (shouldShow) {
      return child;
    } else {
      return fallback ?? const SizedBox.shrink();
    }
  }
}

/// Widget: PermissionBuilder
/// Builder pattern para controle de permissões com mais flexibilidade
/// 
/// Uso:
/// ```dart
/// PermissionBuilder(
///   permission: 'members.edit',
///   builder: (context, hasPermission) {
///     return ElevatedButton(
///       onPressed: hasPermission ? () {} : null,
///       child: Text('Editar'),
///     );
///   },
/// )
/// ```
class PermissionBuilder extends ConsumerWidget {
  /// Código da permissão necessária
  final String permission;
  
  /// Builder que recebe o contexto e se tem permissão
  final Widget Function(BuildContext context, bool hasPermission) builder;
  
  /// Widget de loading
  final Widget? loadingWidget;

  const PermissionBuilder({
    super.key,
    required this.permission,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(
      currentUserHasPermissionProvider(permission),
    );

    return hasPermissionAsync.when(
      data: (hasPermission) => builder(context, hasPermission),
      loading: () => loadingWidget ?? 
        const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      error: (error, stack) {
        debugPrint('PermissionBuilder error: $error');
        return builder(context, false);
      },
    );
  }
}

/// Widget: DisabledByPermission
/// Desabilita um widget se o usuário não tiver permissão
/// 
/// Uso:
/// ```dart
/// DisabledByPermission(
///   permission: 'members.delete',
///   child: IconButton(
///     icon: Icon(Icons.delete),
///     onPressed: () {},
///   ),
/// )
/// ```
class DisabledByPermission extends ConsumerWidget {
  /// Código da permissão necessária
  final String permission;
  
  /// Widget filho
  final Widget child;
  
  /// Tooltip quando desabilitado
  final String? disabledTooltip;
  
  /// Opacidade quando desabilitado
  final double disabledOpacity;

  const DisabledByPermission({
    super.key,
    required this.permission,
    required this.child,
    this.disabledTooltip = 'Você não tem permissão para esta ação',
    this.disabledOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(
      currentUserHasPermissionProvider(permission),
    );

    return hasPermissionAsync.when(
      data: (hasPermission) {
        if (hasPermission) {
          return child;
        } else {
          final disabledChild = Opacity(
            opacity: disabledOpacity,
            child: IgnorePointer(child: child),
          );
          
          if (disabledTooltip != null) {
            return Tooltip(
              message: disabledTooltip!,
              child: disabledChild,
            );
          }
          
          return disabledChild;
        }
      },
      loading: () => Opacity(
        opacity: disabledOpacity,
        child: IgnorePointer(child: child),
      ),
      error: (error, stack) {
        debugPrint('DisabledByPermission error: $error');
        return Opacity(
          opacity: disabledOpacity,
          child: IgnorePointer(child: child),
        );
      },
    );
  }
}

