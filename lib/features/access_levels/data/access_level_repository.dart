// =====================================================
// CHURCH 360 - ACCESS LEVEL REPOSITORY
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/access_level.dart';

class AccessLevelRepository {
  final SupabaseClient _supabase;

  AccessLevelRepository(this._supabase);

  // =====================================================
  // USER ACCESS LEVEL
  // =====================================================

  /// Buscar nível de acesso do usuário atual
  Future<UserAccessLevel?> getCurrentUserAccessLevel() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('user_access_level')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserAccessLevel.fromJson(response);
  }

  /// Buscar nível de acesso de um usuário específico
  Future<UserAccessLevel?> getUserAccessLevel(String userId) async {
    final response = await _supabase
        .from('user_access_level')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserAccessLevel.fromJson(response);
  }

  /// Listar todos os níveis de acesso
  Future<List<UserAccessLevel>> getAllAccessLevels() async {
    final response = await _supabase
        .from('user_access_level')
        .select()
        .order('access_level_number', ascending: false);

    return (response as List)
        .map((json) => UserAccessLevel.fromJson(json))
        .toList();
  }

  /// Listar usuários por nível de acesso
  Future<List<UserAccessLevel>> getUsersByAccessLevel(
    AccessLevelType level,
  ) async {
    final response = await _supabase
        .from('user_access_level')
        .select()
        .eq('access_level', level.name)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => UserAccessLevel.fromJson(json))
        .toList();
  }

  /// Criar nível de acesso para novo usuário
  Future<UserAccessLevel> createAccessLevel({
    required String userId,
    required AccessLevelType accessLevel,
    String? promotedBy,
    String? promotionReason,
    String? notes,
  }) async {
    final data = {
      'user_id': userId,
      'access_level': accessLevel.name,
      'access_level_number': accessLevel.toNumber(),
      'promoted_at': DateTime.now().toIso8601String(),
      'promoted_by': promotedBy,
      'promotion_reason': promotionReason,
      'notes': notes,
    };

    final response = await _supabase
        .from('user_access_level')
        .insert(data)
        .select()
        .single();

    return UserAccessLevel.fromJson(response);
  }

  /// Promover/rebaixar usuário
  Future<UserAccessLevel> updateAccessLevel({
    required String userId,
    required AccessLevelType newLevel,
    required String promotedBy,
    String? reason,
    String? notes,
  }) async {
    final data = {
      'access_level': newLevel.name,
      'access_level_number': newLevel.toNumber(),
      'promoted_at': DateTime.now().toIso8601String(),
      'promoted_by': promotedBy,
      'promotion_reason': reason,
      'notes': notes,
    };

    final response = await _supabase
        .from('user_access_level')
        .update(data)
        .eq('user_id', userId)
        .select()
        .single();

    return UserAccessLevel.fromJson(response);
  }

  /// Deletar nível de acesso
  Future<void> deleteAccessLevel(String userId) async {
    await _supabase
        .from('user_access_level')
        .delete()
        .eq('user_id', userId);
  }

  /// Verificar se usuário tem permissão
  Future<bool> hasPermission(
    String userId,
    AccessLevelType requiredLevel,
  ) async {
    final userLevel = await getUserAccessLevel(userId);
    if (userLevel == null) return false;
    return userLevel.hasPermission(requiredLevel);
  }

  /// Verificar se usuário atual tem permissão
  Future<bool> currentUserHasPermission(
    AccessLevelType requiredLevel,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return hasPermission(userId, requiredLevel);
  }

  // =====================================================
  // ACCESS LEVEL HISTORY
  // =====================================================

  /// Buscar histórico de mudanças de um usuário
  Future<List<AccessLevelHistory>> getUserHistory(String userId) async {
    final response = await _supabase
        .from('access_level_history')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AccessLevelHistory.fromJson(json))
        .toList();
  }

  /// Buscar todo histórico
  Future<List<AccessLevelHistory>> getAllHistory() async {
    final response = await _supabase
        .from('access_level_history')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((json) => AccessLevelHistory.fromJson(json))
        .toList();
  }

  /// Buscar histórico recente (últimos 30 dias)
  Future<List<AccessLevelHistory>> getRecentHistory() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final response = await _supabase
        .from('access_level_history')
        .select()
        .gte('created_at', thirtyDaysAgo.toIso8601String())
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AccessLevelHistory.fromJson(json))
        .toList();
  }

  // =====================================================
  // ESTATÍSTICAS
  // =====================================================

  /// Contar usuários por nível
  Future<Map<AccessLevelType, int>> countUsersByLevel() async {
    final levels = await getAllAccessLevels();

    final counts = <AccessLevelType, int>{};
    for (final level in AccessLevelType.values) {
      counts[level] = levels.where((l) => l.accessLevel == level).length;
    }

    return counts;
  }

  /// Buscar promoções recentes (últimos 7 dias)
  Future<List<AccessLevelHistory>> getRecentPromotions() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final response = await _supabase
        .from('access_level_history')
        .select()
        .gte('created_at', sevenDaysAgo.toIso8601String())
        .order('created_at', ascending: false);

    final history = (response as List)
        .map((json) => AccessLevelHistory.fromJson(json))
        .toList();

    // Filtrar apenas promoções (não rebaixamentos)
    return history.where((h) => h.isPromotion).toList();
  }

  // =====================================================
  // PROMOÇÃO AUTOMÁTICA
  // =====================================================

  /// Promover visitante para frequentador (após 3 visitas)
  Future<UserAccessLevel?> autoPromoteToAttendee({
    required String userId,
    required int visitCount,
  }) async {
    // Verificar se já é frequentador ou superior
    final currentLevel = await getUserAccessLevel(userId);
    if (currentLevel != null && currentLevel.accessLevelNumber >= 1) {
      return null; // Já é frequentador ou superior
    }

    // Verificar se tem 3 ou mais visitas
    if (visitCount < 3) {
      return null; // Ainda não tem visitas suficientes
    }

    // Promover para frequentador
    if (currentLevel == null) {
      // Criar nível inicial como frequentador
      return createAccessLevel(
        userId: userId,
        accessLevel: AccessLevelType.attendee,
        promotionReason: 'Promoção automática após $visitCount visitas',
      );
    } else {
      // Atualizar para frequentador
      return updateAccessLevel(
        userId: userId,
        newLevel: AccessLevelType.attendee,
        promotedBy: userId, // Auto-promoção
        reason: 'Promoção automática após $visitCount visitas',
      );
    }
  }
}

