import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../support_chat/data/support_agents_data.dart';
import '../domain/models/permission.dart';
import '../domain/models/user_effective_permission.dart';

/// Repository: Permissions
/// Gerencia operações de permissões
class PermissionsRepository {
  final SupabaseClient _supabase;
  bool _agentPermissionsEnsured = false;
  bool _corePermissionsEnsured = false;

  PermissionsRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  // =====================================================
  // CATÁLOGO DE PERMISSÕES
  // =====================================================

  Future<void> _ensureAgentPermissions() async {
    if (_agentPermissionsEnsured) return;

    try {
      final tenantId = SupabaseConstants.currentTenantId.trim();
      final runtimeConfigs = await _supabase
          .from('agent_config')
          .select('tenant_id, key, display_name')
          .or('tenant_id.eq.$tenantId,tenant_id.is.null')
          .order('key');

      final runtimeNameByKey = <String, String>{};
      final runtimeKeys = <String>{};
      for (final item in (runtimeConfigs as List)) {
        final key = (item['key'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        runtimeKeys.add(key.toLowerCase());
        final name = (item['display_name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          runtimeNameByKey[key.toLowerCase()] = name;
        }
      }

      final expected = <String, String>{};
      for (final base in kSupportAgents.values) {
        expected[base.key.toLowerCase()] = base.name;
      }
      for (final key in runtimeKeys) {
        expected.putIfAbsent(key, () => runtimeNameByKey[key] ?? key);
      }

      if (expected.isEmpty) {
        _agentPermissionsEnsured = true;
        return;
      }

      final rows = <Map<String, dynamic>>[];
      for (final key in expected.keys) {
        final code = 'agents.access.$key';
        final agentName = runtimeNameByKey[key] ?? expected[key] ?? key;
        rows.add({
          'code': code,
          'name': 'Acessar agente: $agentName',
          'description': 'Permite acessar o agente IA "$agentName".',
          'category': 'agents', // Padronizado para lowercase
          'subcategory': 'access',
          'is_active': true,
          'requires_context': false,
        });
      }

      if (rows.isNotEmpty) {
        await _supabase.from('permissions').upsert(
          rows,
          onConflict: 'code',
        );
      }

      _agentPermissionsEnsured = true;
    } catch (_) {
      _agentPermissionsEnsured = true;
    }
  }

  Future<void> _ensureCorePermissions() async {
    if (_corePermissionsEnsured) return;
    try {
      final rows = <Map<String, dynamic>>[
        {
          'code': 'dispatch.configure',
          'name': 'Configurar Disparos',
          'description': 'Acessar e configurar integrações e disparos automáticos.',
          'category': 'dispatch',
          'subcategory': 'configure',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'events.checkin',
          'name': 'Check-in Eventos',
          'description': 'Fazer check-in em eventos via QR Code.',
          'category': 'events',
          'subcategory': 'checkin',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'financial.manage',
          'name': 'Gerenciar Financeiro',
          'description': 'Permite acesso total ao módulo financeiro (lançamentos, categorias, contas, relatórios).',
          'category': 'financial',
          'subcategory': 'manage',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.view',
          'name': 'Ver Relatórios',
          'description': 'Visualizar relatórios.',
          'category': 'reports',
          'subcategory': 'view',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.create',
          'name': 'Criar Relatórios',
          'description': 'Criar relatórios customizados.',
          'category': 'reports',
          'subcategory': 'create',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.edit',
          'name': 'Editar Relatórios',
          'description': 'Editar relatórios customizados.',
          'category': 'reports',
          'subcategory': 'edit',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.delete',
          'name': 'Deletar Relatórios',
          'description': 'Remover relatórios customizados.',
          'category': 'reports',
          'subcategory': 'delete',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.export',
          'name': 'Exportar Relatórios',
          'description': 'Exportar relatórios.',
          'category': 'reports',
          'subcategory': 'export',
          'is_active': true,
          'requires_context': false,
        },
        {
          'code': 'reports.view_analytics',
          'name': 'Ver Analytics',
          'description': 'Acessar dashboard de analytics.',
          'category': 'reports',
          'subcategory': 'view',
          'is_active': true,
          'requires_context': false,
        },
      ];

      await _supabase.from('permissions').upsert(
        rows,
        onConflict: 'code',
      );
    } catch (_) {
    } finally {
      _corePermissionsEnsured = true;
    }
  }

  /// Buscar todas as permissões
  Future<List<Permission>> getPermissions() async {
    await _ensureAgentPermissions();
    await _ensureCorePermissions();
    final response = await _supabase
        .from('permissions')
        .select()
        .eq('is_active', true)
        .order('category')
        .order('name');

    return (response as List)
        .map((json) => Permission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Buscar permissões por categoria
  Future<List<Permission>> getPermissionsByCategory(String category) async {
    await _ensureAgentPermissions();
    await _ensureCorePermissions();
    final response = await _supabase
        .from('permissions')
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => Permission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Buscar permissão por código
  Future<Permission?> getPermissionByCode(String code) async {
    await _ensureCorePermissions();
    final response = await _supabase
        .from('permissions')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (response == null) return null;
    return Permission.fromJson(response);
  }

  /// Buscar categorias únicas
  Future<List<String>> getCategories() async {
    await _ensureCorePermissions();
    final response = await _supabase
        .from('permissions')
        .select('category')
        .eq('is_active', true);

    final categories = (response as List)
        .map((item) => item['category'] as String)
        .toSet()
        .toList();

    categories.sort();
    return categories;
  }

  // =====================================================
  // PERMISSÕES DE CARGOS
  // =====================================================

  /// Buscar permissões de um cargo
  Future<List<Permission>> getRolePermissions(String roleId) async {
    await _ensureCorePermissions();
    final response = await _supabase
        .from('role_permissions')
        .select('permissions(*)')
        .eq('role_id', roleId)
        .eq('is_granted', true);

    return (response as List)
        .map((item) => Permission.fromJson(item['permissions'] as Map<String, dynamic>))
        .toList();
  }

  /// Atribuir permissão a um cargo
  Future<void> assignPermissionToRole({
    required String roleId,
    required String permissionId,
    bool isGranted = true,
  }) async {
    final actorId = await _effectiveUserId();
    await _supabase
        .from('role_permissions')
        .upsert({
          'role_id': roleId,
          'permission_id': permissionId,
          'is_granted': isGranted,
          'created_by': actorId,
        });
  }

  /// Remover permissão de um cargo
  Future<void> removePermissionFromRole({
    required String roleId,
    required String permissionId,
  }) async {
    await _supabase
        .from('role_permissions')
        .delete()
        .eq('role_id', roleId)
        .eq('permission_id', permissionId);
  }

  /// Atualizar todas as permissões de um cargo
  Future<void> updateRolePermissions({
    required String roleId,
    required List<String> permissionIds,
  }) async {
    // Remove todas as permissões atuais
    await _supabase
        .from('role_permissions')
        .delete()
        .eq('role_id', roleId);

    // Adiciona as novas permissões
    if (permissionIds.isNotEmpty) {
      final actorId = await _effectiveUserId();
      final inserts = permissionIds.map((permId) => {
        'role_id': roleId,
        'permission_id': permId,
        'is_granted': true,
        'created_by': actorId,
      }).toList();

      await _supabase.from('role_permissions').insert(inserts);
    }
  }

  /// Alias para compatibilidade
  Future<void> setRolePermissions({
    required String roleId,
    required List<String> permissionIds,
  }) => updateRolePermissions(
    roleId: roleId,
    permissionIds: permissionIds,
  );

  // =====================================================
  // PERMISSÕES EFETIVAS DO USUÁRIO
  // =====================================================

  /// Buscar permissões efetivas de um usuário
  Future<List<UserEffectivePermission>> getUserEffectivePermissions(String userId) async {
    await _ensureCorePermissions();
    final response = await _supabase
        .rpc('get_user_effective_permissions', params: {'p_user_id': userId});

    return (response as List)
        .map((json) => UserEffectivePermission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Verificar se usuário tem permissão específica
  Future<bool> checkUserPermission({
    required String userId,
    required String permissionCode,
  }) async {
    await _ensureCorePermissions();
    final response = await _supabase.rpc(
      'check_user_permission',
      params: {
        'p_user_id': userId,
        'p_permission_code': permissionCode,
      },
    );

    return response as bool;
  }

  /// Verificar se usuário pode acessar Dashboard
  Future<bool> canAccessDashboard(String userId) async {
    try {
      final hasPermission = await checkUserPermission(
        userId: userId,
        permissionCode: 'dashboard.access',
      );
      if (hasPermission) return true;
    } catch (_) {}

    try {
      final response = await _supabase.rpc(
        'can_access_dashboard',
        params: {'p_user_id': userId},
      );

      return response as bool;
    } catch (_) {
      return false;
    }
  }

  // =====================================================
  // PERMISSÕES CUSTOMIZADAS
  // =====================================================

  /// Atribuir permissão customizada a um usuário
  Future<void> assignCustomPermission({
    required String userId,
    required String permissionId,
    bool isGranted = true,
    DateTime? expiresAt,
    String? reason,
  }) async {
    final actorId = await _effectiveUserId();
    await _supabase
        .from('user_custom_permissions')
        .upsert({
          'user_id': userId,
          'permission_id': permissionId,
          'is_granted': isGranted,
          'expires_at': expiresAt?.toIso8601String(),
          'reason': reason,
          'granted_by': actorId,
        });
  }

  /// Remover permissão customizada
  Future<void> removeCustomPermission({
    required String userId,
    required String permissionId,
  }) async {
    await _supabase
        .from('user_custom_permissions')
        .delete()
        .eq('user_id', userId)
        .eq('permission_id', permissionId);
  }
}
