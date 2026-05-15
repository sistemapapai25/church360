import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/user_role.dart';

/// Lançada quando uma operação que escreve em `user_roles` é solicitada
/// para um membro que não possui conta de acesso (`auth_user_id` nulo).
/// `user_roles.user_id` referencia `auth.users(id)`, então não há como
/// gravar permissões para membros sem login.
class MemberWithoutAccountException implements Exception {
  final String userAccountId;
  const MemberWithoutAccountException(this.userAccountId);

  @override
  String toString() =>
      'MemberWithoutAccountException: user_account $userAccountId não possui auth_user_id';
}

/// Repository: UserRoles
/// Gerencia atribuições de cargos a usuários
class UserRolesRepository {
  final SupabaseClient _supabase;

  UserRolesRepository(this._supabase);

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

  /// Resolve o `auth.users.id` correspondente a um `user_account.id`.
  /// Se o valor recebido já é um `auth.users.id` (nenhum row em
  /// `user_account` com esse id como PK), assume que é o próprio auth id
  /// e retorna ele de volta — isso preserva compatibilidade com chamadas
  /// internas que já passam o auth id.
  /// Retorna null somente se o `user_account` existe mas não tem
  /// `auth_user_id` (membro sem conta de acesso).
  Future<String?> _resolveAuthUserId(String userIdOrAccountId) async {
    try {
      final row = await _supabase
          .from('user_account')
          .select('auth_user_id')
          .eq('id', userIdOrAccountId)
          .maybeSingle();
      if (row == null) {
        // Não achou em user_account.id — assume que já é um auth.users.id.
        return userIdOrAccountId;
      }
      final v = row['auth_user_id'];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    } catch (e) {
      debugPrint('Erro ao resolver auth_user_id de $userIdOrAccountId: $e');
      return userIdOrAccountId;
    }
  }

  // =====================================================
  // ATRIBUIÇÕES DE CARGOS
  // =====================================================

  /// Buscar todas as atribuições de cargos
  Future<List<UserRole>> getAllUserRoles() async {
    final response = await _supabase
        .from('user_roles')
        .select('''
          *,
          role:roles(*),
          role_context:role_contexts(*)
        ''')
        .order('created_at', ascending: false);

    final items = (response as List)
        .map((json) => UserRole.fromJson(json as Map<String, dynamic>))
        .toList();
    return await _withUserData(items);
  }

  /// Buscar cargos de um usuário.
  /// Aceita tanto `user_account.id` (UI) quanto `auth.users.id` (uso interno).
  Future<List<UserRole>> getUserRoles(String userId) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) return [];
    final response = await _supabase
        .from('user_roles')
        .select('''
          *,
          role:roles(*),
          role_context:role_contexts(*)
        ''')
        .eq('user_id', authUserId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
        .order('created_at', ascending: false);

    final items = (response as List)
        .map((json) => UserRole.fromJson(json as Map<String, dynamic>))
        .toList();
    return await _withUserData(items);
  }

  /// Buscar usuários com um cargo específico
  Future<List<UserRole>> getUsersByRole(String roleId) async {
    final response = await _supabase
        .from('user_roles')
        .select('''
          *,
          role:roles(*),
          role_context:role_contexts(*)
        ''')
        .eq('role_id', roleId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
        .order('created_at', ascending: false);

    final items = (response as List)
        .map((json) => UserRole.fromJson(json as Map<String, dynamic>))
        .toList();
    return await _withUserData(items);
  }

  Future<List<UserRole>> _withUserData(List<UserRole> items) async {
    final ids = items.map((e) => e.userId).toSet().toList();
    if (ids.isEmpty) return items;
    var query = _supabase
        .from('user_account')
        .select('id, first_name, last_name, email');

    if (ids.length == 1) {
      query = query.eq('id', ids.first);
    } else {
      final orClause = ids.map((id) => 'id.eq.$id').join(',');
      query = query.or(orClause);
    }

    final ua = await query;
    final map = <String, Map<String, dynamic>>{};
    for (final row in (ua as List)) {
      final m = row as Map<String, dynamic>;
      map[m['id'] as String] = m;
    }
    return items.map((ur) {
      final data = map[ur.userId];
      if (data == null) return ur;
      final first = data['first_name'] as String?;
      final last = data['last_name'] as String?;
      final name = [first, last].where((e) => (e ?? '').isNotEmpty).join(' ').trim();
      final email = data['email'] as String?;
      return ur.copyWith(
        userName: name.isNotEmpty ? name : null,
        userEmail: email,
      );
    }).toList();
  }

  /// Atribuir cargo a usuário.
  /// Aceita `user_account.id` (UI) ou `auth.users.id` (interno) — resolve
  /// internamente para o `auth.users.id` exigido por `user_roles.user_id`.
  /// Lança [MemberWithoutAccountException] se o membro não tiver conta de acesso.
  Future<String> assignRoleToUser({
    required String userId,
    required String roleId,
    String? contextId,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) {
      throw MemberWithoutAccountException(userId);
    }
    final actorId = await _effectiveUserId();
    final response = await _supabase.rpc(
      'assign_role_to_user',
      params: {
        'p_user_id': authUserId,
        'p_role_id': roleId,
        'p_context_id': contextId,
        'p_assigned_by': actorId,
        'p_expires_at': expiresAt?.toIso8601String(),
        'p_notes': notes,
      },
    );

    return response as String;
  }

  /// Alias para compatibilidade
  Future<String> assignRole({
    required String userId,
    required String roleId,
    String? contextId,
    DateTime? expiresAt,
    String? notes,
  }) => assignRoleToUser(
    userId: userId,
    roleId: roleId,
    contextId: contextId,
    expiresAt: expiresAt,
    notes: notes,
  );

  /// Remover cargo de usuário
  Future<bool> removeUserRole(String userRoleId) async {
    final actorId = await _effectiveUserId();
    final response = await _supabase.rpc(
      'remove_user_role',
      params: {
        'p_user_role_id': userRoleId,
        'p_removed_by': actorId,
      },
    );

    return response as bool;
  }

  /// Atualizar cargo de usuário
  Future<void> updateUserRole({
    required String userRoleId,
    String? contextId,
    DateTime? expiresAt,
    String? notes,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    
    if (contextId != null) updates['role_context_id'] = contextId;
    if (expiresAt != null) updates['expires_at'] = expiresAt.toIso8601String();
    if (notes != null) updates['notes'] = notes;
    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isNotEmpty) {
      await _supabase
          .from('user_roles')
          .update(updates)
          .eq('id', userRoleId);
    }
  }

  // =====================================================
  // CONTEXTOS DO USUÁRIO
  // =====================================================

  /// Buscar contextos de um usuário para um cargo específico.
  /// Aceita `user_account.id` (UI) ou `auth.users.id` (interno).
  Future<List<Map<String, dynamic>>> getUserRoleContexts({
    required String userId,
    String? roleId,
  }) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) return [];
    final response = await _supabase.rpc(
      'get_user_role_contexts',
      params: {
        'p_user_id': authUserId,
        'p_role_id': roleId,
      },
    );

    return (response as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  // =====================================================
  // VERIFICAÇÕES
  // =====================================================

  /// Verificar se usuário tem cargo específico
  Future<bool> userHasRole({
    required String userId,
    required String roleId,
  }) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) return false;
    final response = await _supabase
        .from('user_roles')
        .select('id')
        .eq('user_id', authUserId)
        .eq('role_id', roleId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
        .maybeSingle();

    return response != null;
  }

  /// Verificar se usuário tem cargo em contexto específico
  Future<bool> userHasRoleInContext({
    required String userId,
    required String roleId,
    required String contextId,
  }) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) return false;
    final response = await _supabase
        .from('user_roles')
        .select('id')
        .eq('user_id', authUserId)
        .eq('role_id', roleId)
        .eq('role_context_id', contextId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
        .maybeSingle();

    return response != null;
  }

  /// Remover cargo de usuário por contexto (deleção direta)
  Future<void> removeUserRoleByContext({
    required String userId,
    required String contextId,
  }) async {
    final authUserId = await _resolveAuthUserId(userId);
    if (authUserId == null) return;
    await _supabase
        .from('user_roles')
        .delete()
        .eq('user_id', authUserId)
        .eq('role_context_id', contextId);
  }

  // =====================================================
  // AUDITORIA
  // =====================================================

  /// Buscar histórico de mudanças de permissões
  Future<List<Map<String, dynamic>>> getPermissionAuditLog({
    String? userId,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('permission_audit_log')
        .select();

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    final response = await query
        .order('performed_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }
}
