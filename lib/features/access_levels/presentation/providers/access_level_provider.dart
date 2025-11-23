// =====================================================
// CHURCH 360 - ACCESS LEVEL PROVIDERS
// =====================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/access_level_repository.dart';
import '../../domain/models/access_level.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final accessLevelRepositoryProvider = Provider<AccessLevelRepository>((ref) {
  return AccessLevelRepository(Supabase.instance.client);
});

// =====================================================
// CURRENT USER ACCESS LEVEL PROVIDER
// =====================================================

final currentUserAccessLevelProvider =
    FutureProvider<UserAccessLevel?>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getCurrentUserAccessLevel();
});

// =====================================================
// ALL ACCESS LEVELS PROVIDER
// =====================================================

final allAccessLevelsProvider =
    FutureProvider<List<UserAccessLevel>>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getAllAccessLevels();
});

// =====================================================
// USER ACCESS LEVEL PROVIDER (específico)
// =====================================================

final userAccessLevelProvider =
    FutureProvider.family<UserAccessLevel?, String>((ref, userId) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getUserAccessLevel(userId);
});

// =====================================================
// ACCESS LEVEL HISTORY PROVIDER
// =====================================================

final userAccessLevelHistoryProvider =
    FutureProvider.family<List<AccessLevelHistory>, String>((ref, userId) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getUserHistory(userId);
});

final allAccessLevelHistoryProvider =
    FutureProvider<List<AccessLevelHistory>>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getAllHistory();
});

final recentAccessLevelHistoryProvider =
    FutureProvider<List<AccessLevelHistory>>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getRecentHistory();
});

// =====================================================
// STATISTICS PROVIDER
// =====================================================

final accessLevelStatsProvider =
    FutureProvider<Map<AccessLevelType, int>>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.countUsersByLevel();
});

final recentPromotionsProvider =
    FutureProvider<List<AccessLevelHistory>>((ref) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.getRecentPromotions();
});

// =====================================================
// PERMISSION CHECKER PROVIDER
// =====================================================

final hasPermissionProvider =
    FutureProvider.family<bool, AccessLevelType>((ref, requiredLevel) async {
  final repository = ref.watch(accessLevelRepositoryProvider);
  return repository.currentUserHasPermission(requiredLevel);
});

// =====================================================
// HELPER: Verificar se é admin
// =====================================================

final isAdminProvider = FutureProvider<bool>((ref) async {
  final userLevel = await ref.watch(currentUserAccessLevelProvider.future);
  return userLevel?.isAdmin ?? false;
});

// =====================================================
// HELPER: Verificar se é coordenador ou superior
// =====================================================

final isCoordinatorOrAboveProvider = FutureProvider<bool>((ref) async {
  final userLevel = await ref.watch(currentUserAccessLevelProvider.future);
  return userLevel?.isCoordinatorOrAbove ?? false;
});

// =====================================================
// HELPER: Verificar se é líder ou superior
// =====================================================

final isLeaderOrAboveProvider = FutureProvider<bool>((ref) async {
  final userLevel = await ref.watch(currentUserAccessLevelProvider.future);
  return userLevel?.isLeaderOrAbove ?? false;
});

// =====================================================
// HELPER: Verificar se é membro ou superior
// =====================================================

final isMemberOrAboveProvider = FutureProvider<bool>((ref) async {
  final userLevel = await ref.watch(currentUserAccessLevelProvider.future);
  return userLevel?.isMemberOrAbove ?? false;
});

// =====================================================
// ACTIONS: Promover/Rebaixar usuário
// =====================================================

final accessLevelActionsProvider = Provider<AccessLevelActions>((ref) {
  return AccessLevelActions(ref);
});

class AccessLevelActions {
  final Ref ref;

  AccessLevelActions(this.ref);

  /// Promover/rebaixar usuário
  Future<void> updateUserAccessLevel({
    required String userId,
    required AccessLevelType newLevel,
    String? reason,
    String? notes,
  }) async {
    final repository = ref.read(accessLevelRepositoryProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    await repository.updateAccessLevel(
      userId: userId,
      newLevel: newLevel,
      promotedBy: currentUserId,
      reason: reason,
      notes: notes,
    );

    // Invalidar caches
    ref.invalidate(allAccessLevelsProvider);
    ref.invalidate(userAccessLevelProvider(userId));
    ref.invalidate(accessLevelStatsProvider);
    ref.invalidate(recentAccessLevelHistoryProvider);
  }

  /// Criar nível de acesso para novo usuário
  Future<void> createAccessLevel({
    required String userId,
    required AccessLevelType accessLevel,
    String? reason,
    String? notes,
  }) async {
    final repository = ref.read(accessLevelRepositoryProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    await repository.createAccessLevel(
      userId: userId,
      accessLevel: accessLevel,
      promotedBy: currentUserId,
      promotionReason: reason,
      notes: notes,
    );

    // Invalidar caches
    ref.invalidate(allAccessLevelsProvider);
    ref.invalidate(accessLevelStatsProvider);
  }

  /// Deletar nível de acesso
  Future<void> deleteAccessLevel({
    required String userId,
  }) async {
    final repository = ref.read(accessLevelRepositoryProvider);

    await repository.deleteAccessLevel(userId);

    // Invalidar caches
    ref.invalidate(allAccessLevelsProvider);
    ref.invalidate(userAccessLevelProvider(userId));
    ref.invalidate(accessLevelStatsProvider);
  }

  /// Promoção automática para frequentador
  Future<void> autoPromoteToAttendee({
    required String userId,
    required int visitCount,
  }) async {
    final repository = ref.read(accessLevelRepositoryProvider);

    final result = await repository.autoPromoteToAttendee(
      userId: userId,
      visitCount: visitCount,
    );

    if (result != null) {
      // Invalidar caches
      ref.invalidate(allAccessLevelsProvider);
      ref.invalidate(userAccessLevelProvider(userId));
      ref.invalidate(accessLevelStatsProvider);
      ref.invalidate(recentPromotionsProvider);
    }
  }
}

