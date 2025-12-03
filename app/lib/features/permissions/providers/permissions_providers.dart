import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/roles_repository.dart';
import '../data/permissions_repository.dart';
import '../data/user_roles_repository.dart';
import '../data/role_contexts_repository.dart';
import '../domain/models/role.dart';
import '../domain/models/role_context.dart';
import '../domain/models/permission.dart';
import '../domain/models/user_role.dart';
import '../domain/models/user_effective_permission.dart';

// =====================================================
// PROVIDERS DE REPOSITÓRIOS
// =====================================================

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final rolesRepositoryProvider = Provider<RolesRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return RolesRepository(supabase);
});

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PermissionsRepository(supabase);
});

final userRolesRepositoryProvider = Provider<UserRolesRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return UserRolesRepository(supabase);
});

final roleContextsRepositoryProvider = Provider<RoleContextsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return RoleContextsRepository(supabase);
});

// =====================================================
// PROVIDERS DE DADOS - CARGOS
// =====================================================

/// Provider: Lista de todos os cargos
final rolesProvider = FutureProvider<List<Role>>((ref) async {
  final repository = ref.watch(rolesRepositoryProvider);
  return repository.getRoles();
});

/// Alias para compatibilidade
final allRolesProvider = rolesProvider;

/// Provider: Cargo por ID
final roleByIdProvider = FutureProvider.family<Role?, String>((ref, id) async {
  final repository = ref.watch(rolesRepositoryProvider);
  return repository.getRoleById(id);
});

/// Provider: Hierarquia de cargos
final roleHierarchyProvider = FutureProvider<List<Role>>((ref) async {
  final repository = ref.watch(rolesRepositoryProvider);
  return repository.getRoleHierarchy();
});

/// Provider: Todos os contextos
final allRoleContextsProvider = FutureProvider<List<RoleContext>>((ref) async {
  final repository = ref.watch(roleContextsRepositoryProvider);
  return repository.getAllContexts();
});

/// Alias para compatibilidade
final roleContextsProvider = allRoleContextsProvider;

/// Provider: Contextos de um cargo específico
final contextsByRoleProvider = FutureProvider.family<List<RoleContext>, String>((ref, roleId) async {
  final repository = ref.watch(roleContextsRepositoryProvider);
  return repository.getContextsByRole(roleId);
});

// =====================================================
// PROVIDERS DE DADOS - PERMISSÕES
// =====================================================

/// Provider: Lista de todas as permissões
final permissionsProvider = FutureProvider<List<Permission>>((ref) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getPermissions();
});

/// Alias para compatibilidade
final allPermissionsProvider = permissionsProvider;

/// Provider: Permissões por categoria
final permissionsByCategoryProvider = FutureProvider.family<List<Permission>, String>((ref, category) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getPermissionsByCategory(category);
});

/// Provider: Categorias de permissões
final permissionCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getCategories();
});

/// Provider: Permissões de um cargo
final rolePermissionsProvider = FutureProvider.family<List<Permission>, String>((ref, roleId) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getRolePermissions(roleId);
});

// =====================================================
// PROVIDERS DE DADOS - ATRIBUIÇÕES
// =====================================================

/// Provider: Todas as atribuições de cargos
final allUserRolesProvider = FutureProvider<List<UserRole>>((ref) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getAllUserRoles();
});

/// Alias para compatibilidade
final userRolesProvider = allUserRolesProvider;

/// Provider: Cargos de um usuário específico
final userRolesByUserProvider = FutureProvider.family<List<UserRole>, String>((ref, userId) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getUserRoles(userId);
});

/// Provider: Usuários com um cargo específico
final usersByRoleProvider = FutureProvider.family<List<UserRole>, String>((ref, roleId) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getUsersByRole(roleId);
});

/// Provider: Contextos de um usuário
final userRoleContextsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getUserRoleContexts(userId: userId);
});

// =====================================================
// PROVIDERS DE PERMISSÕES EFETIVAS
// =====================================================

/// Provider: Permissões efetivas de um usuário
final userEffectivePermissionsProvider = FutureProvider.family<List<UserEffectivePermission>, String>((ref, userId) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getUserEffectivePermissions(userId);
});

/// Provider: Verificar permissão específica
final checkUserPermissionProvider = FutureProvider.family<bool, ({String userId, String permissionCode})>((ref, params) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.checkUserPermission(
    userId: params.userId,
    permissionCode: params.permissionCode,
  );
});

/// Provider: Verificar acesso ao Dashboard
final canAccessDashboardProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.canAccessDashboard(userId);
});

// =====================================================
// PROVIDERS DE ESTADO - USUÁRIO ATUAL
// =====================================================

/// Provider: ID do usuário atual
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});

/// Provider: Cargos do usuário atual
final currentUserRolesProvider = FutureProvider<List<UserRole>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getUserRoles(userId);
});

/// Provider: Permissões efetivas do usuário atual
final currentUserPermissionsProvider = FutureProvider<List<UserEffectivePermission>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.getUserEffectivePermissions(userId);
});

/// Provider: Verificar se usuário atual pode acessar Dashboard
final currentUserCanAccessDashboardProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  debugPrint('🔍 [currentUserCanAccessDashboardProvider] userId: $userId');

  if (userId == null) {
    debugPrint('❌ [currentUserCanAccessDashboardProvider] userId é null - retornando false');
    return false;
  }

  final repository = ref.watch(permissionsRepositoryProvider);
  final canAccess = await repository.canAccessDashboard(userId);
  debugPrint('📦 [currentUserCanAccessDashboardProvider] canAccess: $canAccess');

  if (canAccess) return true;

  // Fallback: se a sessão estiver com um user_id antigo (após realinhamento),
  // tenta resolver pelo e-mail atual e usar o id de user_account.
  final supabase = ref.watch(supabaseClientProvider);
  final currentEmail = supabase.auth.currentUser?.email;
  if (currentEmail != null && currentEmail.isNotEmpty) {
    try {
      final mapped = await supabase
          .from('user_account')
          .select('id')
          .eq('email', currentEmail)
          .maybeSingle();

      final mappedId = mapped != null ? mapped['id'] as String : null;
      debugPrint('🔁 [currentUserCanAccessDashboardProvider] mappedId via email: $mappedId');
      if (mappedId != null && mappedId != userId) {
        final canAccessMapped = await repository.canAccessDashboard(mappedId);
        debugPrint('📦 [currentUserCanAccessDashboardProvider] canAccess(mappedId): $canAccessMapped');
        return canAccessMapped;
      }
    } catch (e) {
      debugPrint('❌ [currentUserCanAccessDashboardProvider] fallback erro: $e');
    }
  }

  return false;
});

/// Provider: Verificar se usuário atual tem permissão específica
final currentUserHasPermissionProvider = FutureProvider.family<bool, String>((ref, permissionCode) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  
  final repository = ref.watch(permissionsRepositoryProvider);
  return repository.checkUserPermission(
    userId: userId,
    permissionCode: permissionCode,
  );
});

// =====================================================
// PROVIDERS DE AUDITORIA
// =====================================================

/// Provider: Log de auditoria
final permissionAuditLogProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String? userId, int limit})>((ref, params) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getPermissionAuditLog(
    userId: params.userId,
    limit: params.limit,
  );
});

/// Provider: Log de auditoria (sem parâmetros - últimos 100)
final auditLogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(userRolesRepositoryProvider);
  return repository.getPermissionAuditLog(limit: 100);
});
