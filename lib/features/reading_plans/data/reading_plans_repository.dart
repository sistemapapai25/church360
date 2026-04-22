import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/reading_plan.dart';

/// Repository para gerenciar planos de leitura
class ReadingPlansRepository {
  final SupabaseClient _supabase;

  ReadingPlansRepository(this._supabase);

  Future<Set<String>> _candidateUserIds(String memberId) async {
    final ids = <String>{};
    final normalizedMemberId = memberId.trim();
    if (normalizedMemberId.isNotEmpty) {
      ids.add(normalizedMemberId);
    }

    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.trim().isNotEmpty) {
      ids.add(authId.trim());
    }

    final seeds = ids.toList(growable: false);
    for (final seed in seeds) {
      try {
        final rows = await _supabase
            .from('user_account')
            .select('id, auth_user_id')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .or('id.eq.$seed,auth_user_id.eq.$seed')
            .limit(5);

        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] as String?)?.trim();
          final authUserId = (row['auth_user_id'] as String?)?.trim();
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
          if (authUserId != null && authUserId.isNotEmpty) {
            ids.add(authUserId);
          }
        }
      } catch (_) {}
    }

    return ids;
  }

  /// Buscar todos os planos de leitura
  Future<List<ReadingPlan>> getAllPlans() async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReadingPlan.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar planos ativos
  Future<List<ReadingPlan>> getActivePlans() async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .select()
          .eq('status', 'active')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReadingPlan.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar plano por ID
  Future<ReadingPlan?> getPlanById(String id) async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;

      return ReadingPlan.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo plano
  Future<ReadingPlan> createPlan(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .insert({...data, 'tenant_id': SupabaseConstants.currentTenantId})
          .select()
          .single();

      return ReadingPlan.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar plano
  Future<ReadingPlan> updatePlan(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return ReadingPlan.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar plano
  Future<void> deletePlan(String id) async {
    try {
      await _supabase
          .from('reading_plan')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar progresso do usuário em um plano
  Future<ReadingPlanProgress?> getUserProgress(
    String planId,
    String memberId,
  ) async {
    try {
      final candidateIds = await _candidateUserIds(memberId);
      final scopedResponse = await _supabase
          .from('reading_plan_progress')
          .select()
          .eq('plan_id', planId)
          .inFilter('user_id', candidateIds.toList())
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (scopedResponse != null) {
        return ReadingPlanProgress.fromJson(scopedResponse);
      }

      // Fallback para dados legados sem tenant_id preenchido.
      final legacyResponse = await _supabase
          .from('reading_plan_progress')
          .select()
          .eq('plan_id', planId)
          .inFilter('user_id', candidateIds.toList())
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (legacyResponse == null) return null;

      final currentTenant = legacyResponse['tenant_id'] as String?;
      final shouldSyncTenant =
          currentTenant == null ||
          currentTenant.isEmpty ||
          currentTenant != SupabaseConstants.currentTenantId;
      if (shouldSyncTenant) {
        final progressId = legacyResponse['id'] as String?;
        if (progressId != null && progressId.isNotEmpty) {
          await _supabase
              .from('reading_plan_progress')
              .update({'tenant_id': SupabaseConstants.currentTenantId})
              .eq('id', progressId);
        } else {
          await _supabase
              .from('reading_plan_progress')
              .update({'tenant_id': SupabaseConstants.currentTenantId})
              .eq('plan_id', planId)
              .inFilter('user_id', candidateIds.toList());
        }
      }

      return ReadingPlanProgress.fromJson({
        ...legacyResponse,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Iniciar plano (criar progresso)
  Future<ReadingPlanProgress> startPlan(String planId, String memberId) async {
    try {
      // Idempotência: se o progresso já existir, retorna o registro atual.
      final existing = await getUserProgress(planId, memberId);
      if (existing != null) {
        return existing;
      }

      final data = {
        'plan_id': planId,
        'user_id': memberId,
        'started_at': DateTime.now().toIso8601String(),
        'current_day': 1,
        'tenant_id': SupabaseConstants.currentTenantId,
      };

      await _supabase
          .from('reading_plan_progress')
          .upsert(data, onConflict: 'plan_id,user_id', ignoreDuplicates: true);

      final progress = await getUserProgress(planId, memberId);
      if (progress != null) return progress;

      throw Exception('Não foi possível iniciar o plano de leitura');
    } on PostgrestException catch (e) {
      // Em corrida de concorrência, reaproveita o progresso já criado.
      if (e.code == '23505') {
        final existing = await getUserProgress(planId, memberId);
        if (existing != null) {
          return existing;
        }
        // Fallback: não quebra o fluxo do usuário em cenário legado.
        final now = DateTime.now();
        return ReadingPlanProgress(
          planId: planId,
          memberId: memberId,
          startedAt: now,
          currentDay: 1,
        );
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar progresso
  Future<ReadingPlanProgress> updateProgress(
    String planId,
    String memberId,
    int currentDay,
  ) async {
    try {
      final existing = await getUserProgress(planId, memberId);
      if (existing == null) {
        throw Exception('Plano não iniciado');
      }

      final sanitizedDay = currentDay < 1 ? 1 : currentDay;
      final data = {
        'current_day': sanitizedDay,
        'last_read_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('reading_plan_progress')
          .update(data)
          .eq('plan_id', planId)
          .eq('user_id', existing.memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return ReadingPlanProgress.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Completar plano
  Future<ReadingPlanProgress> completePlan(
    String planId,
    String memberId,
  ) async {
    try {
      final existing = await getUserProgress(planId, memberId);
      if (existing == null) {
        throw Exception('Plano não iniciado');
      }

      final data = {
        'completed_at': DateTime.now().toIso8601String(),
        'last_read_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('reading_plan_progress')
          .update(data)
          .eq('plan_id', planId)
          .eq('user_id', existing.memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return ReadingPlanProgress.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar o módulo/dia atual como lido e avançar no plano.
  /// Quando chega ao último módulo, conclui automaticamente o plano.
  Future<ReadingPlanProgress> markCurrentDayAsRead({
    required String planId,
    required String memberId,
    required int totalDays,
  }) async {
    final progress = await getUserProgress(planId, memberId);
    if (progress == null) {
      throw Exception('Plano ainda não foi iniciado');
    }

    if (progress.isCompleted) {
      return progress;
    }

    final normalizedTotalDays = totalDays < 1 ? 1 : totalDays;
    if (progress.currentDay >= normalizedTotalDays) {
      return completePlan(planId, memberId);
    }

    return updateProgress(planId, memberId, progress.currentDay + 1);
  }

  /// Reinicia o progresso do plano para o usuário atual.
  Future<ReadingPlanProgress> restartPlan({
    required String planId,
    required String memberId,
  }) async {
    final existing = await getUserProgress(planId, memberId);
    if (existing == null) {
      return startPlan(planId, memberId);
    }

    final response = await _supabase
        .from('reading_plan_progress')
        .update({
          'started_at': DateTime.now().toIso8601String(),
          'current_day': 1,
          'completed_at': null,
          'last_read_at': null,
        })
        .eq('plan_id', planId)
        .eq('user_id', existing.memberId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return ReadingPlanProgress.fromJson(response);
  }

  /// Buscar todos os planos em progresso do usuário
  Future<List<ReadingPlanProgress>> getUserActiveProgress(
    String memberId,
  ) async {
    try {
      final candidateIds = await _candidateUserIds(memberId);
      final response = await _supabase
          .from('reading_plan_progress')
          .select()
          .inFilter('user_id', candidateIds.toList())
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('completed_at', null)
          .order('started_at', ascending: false);

      return (response as List)
          .map((json) => ReadingPlanProgress.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
