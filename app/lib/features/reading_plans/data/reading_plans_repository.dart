import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/reading_plan.dart';

/// Repository para gerenciar planos de leitura
class ReadingPlansRepository {
  final SupabaseClient _supabase;

  ReadingPlansRepository(this._supabase);

  /// Buscar todos os planos de leitura
  Future<List<ReadingPlan>> getAllPlans() async {
    try {
      final response = await _supabase
          .from('reading_plan')
          .select()
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
          .insert(data)
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
      await _supabase.from('reading_plan').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar progresso do usuário em um plano
  Future<ReadingPlanProgress?> getUserProgress(String planId, String memberId) async {
    try {
      final response = await _supabase
          .from('reading_plan_progress')
          .select()
          .eq('plan_id', planId)
          .eq('user_id', memberId)
          .maybeSingle();

      if (response == null) return null;

      return ReadingPlanProgress.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Iniciar plano (criar progresso)
  Future<ReadingPlanProgress> startPlan(String planId, String memberId) async {
    try {
      final data = {
        'plan_id': planId,
        'user_id': memberId,
        'started_at': DateTime.now().toIso8601String(),
        'current_day': 1,
      };

      final response = await _supabase
          .from('reading_plan_progress')
          .insert(data)
          .select()
          .single();

      return ReadingPlanProgress.fromJson(response);
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
      final data = {
        'current_day': currentDay,
        'last_read_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('reading_plan_progress')
          .update(data)
          .eq('plan_id', planId)
          .eq('user_id', memberId)
          .select()
          .single();

      return ReadingPlanProgress.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Completar plano
  Future<ReadingPlanProgress> completePlan(String planId, String memberId) async {
    try {
      final data = {
        'completed_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('reading_plan_progress')
          .update(data)
          .eq('plan_id', planId)
          .eq('user_id', memberId)
          .select()
          .single();

      return ReadingPlanProgress.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar todos os planos em progresso do usuário
  Future<List<ReadingPlanProgress>> getUserActiveProgress(String memberId) async {
    try {
      final response = await _supabase
          .from('reading_plan_progress')
          .select()
          .eq('user_id', memberId)
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
