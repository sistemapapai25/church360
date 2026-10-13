import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/route_guard.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../providers/groups_provider.dart';

/// [PermissionGate] de um grupo: abre com a [permission] OU para o líder do
/// grupo com groups.manage_own ([canManageGroupProvider]).
class GroupPermissionGate extends ConsumerWidget {
  final String groupId;
  final String permission;
  final Widget child;
  final Widget? fallback;

  const GroupPermissionGate({
    super.key,
    required this.groupId,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ViewOnlyScope.isActive(context)) {
      return fallback ?? const SizedBox.shrink();
    }
    final allowed = ref
        .watch(
          canManageGroupProvider((groupId: groupId, permission: permission)),
        )
        .valueOrNull;
    return allowed == true ? child : (fallback ?? const SizedBox.shrink());
  }
}

/// [PermissionOnlyRoute] de um grupo, com a mesma régua do [GroupPermissionGate].
class GroupPermissionRoute extends ConsumerWidget {
  final String groupId;
  final String permission;
  final Widget child;

  const GroupPermissionRoute({
    super.key,
    required this.groupId,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(
          canManageGroupProvider((groupId: groupId, permission: permission)),
        )
        .when(
          data: (allowed) => allowed
              ? child
              : PermissionDeniedScreen(requiredPermission: permission),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) =>
              PermissionDeniedScreen(requiredPermission: permission),
        );
  }
}
