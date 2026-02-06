import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';
import '../../../access_levels/domain/models/access_level.dart';
import '../../../permissions/providers/permissions_providers.dart' hide supabaseClientProvider;
import '../../../permissions/domain/models/user_effective_permission.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../data/support_agents_data.dart';
import '../../domain/models/support_agent.dart';
import '../../../../core/constants/supabase_constants.dart';

final agentRuntimeConfigsProvider = FutureProvider<List<AgentRuntimeConfig>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <AgentRuntimeConfig>[];
  try {
    try {
      await ref.watch(currentMemberProvider.future);
    } catch (_) {}
    final supabase = ref.watch(supabaseClientProvider);
    SupabaseConstants.applyTenantHeadersToClient(supabase);
    final selectFields =
        'tenant_id, key, assistant_id, display_name, subtitle, avatar_url, theme_color, show_on_home, show_on_dashboard, show_floating_button, floating_route, allowed_access_levels';
    final tenantId = SupabaseConstants.currentTenantId.trim();
    final rows = await supabase
        .from('agent_config')
        .select(selectFields)
        .or('tenant_id.eq.$tenantId,tenant_id.is.null')
        .order('key');

    final byKey = <String, Map<String, dynamic>>{};
    for (final r in (rows as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(r);
      final key = (map['key']?.toString() ?? '').trim();
      if (key.isEmpty) continue;
      final rowTenant = (map['tenant_id']?.toString() ?? '').trim();
      if (rowTenant.isEmpty) byKey.putIfAbsent(key.toLowerCase(), () => map);
    }
    for (final r in (rows as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(r);
      final key = (map['key']?.toString() ?? '').trim();
      if (key.isEmpty) continue;
      final rowTenant = (map['tenant_id']?.toString() ?? '').trim();
      if (rowTenant == tenantId) byKey[key.toLowerCase()] = map;
    }

    final merged = byKey.values.toList()
      ..sort((a, b) => (a['key']?.toString() ?? '').compareTo((b['key']?.toString() ?? '')));

    return merged
        .map((e) {
          try {
            return AgentRuntimeConfig.fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<AgentRuntimeConfig>()
        .where((c) => c.agentKey.isNotEmpty)
        .toList();
  } catch (_) {
    return <AgentRuntimeConfig>[];
  }
});

final resolvedAgentsProvider = FutureProvider<List<ResolvedAgent>>((ref) async {
  final runtimeList = await ref.watch(agentRuntimeConfigsProvider.future);
  final runtimeByKey = <String, AgentRuntimeConfig>{
    for (final cfg in runtimeList) cfg.agentKey.toLowerCase(): cfg,
  };

  final resolved = <ResolvedAgent>[];

  for (final base in kSupportAgents.values) {
    final cfg = runtimeByKey[base.key.toLowerCase()];
    resolved.add(resolveAgent(base, cfg));
  }

  for (final cfg in runtimeList) {
    if (kSupportAgents.containsKey(cfg.agentKey.toLowerCase())) continue;
    final base = SupportAgent(
      key: cfg.agentKey,
      name: cfg.displayName ?? cfg.agentKey,
      role: cfg.subtitle ?? 'Agente',
      iconName: 'chat',
      defaultThemeColorHex: cfg.themeColorHex,
    );
    resolved.add(resolveAgent(base, cfg));
  }

  resolved.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return resolved;
});

final visibleAgentsForCurrentUserProvider = FutureProvider<List<ResolvedAgent>>((ref) async {
  final allAgents = await ref.watch(resolvedAgentsProvider.future);
  UserAccessLevel? userAccessLevel;
  try {
    userAccessLevel = await ref.watch(currentUserAccessLevelProvider.future);
  } catch (_) {
    userAccessLevel = null;
  }
  final levelName = userAccessLevel?.accessLevel.name ?? 'member';

  List<UserEffectivePermission> effective;
  try {
    effective = await ref.watch(currentUserPermissionsProvider.future);
  } catch (_) {
    effective = const <UserEffectivePermission>[];
  }

  // Mapa de overrides: agents.access.{key} -> isGranted
  final permissionOverrides = <String, bool>{};
  
  // 1. Processar Roles (base)
  for (final p in effective.where((e) => e.source == 'role')) {
    final code = p.permissionCode.trim().toLowerCase();
    if (code.startsWith('agents.access.')) {
      permissionOverrides[code] = p.isGranted;
    }
  }

  // 2. Processar Custom (override) - Sobrescreve roles
  for (final p in effective.where((e) => e.source == 'custom')) {
    final code = p.permissionCode.trim().toLowerCase();
    if (code.startsWith('agents.access.')) {
      permissionOverrides[code] = p.isGranted;
    }
  }

  return filterAgentsForUser(allAgents, levelName, permissionOverrides);
});
