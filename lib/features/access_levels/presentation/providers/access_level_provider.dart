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

