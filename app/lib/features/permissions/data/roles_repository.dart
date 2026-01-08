import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/role.dart';
import '../domain/models/role_context.dart';

/// Repository: Roles
/// Gerencia operações CRUD de cargos
class RolesRepository {
  final SupabaseClient _supabase;

  RolesRepository(this._supabase);

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
  // CRUD DE CARGOS
  // =====================================================

  /// Buscar todos os cargos ativos
  Future<List<Role>> getRoles() async {
    final response = await _supabase
        .from('roles')
        .select()
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => Role.fromJson(json))
        .toList();
  }

  /// Buscar cargo por ID
  Future<Role?> getRoleById(String id) async {
    final response = await _supabase
        .from('roles')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Role.fromJson(response);
  }

  /// Criar novo cargo (com objeto Role)
  Future<Role> createRoleFromObject(Role role) async {
    final actorId = await _effectiveUserId();
    final response = await _supabase
        .from('roles')
        .insert({
          'name': role.name,
          'description': role.description,
          'parent_role_id': role.parentRoleId,
          'hierarchy_level': role.hierarchyLevel,
          'allows_context': role.allowsContext,
          'is_active': role.isActive,
          'created_by': actorId,
        })
        .select()
        .single();

    return Role.fromJson(response);
  }

  /// Criar novo cargo (com parâmetros)
  Future<Role> createRole({
    required String name,
    String? description,
    String? parentRoleId,
    int hierarchyLevel = 0,
    bool allowsContext = false,
  }) async {
    final actorId = await _effectiveUserId();
    final response = await _supabase
        .from('roles')
        .insert({
          'name': name,
          'description': description,
          'parent_role_id': parentRoleId,
          'hierarchy_level': hierarchyLevel,
          'allows_context': allowsContext,
          'is_active': true,
          'created_by': actorId,
        })
        .select()
        .single();

    return Role.fromJson(response);
  }

  /// Atualizar cargo (com objeto Role)
  Future<void> updateRoleFromObject(Role role) async {
    await _supabase
        .from('roles')
        .update({
          'name': role.name,
          'description': role.description,
          'parent_role_id': role.parentRoleId,
          'hierarchy_level': role.hierarchyLevel,
          'allows_context': role.allowsContext,
          'is_active': role.isActive,
        })
        .eq('id', role.id);
  }

  /// Atualizar cargo (com parâmetros)
  Future<void> updateRole({
    required String roleId,
    String? name,
    String? description,
    String? parentRoleId,
    int? hierarchyLevel,
    bool? allowsContext,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (parentRoleId != null) updates['parent_role_id'] = parentRoleId;
    if (hierarchyLevel != null) updates['hierarchy_level'] = hierarchyLevel;
    if (allowsContext != null) updates['allows_context'] = allowsContext;
    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isNotEmpty) {
      await _supabase
          .from('roles')
          .update(updates)
          .eq('id', roleId);
    }
  }

  /// Deletar cargo (soft delete)
  Future<void> deleteRole(String id) async {
    await _supabase
        .from('roles')
        .update({'is_active': false})
        .eq('id', id);
  }

  // =====================================================
  // HIERARQUIA
  // =====================================================

  /// Buscar cargos filhos de um cargo pai
  Future<List<Role>> getChildRoles(String parentId) async {
    final response = await _supabase
        .from('roles')
        .select()
        .eq('parent_role_id', parentId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => Role.fromJson(json))
        .toList();
  }

  /// Buscar hierarquia completa de cargos
  Future<List<Role>> getRoleHierarchy() async {
    final response = await _supabase
        .from('roles')
        .select()
        .eq('is_active', true)
        .order('hierarchy_level')
        .order('name');

    return (response as List)
        .map((json) => Role.fromJson(json))
        .toList();
  }

  // =====================================================
  // CONTEXTOS
  // =====================================================

  /// Buscar contextos de um cargo
  Future<List<RoleContext>> getRoleContexts(String roleId) async {
    final response = await _supabase
        .from('role_contexts')
        .select()
        .eq('role_id', roleId)
        .eq('is_active', true)
        .order('context_name');

    return (response as List)
        .map((json) => RoleContext.fromJson(json))
        .toList();
  }

  /// Criar novo contexto
  Future<RoleContext> createRoleContext(RoleContext context) async {
    final actorId = await _effectiveUserId();
    final response = await _supabase
        .from('role_contexts')
        .insert({
          'role_id': context.roleId,
          'context_name': context.contextName,
          'description': context.description,
          'metadata': context.metadata,
          'is_active': context.isActive,
          'created_by': actorId,
        })
        .select()
        .single();

    return RoleContext.fromJson(response);
  }

  /// Atualizar contexto
  Future<void> updateRoleContext(RoleContext context) async {
    await _supabase
        .from('role_contexts')
        .update({
          'context_name': context.contextName,
          'description': context.description,
          'metadata': context.metadata,
          'is_active': context.isActive,
        })
        .eq('id', context.id);
  }

  /// Deletar contexto (soft delete)
  Future<void> deleteRoleContext(String id) async {
    await _supabase
        .from('role_contexts')
        .update({'is_active': false})
        .eq('id', id);
  }
}
