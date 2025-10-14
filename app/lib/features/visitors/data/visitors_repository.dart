import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/visitor.dart';

/// Repository para gerenciar visitantes
class VisitorsRepository {
  final SupabaseClient _supabase;

  VisitorsRepository(this._supabase);

  // ==================== VISITORS ====================

  /// Buscar todos os visitantes
  Future<List<Visitor>> getAllVisitors() async {
    final response = await _supabase
        .from('visitor')
        .select()
        .order('first_visit_date', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar visitantes por status
  Future<List<Visitor>> getVisitorsByStatus(VisitorStatus status) async {
    final response = await _supabase
        .from('visitor')
        .select()
        .eq('status', status.value)
        .order('first_visit_date', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar visitante por ID
  Future<Visitor?> getVisitorById(String id) async {
    final response = await _supabase
        .from('visitor')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Visitor.fromJson(response);
  }

  /// Criar visitante
  Future<Visitor> createVisitor(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('visitor')
        .insert(data)
        .select()
        .single();

    return Visitor.fromJson(response);
  }

  /// Atualizar visitante
  Future<Visitor> updateVisitor(String id, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('visitor')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return Visitor.fromJson(response);
  }

  /// Deletar visitante
  Future<void> deleteVisitor(String id) async {
    await _supabase.from('visitor').delete().eq('id', id);
  }

  /// Converter visitante em membro
  Future<Visitor> convertToMember(String visitorId, String memberId) async {
    final response = await _supabase
        .from('visitor')
        .update({
          'status': 'converted',
          'converted_to_member_id': memberId,
          'converted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', visitorId)
        .select()
        .single();

    return Visitor.fromJson(response);
  }

  /// Buscar visitantes recentes (últimos 30 dias)
  Future<List<Visitor>> getRecentVisitors() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final response = await _supabase
        .from('visitor')
        .select()
        .gte('first_visit_date', thirtyDaysAgo.toIso8601String().split('T')[0])
        .order('first_visit_date', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar visitantes inativos (sem visita há mais de X dias)
  Future<List<Visitor>> getInactiveVisitors({int days = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    final response = await _supabase
        .from('visitor')
        .select()
        .lt('last_visit_date', cutoffDate.toIso8601String().split('T')[0])
        .neq('status', 'converted')
        .order('last_visit_date', ascending: true);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Contar visitantes por status
  Future<Map<VisitorStatus, int>> countVisitorsByStatus() async {
    final response = await _supabase
        .from('visitor')
        .select('status');

    final counts = <VisitorStatus, int>{};
    for (final status in VisitorStatus.values) {
      counts[status] = 0;
    }

    for (final row in response as List) {
      final status = VisitorStatus.fromValue(row['status'] as String);
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  // ==================== VISITOR VISITS ====================

  /// Buscar visitas de um visitante
  Future<List<VisitorVisit>> getVisitorVisits(String visitorId) async {
    final response = await _supabase
        .from('visitor_visit')
        .select()
        .eq('visitor_id', visitorId)
        .order('visit_date', ascending: false);

    return (response as List)
        .map((json) => VisitorVisit.fromJson(json))
        .toList();
  }

  /// Registrar nova visita
  Future<VisitorVisit> createVisit(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('visitor_visit')
        .insert(data)
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  /// Atualizar visita
  Future<VisitorVisit> updateVisit(String id, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('visitor_visit')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  /// Deletar visita
  Future<void> deleteVisit(String id) async {
    await _supabase.from('visitor_visit').delete().eq('id', id);
  }

  /// Marcar visita como contatada
  Future<VisitorVisit> markVisitAsContacted(
    String visitId,
    String contactNotes,
  ) async {
    final response = await _supabase
        .from('visitor_visit')
        .update({
          'was_contacted': true,
          'contact_date': DateTime.now().toIso8601String().split('T')[0],
          'contact_notes': contactNotes,
        })
        .eq('id', visitId)
        .select()
        .single();

    return VisitorVisit.fromJson(response);
  }

  // ==================== VISITOR FOLLOWUPS ====================

  /// Buscar follow-ups de um visitante
  Future<List<VisitorFollowup>> getVisitorFollowups(String visitorId) async {
    final response = await _supabase
        .from('visitor_followup')
        .select()
        .eq('visitor_id', visitorId)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }

  /// Buscar follow-ups pendentes
  Future<List<VisitorFollowup>> getPendingFollowups() async {
    final response = await _supabase
        .from('visitor_followup')
        .select()
        .eq('completed', false)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }

  /// Criar follow-up
  Future<VisitorFollowup> createFollowup(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('visitor_followup')
        .insert(data)
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
        .from('visitor_followup')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return VisitorFollowup.fromJson(response);
  }

  /// Deletar follow-up
  Future<void> deleteFollowup(String id) async {
    await _supabase.from('visitor_followup').delete().eq('id', id);
  }

  /// Marcar follow-up como completo
  Future<VisitorFollowup> completeFollowup(String id) async {
    final response = await _supabase
        .from('visitor_followup')
        .update({
          'completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return VisitorFollowup.fromJson(response);
  }

  /// Buscar follow-ups do dia
  Future<List<VisitorFollowup>> getTodayFollowups() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final response = await _supabase
        .from('visitor_followup')
        .select()
        .eq('followup_date', today)
        .eq('completed', false)
        .order('followup_date', ascending: true);

    return (response as List)
        .map((json) => VisitorFollowup.fromJson(json))
        .toList();
  }
}

