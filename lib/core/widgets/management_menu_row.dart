import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/duplicates/presentation/providers/duplicates_provider.dart';
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

/// G1: quantos cadastros esperam vínculo (bolinha de Pessoas). 0 para quem
/// não pode vincular, sem chamar a RPC. Erro também vira 0: a bolinha não é
/// motivo para quebrar a Dashboard.
final pendingLinkCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final can = await ref.watch(
    currentUserHasPermissionProvider('members.merge_duplicates').future,
  );
  if (!can) return 0;
  try {
    return (await ref.watch(duplicateGroupsProvider.future)).length;
  } catch (_) {
    return 0;
  }
});

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

/// Bolinha vermelha de contagem (estilo Messenger). Some com 0.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}

/// Os itens visíveis de uma categoria, um por linha. Usado pela tela Pessoas
/// e por cada seção do ☰ da igreja. "Vincular pessoas" ganha a bolinha.
class ManagementMenuSection extends ConsumerWidget {
  const ManagementMenuSection({
    super.key,
    required this.category,
    this.showTitle = true,
    this.onNavigate,
  });

  final ManagementMenuCategory category;
  final bool showTitle;

  /// Injetável para teste; padrão `context.push(route)`.
  final void Function(BuildContext context, String route)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (managementCategoryVisible(ref, category) != true) {
      return const SizedBox.shrink();
    }
    final navigate = onNavigate ?? (ctx, route) => ctx.push(route);
    final pending = ref.watch(pendingLinkCountProvider).valueOrNull ?? 0;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              category.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final item in category.items)
          ManagementItemGate(
            item: item,
            child: ListTile(
              leading: CountBadge(
                count: item.route == '/duplicate-accounts' ? pending : 0,
                child: Icon(item.icon, color: theme.colorScheme.primary),
              ),
              title: Text(item.title),
              subtitle: item.route == '/duplicate-accounts' && pending > 0
                  ? Text(
                      pending == 1
                          ? '1 cadastro esperando vínculo'
                          : '$pending cadastros esperando vínculo',
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigate(context, item.route),
            ),
          ),
      ],
    );
  }
}
