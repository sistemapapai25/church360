import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/permission.dart';
import '../domain/models/user_effective_permission.dart';

/// Repository: Permissions
/// Gerencia operações de permissões
class PermissionsRepository {
  final SupabaseClient _supabase;

  PermissionsRepository(this._supabase);

  // =====================================================
  // CATÁLOGO DE PERMISSÕES
  // =====================================================

  /// Buscar todas as permissões
  Future<List<Permission>> getPermissions() async {
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
    await _supabase
        .from('role_permissions')
        .upsert({
          'role_id': roleId,
          'permission_id': permissionId,
          'is_granted': isGranted,
          'created_by': _supabase.auth.currentUser?.id,
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
      final inserts = permissionIds.map((permId) => {
        'role_id': roleId,
        'permission_id': permId,
        'is_granted': true,
        'created_by': _supabase.auth.currentUser?.id,
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
    final response = await _supabase.rpc(
      'can_access_dashboard',
      params: {'p_user_id': userId},
    );

    return response as bool;
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
    await _supabase
        .from('user_custom_permissions')
        .upsert({
          'user_id': userId,
          'permission_id': permissionId,
          'is_granted': isGranted,
          'expires_at': expiresAt?.toIso8601String(),
          'reason': reason,
          'granted_by': _supabase.auth.currentUser?.id,
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
