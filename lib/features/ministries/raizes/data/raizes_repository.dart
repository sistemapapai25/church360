import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/models/raizes_dashboard_stats.dart';
import '../domain/models/raizes_sponsor_profile.dart';
import '../domain/models/raizes_visit.dart';
import '../domain/models/visitor_recommendation.dart';

/// Filtro temporal usado pela tela de Agenda de Visitas.
enum RaizesVisitsFilter {
  /// Hoje + atrasadas em aberto.
  todayAndOverdue,

  /// Próximos 7 dias com status aberto.
  upcoming,

  /// Todas as visitas (qualquer status), ordenadas por data desc.
  all,
}

/// Repository do módulo Raízes: dashboard, agenda de visitas e dispatch de lembretes.
class RaizesRepository {
  final SupabaseClient _supabase;

  RaizesRepository(this._supabase);

  // =====================================================
  // DASHBOARD
  // =====================================================

  /// Carrega os KPIs do dashboard em paralelo. Inclui contagens de visitas
  /// (`raizes_visit_schedule`) introduzidas no Lote 4B.
  Future<RaizesDashboardStats> getDashboardStats() async {
    final tenantId = SupabaseConstants.currentTenantId;
    final today = _isoDateToday();
    final thirtyDaysAgo = _isoDate(DateTime.now().subtract(const Duration(days: 30)));

    final results = await Future.wait([
      _countTotalActive(tenantId),
      _countWantingContactPending(tenantId),
      _countWithoutMentor(tenantId),
      _countNewSalvations(tenantId, thirtyDaysAgo),
      _countNewVisitors(tenantId, thirtyDaysAgo),
      _countVisitsOn(tenantId, today),
      _countVisitsOverdue(tenantId, today),
    ]);

    return RaizesDashboardStats(
      totalActiveVisitors: results[0],
      wantingContactPending: results[1],
      withoutMentor: results[2],
      newSalvationsLast30Days: results[3],
      newVisitorsLast30Days: results[4],
      visitsToday: results[5],
      visitsOverdue: results[6],
    );
  }

  Future<int> _countTotalActive(String tenantId) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('status', const ['visitor', 'new_convert'])
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countWantingContactPending(String tenantId) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .eq('status', 'visitor')
        .eq('wants_contact', true)
        .eq('follow_up_status', 'pending')
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countWithoutMentor(String tenantId) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('status', const ['visitor', 'new_convert'])
        .isFilter('assigned_mentor_id', null)
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countNewSalvations(String tenantId, String sinceIsoDate) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .eq('is_salvation', true)
        .gte('salvation_date', sinceIsoDate)
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countNewVisitors(String tenantId, String sinceIsoDate) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('status', const ['visitor', 'new_convert'])
        .gte('first_visit_date', sinceIsoDate)
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countVisitsOn(String tenantId, String todayIso) async {
    final response = await _supabase
        .from('raizes_visit_schedule')
        .select()
        .eq('tenant_id', tenantId)
        .eq('scheduled_date', todayIso)
        .inFilter('status', const ['pending', 'confirmed'])
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countVisitsOverdue(String tenantId, String todayIso) async {
    final response = await _supabase
        .from('raizes_visit_schedule')
        .select()
        .eq('tenant_id', tenantId)
        .lt('scheduled_date', todayIso)
        .inFilter('status', const ['pending', 'confirmed'])
        .count(CountOption.exact);
    return response.count;
  }

  // =====================================================
  // AGENDA DE VISITAS
  // =====================================================

  /// Lista visitas conforme o filtro. Embebe os nomes do visitante e do
  /// responsável via FK direta para `user_account`.
  Future<List<RaizesVisit>> getVisits({
    required String ministryId,
    RaizesVisitsFilter filter = RaizesVisitsFilter.todayAndOverdue,
  }) async {
    final tenantId = SupabaseConstants.currentTenantId;
    final today = _isoDateToday();

    final query = _supabase
        .from('raizes_visit_schedule')
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, phone),'
          'assignee:assigned_to(first_name, last_name)',
        )
        .eq('tenant_id', tenantId)
        .eq('ministry_id', ministryId);

    final filtered = switch (filter) {
      RaizesVisitsFilter.todayAndOverdue => query
          .lte('scheduled_date', today)
          .inFilter('status', const ['pending', 'confirmed']),
      RaizesVisitsFilter.upcoming => query
          .gt('scheduled_date', today)
          .inFilter('status', const ['pending', 'confirmed']),
      RaizesVisitsFilter.all => query,
    };

    final response = await filtered
        .order('scheduled_date', ascending: filter != RaizesVisitsFilter.all)
        .order('scheduled_time', ascending: true, nullsFirst: false);

    return (response as List)
        .map((json) => RaizesVisit.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cria uma visita nova. `scheduledTime` opcional ("HH:mm"); `period`
  /// opcional. O backend valida via CHECK constraints.
  Future<RaizesVisit> createVisit({
    required String ministryId,
    required String visitorId,
    String? assignedTo,
    required DateTime scheduledDate,
    String? scheduledTime,
    RaizesVisitPeriod? period,
    String? notes,
  }) async {
    final currentAuthId = _supabase.auth.currentUser?.id;
    String? createdByUserAccountId;
    if (currentAuthId != null) {
      final me = await _supabase
          .from('user_account')
          .select('id')
          .eq('auth_user_id', currentAuthId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();
      createdByUserAccountId = me?['id'] as String?;
    }

    final payload = <String, dynamic>{
      'tenant_id': SupabaseConstants.currentTenantId,
      'ministry_id': ministryId,
      'visitor_id': visitorId,
      'assigned_to': assignedTo,
      'scheduled_date': _isoDate(scheduledDate),
      'scheduled_time': scheduledTime,
      'period': period?.value,
      'status': RaizesVisitStatus.pending.value,
      'notes': notes,
      'created_by': createdByUserAccountId,
    };
    payload.removeWhere((_, v) => v == null);

    final response = await _supabase
        .from('raizes_visit_schedule')
        .insert(payload)
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, phone),'
          'assignee:assigned_to(first_name, last_name)',
        )
        .single();

    return RaizesVisit.fromJson(response);
  }

  /// Atualiza somente o status. Atualiza `updated_at` por trigger.
  Future<RaizesVisit> updateVisitStatus({
    required String visitId,
    required RaizesVisitStatus status,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'status': status.value,
      if (notes != null) 'notes': notes,
    };

    final response = await _supabase
        .from('raizes_visit_schedule')
        .update(payload)
        .eq('id', visitId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, phone),'
          'assignee:assigned_to(first_name, last_name)',
        )
        .single();

    return RaizesVisit.fromJson(response);
  }

  /// Deleta uma visita (apaga histórico). Usado raramente — em geral preferir
  /// status `cancelled`.
  Future<void> deleteVisit(String visitId) async {
    await _supabase
        .from('raizes_visit_schedule')
        .delete()
        .eq('id', visitId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // LEMBRETES INTERNOS
  // =====================================================

  /// Dispara a RPC server-side que cria notificações para as visitas do dia
  /// e atrasadas. Retorna a quantidade criada nesta chamada. Idempotente.
  Future<int> dispatchVisitReminders() async {
    final response = await _supabase.rpc('raizes_dispatch_visit_reminders');
    if (response is int) return response;
    if (response is num) return response.toInt();
    return 0;
  }

  /// Marca `reminder_whatsapp_sent_at = now()` na visita. Chamado pela UI
  /// **após** o usuário disparar o WhatsApp via wa.me launcher (Lote MR4C.4).
  /// Idempotente — re-chamar sobrescreve o timestamp.
  Future<RaizesVisit> markVisitWhatsappReminderSent(String visitId) async {
    final response = await _supabase
        .from('raizes_visit_schedule')
        .update({'reminder_whatsapp_sent_at': DateTime.now().toIso8601String()})
        .eq('id', visitId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, phone),'
          'assignee:assigned_to(first_name, last_name)',
        )
        .single();
    return RaizesVisit.fromJson(response);
  }

  // =====================================================
  // LISTAS AUXILIARES PARA FORMULÁRIOS
  // =====================================================

  /// Visitantes elegíveis a receber visita: status visitor/new_convert,
  /// is_active=true.
  Future<List<Map<String, String>>> getEligibleVisitors() async {
    final response = await _supabase
        .from('user_account')
        .select('id, first_name, last_name')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .inFilter('status', const ['visitor', 'new_convert'])
        .eq('is_active', true)
        .order('first_name', ascending: true);

    return (response as List).map<Map<String, String>>((row) {
      final first = (row['first_name'] as String?)?.trim() ?? '';
      final last = (row['last_name'] as String?)?.trim() ?? '';
      final fullName = '$first $last'.trim();
      return {
        'id': row['id'] as String,
        'name': fullName.isEmpty ? 'Visitante' : fullName,
      };
    }).toList();
  }

  /// Responsáveis elegíveis: membros do ministério (ministry_member). Vem com
  /// nome para uso direto no dropdown.
  Future<List<Map<String, String>>> getEligibleAssignees(String ministryId) async {
    final response = await _supabase
        .from('ministry_member')
        .select(
          'user_id, user:user_id(first_name, last_name)',
        )
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId);

    final out = <Map<String, String>>[];
    for (final row in (response as List)) {
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      final user = row['user'] as Map<String, dynamic>?;
      final first = (user?['first_name'] as String?)?.trim() ?? '';
      final last = (user?['last_name'] as String?)?.trim() ?? '';
      final full = '$first $last'.trim();
      out.add({
        'id': userId,
        'name': full.isEmpty ? 'Membro do ministério' : full,
      });
    }
    out.sort((a, b) => a['name']!.compareTo(b['name']!));
    return out;
  }

  // =====================================================
  // INDICAÇÕES DE PADRINHO (MR4C.1)
  // =====================================================

  /// Dispara a RPC `generate_visitor_recommendations` para o ministério.
  /// Retorna a quantidade de pares (visitante, sponsor) avaliados com score > 0.
  /// Idempotente — re-chamar não duplica e preserva decisões aceitas/recusadas.
  Future<int> generateRecommendations(String ministryId) async {
    final response = await _supabase.rpc(
      'generate_visitor_recommendations',
      params: {'p_ministry_id': ministryId},
    );
    if (response is int) return response;
    if (response is num) return response.toInt();
    return 0;
  }

  /// Lista de recomendações de um ministério com info joined de visitor +
  /// sponsor (nome, foto). Filtra por status e ordena por (score DESC, generated_at DESC).
  Future<List<VisitorRecommendation>> getRecommendations({
    required String ministryId,
    VisitorRecommendationStatus? status,
  }) async {
    final query = _supabase
        .from('visitor_recommendation')
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, photo_url, birthdate, gender, marital_status, interests),'
          'sponsor_profile:sponsor_profile_id('
          '  id, user_id,'
          '  user:user_id(first_name, last_name, photo_url)'
          ')',
        )
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId);

    final filtered = status == null ? query : query.eq('status', status.value);

    final response = await filtered
        .order('score', ascending: false)
        .order('generated_at', ascending: false);

    return (response as List)
        .map((j) => VisitorRecommendation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Aceita uma recomendação via RPC transacional: marca status=accepted,
  /// seta `user_account.assigned_mentor_id` no visitante, arquiva outras
  /// pendências do mesmo visitante.
  Future<bool> acceptRecommendation(String recommendationId) async {
    final response = await _supabase.rpc(
      'accept_visitor_recommendation',
      params: {'p_recommendation_id': recommendationId},
    );
    return response == true;
  }

  /// Recusa uma recomendação. `notes` opcional para registrar motivo.
  /// Não toca em `user_account.assigned_mentor_id`.
  Future<VisitorRecommendation> rejectRecommendation({
    required String recommendationId,
    String? notes,
  }) async {
    final decidedBy = await _resolveCurrentUserAccountId();
    final payload = <String, dynamic>{
      'status': VisitorRecommendationStatus.rejected.value,
      'decided_by': decidedBy,
      'decided_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
    };

    final response = await _supabase
        .from('visitor_recommendation')
        .update(payload)
        .eq('id', recommendationId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, photo_url, birthdate, gender, marital_status, interests),'
          'sponsor_profile:sponsor_profile_id('
          '  id, user_id,'
          '  user:user_id(first_name, last_name, photo_url)'
          ')',
        )
        .single();
    return VisitorRecommendation.fromJson(response);
  }

  /// Arquiva uma recomendação (esconde da fila sem marcar accept/reject).
  Future<VisitorRecommendation> archiveRecommendation(
    String recommendationId,
  ) async {
    final decidedBy = await _resolveCurrentUserAccountId();
    final payload = <String, dynamic>{
      'status': VisitorRecommendationStatus.archived.value,
      'decided_by': decidedBy,
      'decided_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('visitor_recommendation')
        .update(payload)
        .eq('id', recommendationId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'visitor:visitor_id(first_name, last_name, photo_url, birthdate, gender, marital_status, interests),'
          'sponsor_profile:sponsor_profile_id('
          '  id, user_id,'
          '  user:user_id(first_name, last_name, photo_url)'
          ')',
        )
        .single();
    return VisitorRecommendation.fromJson(response);
  }

  // =====================================================
  // PERFIS DE PADRINHO (MR4C.3)
  // =====================================================

  /// Lista de padrinhos cadastrados no ministério, com info joined do
  /// `user_account` (first_name, last_name, photo_url) para render direto.
  /// Ordem: ativos primeiro, depois alfabético por nome.
  Future<List<RaizesSponsorProfile>> getSponsorProfiles(
    String ministryId,
  ) async {
    final response = await _supabase
        .from('raizes_sponsor_profile')
        .select(
          '*,'
          'user:user_id(first_name, last_name, photo_url)',
        )
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId)
        .order('is_active', ascending: false);

    final list = (response as List)
        .map((j) => RaizesSponsorProfile.fromJson(j as Map<String, dynamic>))
        .toList();

    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
    });
    return list;
  }

  /// Membros do ministério ainda não cadastrados como padrinho. Útil pro
  /// dropdown de "criar novo padrinho".
  Future<List<Map<String, String>>> getEligibleSponsorCandidates(
    String ministryId,
  ) async {
    final members = await getEligibleAssignees(ministryId);
    final existing = await _supabase
        .from('raizes_sponsor_profile')
        .select('user_id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId);
    final existingUserIds = (existing as List)
        .map((row) => (row as Map)['user_id'] as String?)
        .whereType<String>()
        .toSet();
    return members.where((m) => !existingUserIds.contains(m['id'])).toList();
  }

  /// Cria um novo perfil de padrinho. Idempotente via UNIQUE
  /// (tenant, ministry, user) — re-chamadas com o mesmo par falham com erro
  /// PostgREST 23505. Cabe ao caller mostrar a mensagem amigável.
  Future<RaizesSponsorProfile> createSponsorProfile({
    required String ministryId,
    required String userId,
    int? minAge,
    int? maxAge,
    required List<String> maritalStatuses,
    required List<String> genders,
    required List<String> lifeStages,
    required List<String> interests,
    bool isActive = true,
    String? notes,
  }) async {
    final createdBy = await _resolveCurrentUserAccountId();
    final payload = <String, dynamic>{
      'tenant_id': SupabaseConstants.currentTenantId,
      'ministry_id': ministryId,
      'user_id': userId,
      'min_age': minAge,
      'max_age': maxAge,
      'marital_statuses': maritalStatuses,
      'genders': genders,
      'life_stages': lifeStages,
      'interests': interests,
      'is_active': isActive,
      'notes': notes,
      'created_by': createdBy,
    };
    payload.removeWhere((_, v) => v == null);

    final response = await _supabase
        .from('raizes_sponsor_profile')
        .insert(payload)
        .select(
          '*,'
          'user:user_id(first_name, last_name, photo_url)',
        )
        .single();
    return RaizesSponsorProfile.fromJson(response);
  }

  /// Atualiza critérios de um perfil de padrinho. `user_id` e `ministry_id`
  /// são imutáveis (definidos na criação).
  Future<RaizesSponsorProfile> updateSponsorProfile({
    required String id,
    int? minAge,
    int? maxAge,
    List<String>? maritalStatuses,
    List<String>? genders,
    List<String>? lifeStages,
    List<String>? interests,
    bool? isActive,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      if (minAge != null) 'min_age': minAge,
      if (maxAge != null) 'max_age': maxAge,
      if (maritalStatuses != null) 'marital_statuses': maritalStatuses,
      if (genders != null) 'genders': genders,
      if (lifeStages != null) 'life_stages': lifeStages,
      if (interests != null) 'interests': interests,
      if (isActive != null) 'is_active': isActive,
      if (notes != null) 'notes': notes,
    };

    final response = await _supabase
        .from('raizes_sponsor_profile')
        .update(payload)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'user:user_id(first_name, last_name, photo_url)',
        )
        .single();
    return RaizesSponsorProfile.fromJson(response);
  }

  /// Para campos que precisam de UPDATE com NULL explícito (ex.: limpar
  /// `min_age` ou `max_age`), use este método com o map completo.
  Future<RaizesSponsorProfile> patchSponsorProfile({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _supabase
        .from('raizes_sponsor_profile')
        .update(payload)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(
          '*,'
          'user:user_id(first_name, last_name, photo_url)',
        )
        .single();
    return RaizesSponsorProfile.fromJson(response);
  }

  /// Remove um perfil de padrinho. Hard delete — não há histórico.
  /// Cascade da migration deleta `visitor_recommendation` relacionadas.
  Future<void> deleteSponsorProfile(String id) async {
    await _supabase
        .from('raizes_sponsor_profile')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<String?> _resolveCurrentUserAccountId() async {
    final currentAuthId = _supabase.auth.currentUser?.id;
    if (currentAuthId == null) return null;
    final me = await _supabase
        .from('user_account')
        .select('id')
        .eq('auth_user_id', currentAuthId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();
    return me?['id'] as String?;
  }

  // =====================================================
  // HELPERS
  // =====================================================

  String _isoDateToday() => _isoDate(DateTime.now());

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
