import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/permissions/presentation/widgets/permission_gate.dart';
import '../../features/permissions/providers/permissions_providers.dart';
import '../domain/models/management_menu.dart';

/// `true`/`false` quando todas as checagens da categoria resolveram; `null`
/// enquanto alguma ainda carrega (aí a categoria não aparece).
bool? managementCategoryVisible(WidgetRef ref, ManagementMenuCategory c) {
  final checks = [
    for (final permission in c.permissions)
      ref.watch(currentUserHasPermissionProvider(permission)),
    if (c.extraVisibilityCheck != null) ref.watch(c.extraVisibilityCheck!),
  ];
  if (checks.any((check) => check.isLoading)) return null;
  return checks.any((check) => check.value == true);
}

/// Mostra [child] só quando o [item] está visível para o usuário: pela
/// permissão RBAC ([PermissionGate]) ou pelo gate próprio do item.
class ManagementItemGate extends ConsumerWidget {
  const ManagementItemGate({super.key, required this.item, required this.child});

  final ManagementMenuItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = item.permission;
    if (permission != null) {
      return PermissionGate(
        permission: permission,
        showLoading: false,
        child: child,
      );
    }
    final visible = ref.watch(item.visibleWhen!);
    return visible.value == true ? child : const SizedBox.shrink();
  }
}

/// B5a: fileira rolável de bolinhas no topo da Dashboard, uma por categoria
/// do Menu de Gestão ([kManagementMenu]). Tocar abre um bottom sheet com os
/// itens da categoria. Bolinha some quando nenhuma permissão da categoria;
/// a fileira some quando nenhuma bolinha.
class ManagementMenuRow extends ConsumerWidget {
  const ManagementMenuRow({super.key, this.onNavigate});

  /// Injetável para teste; padrão `context.push(route)`.
  final void Function(BuildContext context, String route)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = [
      for (final c in kManagementMenu)
        if (managementCategoryVisible(ref, c) == true) c,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final c in visible)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _Bubble(
                category: c,
                onTap: () => _openCategory(context, c),
              ),
            ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, ManagementMenuCategory c) {
    final navigate = onNavigate ?? (ctx, route) => ctx.push(route);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                c.icon,
                color: Theme.of(sheetContext).colorScheme.primary,
              ),
              title: Text(
                c.title,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            for (final item in c.items)
              ManagementItemGate(
                item: item,
                child: ListTile(
                  leading: Icon(item.icon, size: 22),
                  title: Text(item.title),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    navigate(context, item.route);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.category, required this.onTap});

  final ManagementMenuCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(category.icon, color: scheme.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              category.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
