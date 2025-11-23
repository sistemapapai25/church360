import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
        .eq('status', 'visitor')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar visitantes por status
  Future<List<Visitor>> getVisitorsByStatus(VisitorStatus status) async {
    final response = await _supabase
        .from('user_account')
        .select('''
          *,
          mentor:user_account!assigned_mentor_id(first_name, last_name)
        ''')
        .eq('status', 'visitor')
        .order('first_visit_date', ascending: false);

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
        .maybeSingle();

    if (response == null) return null;
    return Visitor.fromJson(response);
  }

  /// Criar visitante
  Future<Visitor> createVisitor(Map<String, dynamic> data) async {
    // Gerar UUID para o visitante (não tem conta Auth)
    const uuid = Uuid();
    final visitorId = uuid.v4();

    // Mapear campos para user_account
    final userData = {
      'id': visitorId, // Gerar UUID manualmente
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'email': data['email'],
      'phone': data['phone'],
      'birthdate': data['birth_date'], // birth_date → birthdate
      'address': data['address'],
      'city': data['city'],
      'state': data['state'],
      'zip_code': data['zip_code'],
      'gender': data['gender'],
      'status': 'visitor', // SEMPRE 'visitor' para user_account (member_status ENUM)
      'is_active': true,
      'first_visit_date': data['first_visit_date'],
      'last_visit_date': data['last_visit_date'],
      'assigned_mentor_id': data['assigned_mentor_id'],
      'follow_up_status': data['follow_up_status'],
      'last_contact_date': data['last_contact_date'],
      'wants_contact': data['wants_contact'],
      'wants_to_return': data['wants_to_return'],
      'notes': data['notes'],
    };

    // Remover campos null
    userData.removeWhere((key, value) => value == null);

    final response = await _supabase
        .from('user_account')
        .insert(userData)
        .select()
        .single();

    return Visitor.fromJson(response);
  }

  /// Atualizar visitante
  Future<Visitor> updateVisitor(String id, Map<String, dynamic> data) async {
    // Mapear campos para user_account
    final userData = {
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'email': data['email'],
      'phone': data['phone'],
      'birthdate': data['birth_date'], // birth_date → birthdate
      'address': data['address'],
      'city': data['city'],
      'state': data['state'],
      'zip_code': data['zip_code'],
      'gender': data['gender'],
      'first_visit_date': data['first_visit_date'],
      'last_visit_date': data['last_visit_date'],
      'assigned_mentor_id': data['assigned_mentor_id'],
      'follow_up_status': data['follow_up_status'],
      'last_contact_date': data['last_contact_date'],
      'wants_contact': data['wants_contact'],
      'wants_to_return': data['wants_to_return'],
      'notes': data['notes'],
      // NÃO atualizar 'status' - deve permanecer 'visitor' em user_account
    };

    // Remover campos null
    userData.removeWhere((key, value) => value == null);

    final response = await _supabase
        .from('user_account')
        .update(userData)
        .eq('id', id)
        .select()
        .single();

    return Visitor.fromJson(response);
  }

  /// Deletar visitante
  Future<void> deleteVisitor(String id) async {
    await _supabase.from('user_account').delete().eq('id', id);
  }

  /// Converter visitante em membro
  Future<Visitor> convertToMember(String visitorId, String memberId) async {
    final response = await _supabase
        .from('user_account')
        .update({
          'status': 'member_active',
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

  // ==================== VISITANTES DE REUNIÕES ====================

  /// Buscar visitantes de uma reunião específica
  Future<List<Visitor>> getVisitorsByMeeting(String meetingId) async {
    final response = await _supabase
        .from('visitor')
        .select('''
          *,
          mentor:member!assigned_mentor_id(first_name, last_name)
        ''')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Buscar todas as salvações
  Future<List<Visitor>> getAllSalvations() async {
    final response = await _supabase
        .from('visitor')
        .select('''
          *,
          mentor:member!assigned_mentor_id(first_name, last_name)
        ''')
        .eq('is_salvation', true)
        .order('salvation_date', ascending: false);

    return (response as List)
        .map((json) => Visitor.fromJson(json))
        .toList();
  }

  /// Contar total de salvações
  Future<int> countSalvations() async {
    final response = await _supabase
        .from('visitor')
        .select()
        .eq('is_salvation', true);

    return (response as List).length;
  }

  /// Contar salvações por período
  Future<int> countSalvationsByPeriod(DateTime startDate, DateTime endDate) async {
    final response = await _supabase
        .from('visitor')
        .select()
        .eq('is_salvation', true)
        .gte('salvation_date', startDate.toIso8601String().split('T')[0])
        .lte('salvation_date', endDate.toIso8601String().split('T')[0]);

    return (response as List).length;
  }
}

