import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/visitor.dart';

/// Repository para gerenciar visitantes
class VisitorsRepository {
  final SupabaseClient _supabase;

  VisitorsRepository(this._supabase);

  // ==================== VISITORS ====================

  /// Buscar todos os visitantes
  Future<List<Visitor>> getAllVisitors() async {
    final response = await _supabase
        .from('user_account')
        .select('*')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('status', 'visitor')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar visitante por ID
  Future<Visitor?> getVisitorById(String id) async {
    final response = await _supabase
        .from('user_account')
        .select('''
          *,
          mentor:user_account!assigned_mentor_id(first_name, last_name)
        ''')
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return Visitor.fromJson(response);
  }

  // ==================== VISITOR VISITS ====================

  /// Buscar visitas de um visitante
  Future<List<VisitorVisit>> getVisitorVisits(String visitorId) async {
    final response = await _supabase
        .from('user_visit')
        .select()
        .eq('user_id', visitorId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('visit_date', ascending: false);

    return (response as List)
        .map((json) => VisitorVisit.fromJson(json))
        .toList();
  }

  /// Registrar nova visita
  Future<VisitorVisit> createVisit(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('user_visit')
        .insert({
          ...data,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  /// Atualizar visita
  Future<VisitorVisit> updateVisit(String id, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('user_visit')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  /// Deletar visita
  Future<void> deleteVisit(String id) async {
    await _supabase
        .from('user_visit')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Marcar visita como contatada
  Future<VisitorVisit> markVisitAsContacted(
    String visitId,
    String contactNotes,
  ) async {
    final response = await _supabase
        .from('user_visit')
        .update({
          'was_contacted': true,
          'contact_date': DateTime.now().toIso8601String().split('T')[0],
          'contact_notes': contactNotes,
        })
        .eq('id', visitId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  // ==================== VISITOR FOLLOWUPS ====================

  /// Buscar follow-ups de um visitante
  Future<List<VisitorFollowup>> getVisitorFollowups(String visitorId) async {
    final response = await _supabase
        .from('user_followup')
        .select()
        .eq('user_id', visitorId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }

  /// Buscar follow-ups pendentes
  Future<List<VisitorFollowup>> getPendingFollowups() async {
    final response = await _supabase
        .from('user_followup')
        .select()
        .eq('completed', false)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }

  /// Criar follow-up
  Future<VisitorFollowup> createFollowup(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('user_followup')
        .insert({
          ...data,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return VisitorFollowup.fromJson(response);
  }

  /// Atualizar follow-up
  Future<VisitorFollowup> updateFollowup(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('user_followup')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return VisitorFollowup.fromJson(response);
  }

  /// Deletar follow-up
  Future<void> deleteFollowup(String id) async {
    await _supabase
        .from('user_followup')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Marcar follow-up como completo
  Future<VisitorFollowup> completeFollowup(String id) async {
    final response = await _supabase
        .from('user_followup')
        .update({
          'completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return VisitorFollowup.fromJson(response);
  }

  /// Buscar follow-ups do dia
  Future<List<VisitorFollowup>> getTodayFollowups() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _supabase
        .from('user_followup')
        .select()
        .eq('followup_date', today)
        .eq('completed', false)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }
}
