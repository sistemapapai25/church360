import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/models/raizes_dashboard_stats.dart';
import '../domain/models/raizes_visit.dart';

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
          'visitor:visitor_id(first_name, last_name),'
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
          'visitor:visitor_id(first_name, last_name),'
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
          'visitor:visitor_id(first_name, last_name),'
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
  // HELPERS
  // =====================================================

  String _isoDateToday() => _isoDate(DateTime.now());

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
