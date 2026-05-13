import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../domain/auto_scheduler_service.dart';

/// Lote 3 (#11, #13): persiste auditoria de cada geração de escala e as
/// pendências manuais para revisão posterior.
class ScheduleAuditRepository {
  final SupabaseClient _supabase;
  ScheduleAuditRepository(this._supabase);

  /// Insere um registro em `schedule_audit` para o evento dado.
  /// Retorna o `audit_id` para vinculação com pendências.
  Future<String?> recordAudit(EventScheduleReport report) async {
    if (report.slots.isEmpty && report.generalNote == null) {
      return null; // nada a auditar (evento sem cfg e sem presença)
    }
    final userId = _supabase.auth.currentUser?.id;
    final ministryIds =
        report.slots.map((s) => s.ministryId).toSet().toList();
    final relaxed = <String>{
      for (final s in report.slots) ...s.relaxedRules,
    }.toList();
    final slotsJson = report.slots
        .map((s) => {
              'ministry_id': s.ministryId,
              'func_name': s.funcName,
              'expected': s.expected,
              'inserted': s.inserted,
              'reason': s.reason,
              'relaxed_rules': s.relaxedRules.toList(),
            })
        .toList();
    final payload = <String, dynamic>{
      'tenant_id': SupabaseConstants.currentTenantId,
      'event_id': report.eventId,
      'ministry_id': ministryIds.length == 1 ? ministryIds.first : null,
      'status': report.status.name, // 'ok' | 'partial' | 'empty'
      'total_expected': report.totalExpected,
      'total_inserted': report.totalInserted,
      'general_note': report.generalNote,
      'slots': slotsJson,
      'relaxed_rules': relaxed,
      'generated_by': userId,
    };
    final response = await _supabase
        .from('schedule_audit')
        .insert(payload)
        .select('id')
        .single();
    return response['id']?.toString();
  }

  /// Persiste pendências (slots não-OK) ligadas a um audit.
  /// Idempotente por (event_id, ministry_id, func_name) enquanto status='open'
  /// — a unique index parcial no banco evita duplicatas.
  Future<void> recordPendings(
    EventScheduleReport report,
    String auditId,
  ) async {
    final pending = report.slots
        .where((s) =>
            s.status != ScheduleSlotStatus.ok && s.ministryId.isNotEmpty)
        .toList();
    if (pending.isEmpty) return;
    final rows = pending
        .map((s) => {
              'tenant_id': SupabaseConstants.currentTenantId,
              'event_id': report.eventId,
              'ministry_id': s.ministryId,
              'func_name': s.funcName,
              'expected': s.expected,
              'inserted': s.inserted,
              'reason': s.reason,
              'audit_id': auditId,
            })
        .toList();
    try {
      await _supabase.from('schedule_pending').insert(rows);
    } on PostgrestException catch (e) {
      // Código 23505 = unique_violation (pendência aberta já existe).
      // Não é erro real do ponto de vista de UX — significa que aquele slot
      // já tem uma pendência registrada. Logar e seguir.
      if (e.code == '23505') {
        // Tentar inserir uma por uma para não perder as não-duplicadas.
        for (final r in rows) {
          try {
            await _supabase.from('schedule_pending').insert(r);
          } catch (_) {/* já existe ou outro erro: ignora individualmente */}
        }
        return;
      }
      rethrow;
    }
  }

  /// Lista pendências abertas, opcionalmente filtradas por ministério.
  Future<List<Map<String, dynamic>>> listOpenPendings({
    String? ministryId,
  }) async {
    final query = _supabase
        .from('schedule_pending')
        .select('*, event:event_id(name, start_date)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('status', 'open');
    final filtered = ministryId != null
        ? query.eq('ministry_id', ministryId)
        : query;
    final response = await filtered.order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Lote 4: listagem de pendências com filtros completos para a tela
  /// dedicada. `status` aceita 'open' | 'resolved' | 'dismissed' | null (todos).
  /// Funções e datas são filtradas server-side quando possível.
  Future<List<Map<String, dynamic>>> listPendings({
    String? status,
    String? ministryId,
    String? funcName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _supabase
        .from('schedule_pending')
        .select('*, event:event_id(name, start_date), ministry:ministry_id(name)')
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    if (status != null) query = query.eq('status', status);
    if (ministryId != null) query = query.eq('ministry_id', ministryId);
    if (funcName != null && funcName.isNotEmpty) {
      query = query.eq('func_name', funcName);
    }
    final response = await query.order('created_at', ascending: false);
    var list = (response as List).cast<Map<String, dynamic>>();
    // Filtros por data sobre `event.start_date` — feitos client-side para
    // evitar embed-filter (que tem sintaxe específica e quebra fácil).
    if (fromDate != null || toDate != null) {
      list = list.where((p) {
        final ev = (p['event'] as Map?)?.cast<String, dynamic>();
        final raw = ev?['start_date']?.toString();
        final dt = raw != null ? DateTime.tryParse(raw) : null;
        if (dt == null) return false;
        if (fromDate != null && dt.isBefore(fromDate)) return false;
        if (toDate != null && dt.isAfter(toDate)) return false;
        return true;
      }).toList();
    }
    return list;
  }

  /// Lote 4: lista entradas de auditoria para a tela de histórico. Filtros
  /// equivalentes aos da tela: status, ministério, intervalo de datas,
  /// presença de regras relaxadas. `relaxedRulesAny` aceita lista de regras —
  /// retorna auditorias que tenham QUALQUER uma delas em `relaxed_rules[]`.
  Future<List<Map<String, dynamic>>> listAudits({
    String? status,
    String? ministryId,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? relaxedRulesAny,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _supabase
        .from('schedule_audit')
        .select(
            '*, event:event_id(name, start_date), ministry:ministry_id(name)')
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    if (status != null) query = query.eq('status', status);
    if (ministryId != null) query = query.eq('ministry_id', ministryId);
    if (relaxedRulesAny != null && relaxedRulesAny.isNotEmpty) {
      // Postgrest sintaxe para "array overlaps" — usa `overlaps` no array col.
      query = query.overlaps('relaxed_rules', relaxedRulesAny);
    }
    final response = await query
        .order('generated_at', ascending: false)
        .range(offset, offset + limit - 1);
    var list = (response as List).cast<Map<String, dynamic>>();
    if (fromDate != null || toDate != null) {
      list = list.where((a) {
        final raw = a['generated_at']?.toString();
        final dt = raw != null ? DateTime.tryParse(raw) : null;
        if (dt == null) return false;
        if (fromDate != null && dt.isBefore(fromDate)) return false;
        if (toDate != null && dt.isAfter(toDate)) return false;
        return true;
      }).toList();
    }
    return list;
  }

  Future<void> markResolved(String pendingId, {String? note}) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase
        .from('schedule_pending')
        .update({
          'status': 'resolved',
          'resolved_by': userId,
          'resolved_at': DateTime.now().toIso8601String(),
          'resolution_note': note,
        })
        .eq('id', pendingId);
  }

  Future<void> markDismissed(String pendingId, {String? note}) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase
        .from('schedule_pending')
        .update({
          'status': 'dismissed',
          'resolved_by': userId,
          'resolved_at': DateTime.now().toIso8601String(),
          'resolution_note': note,
        })
        .eq('id', pendingId);
  }
}
