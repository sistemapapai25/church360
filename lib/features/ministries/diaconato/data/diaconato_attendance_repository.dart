import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/models/communion_delivery.dart';
import '../domain/models/diaconato_dashboard_stats.dart';
import '../domain/models/worship_attendance.dart';

/// Repository do checklist de presença do Diaconato.
///
/// Lê e escreve em `worship_attendance_count` + `worship_attendance_person`
/// (migration `20260515000000`). Não toca em `worship_attendance` — esta
/// segue como check-in voluntário.
class DiaconatoAttendanceRepository {
  final SupabaseClient _supabase;

  DiaconatoAttendanceRepository(this._supabase);

  String get _tenantId => SupabaseConstants.currentTenantId;

  // =====================================================
  // Cargas de leitura
  // =====================================================

  /// Recupera (ou cria) a contagem oficial para `(worship_service, ministry)`.
  ///
  /// Como há `UNIQUE(worship_service_id, ministry_id)` na tabela, qualquer
  /// par sempre tem no máximo uma linha. Se ainda não existir, insere com
  /// totais zerados e `counted_by` resolvido a partir do usuário logado.
  Future<WorshipAttendanceCount> getOrCreateAttendanceCount({
    required String worshipServiceId,
    required String ministryId,
  }) async {
    final existing = await _supabase
        .from('worship_attendance_count')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('worship_service_id', worshipServiceId)
        .eq('ministry_id', ministryId)
        .maybeSingle();

    if (existing != null) {
      return WorshipAttendanceCount.fromJson(existing);
    }

    final ws = await _supabase
        .from('worship_service')
        .select('service_date')
        .eq('id', worshipServiceId)
        .eq('tenant_id', _tenantId)
        .single();
    final serviceDate = ws['service_date'] as String;

    final countedByUserAccountId = await _resolveCurrentUserAccountId();

    final payload = <String, dynamic>{
      'tenant_id': _tenantId,
      'worship_service_id': worshipServiceId,
      'ministry_id': ministryId,
      'service_date': serviceDate,
      if (countedByUserAccountId != null) 'counted_by': countedByUserAccountId,
    };

    final inserted = await _supabase
        .from('worship_attendance_count')
        .insert(payload)
        .select()
        .single();

    return WorshipAttendanceCount.fromJson(inserted);
  }

  /// Marcações individuais já registradas para uma contagem.
  Future<List<WorshipAttendancePerson>> getPersonRows(
    String attendanceCountId,
  ) async {
    final response = await _supabase
        .from('worship_attendance_person')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('attendance_count_id', attendanceCountId);

    return (response as List)
        .map((j) =>
            WorshipAttendancePerson.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Pessoas elegíveis para aparecer no checklist: membros ativos +
  /// visitantes/novos convertidos já cadastrados em `user_account`.
  Future<List<DiaconatoEligiblePerson>> getEligiblePeople() async {
    final response = await _supabase
        .from('user_account')
        .select('id, first_name, last_name, photo_url, status')
        .eq('tenant_id', _tenantId)
        .inFilter('status', const ['member_active', 'visitor', 'new_convert'])
        .order('first_name', ascending: true);

    return (response as List)
        .map((j) => DiaconatoEligiblePerson.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // =====================================================
  // Save do checklist (MD.2)
  // =====================================================

  /// Atualiza o estado do checklist para uma contagem:
  ///
  /// - Para cada pessoa em `presentByUser` (chave = userId, valor = tipo
  ///   snapshotado), faz upsert com `present = true` e `absent_action = 'none'`.
  /// - Para pessoas que **estavam** marcadas presentes na DB mas não estão
  ///   mais em `presentByUser`, remove a linha **se** o `absent_action` atual
  ///   é `none` (preserva triagens já feitas pela aba Ausentes do MD.3).
  /// - Atualiza os totais e `total_unregistered_visitors` da contagem.
  ///
  /// Não toca em linhas com `present = false` e `absent_action != 'none'`
  /// (essas só serão criadas/editadas na aba Ausentes).
  Future<WorshipAttendanceCount> saveChecklist({
    required String attendanceCountId,
    required Map<String, DiaconatoPersonType> presentByUser,
    required int totalUnregisteredVisitors,
    String? notes,
  }) async {
    final existing = await getPersonRows(attendanceCountId);
    final desiredUserIds = presentByUser.keys.toSet();

    // Toggle off: estava presente, não está mais marcado.
    for (final row in existing) {
      if (!row.present) continue;
      if (desiredUserIds.contains(row.userId)) continue;
      if (row.absentAction == DiaconatoAbsentAction.none) {
        await _supabase
            .from('worship_attendance_person')
            .delete()
            .eq('id', row.id)
            .eq('tenant_id', _tenantId);
      } else {
        await _supabase
            .from('worship_attendance_person')
            .update({'present': false})
            .eq('id', row.id)
            .eq('tenant_id', _tenantId);
      }
    }

    // Upsert dos presentes.
    if (desiredUserIds.isNotEmpty) {
      final payload = desiredUserIds
          .map((userId) => <String, dynamic>{
                'tenant_id': _tenantId,
                'attendance_count_id': attendanceCountId,
                'user_id': userId,
                'person_type': presentByUser[userId]!.value,
                'present': true,
                'absent_action': DiaconatoAbsentAction.none.value,
              })
          .toList();
      await _supabase
          .from('worship_attendance_person')
          .upsert(payload, onConflict: 'attendance_count_id,user_id');
    }

    // Atualiza os totais da contagem.
    final totalMembers = presentByUser.values
        .where((t) => t == DiaconatoPersonType.member)
        .length;
    final totalVisitors = presentByUser.values
        .where((t) => t == DiaconatoPersonType.visitor)
        .length;

    final updatePayload = <String, dynamic>{
      'total_members_present': totalMembers,
      'total_registered_visitors_present': totalVisitors,
      'total_unregistered_visitors': totalUnregisteredVisitors,
      if (notes != null) 'notes': notes,
    };

    final updated = await _supabase
        .from('worship_attendance_count')
        .update(updatePayload)
        .eq('id', attendanceCountId)
        .eq('tenant_id', _tenantId)
        .select()
        .single();

    return WorshipAttendanceCount.fromJson(updated);
  }

  /// Persiste triagem de ausentes feita pela aba Ausentes (MD.3).
  ///
  /// Para cada `(userId, action, personType)` modificado:
  /// - `action == none`: se existir uma linha com `present = false`, deleta
  ///   (equivalente a "nenhuma triagem registrada"). Não toca em linhas
  ///   `present = true` para não bagunçar o checklist.
  /// - `action != none`: faz upsert com `present = false` e o
  ///   `absent_action` escolhido.
  ///
  /// Não atualiza os totais da contagem — triagem mexe só na coluna
  /// `absent_action` de linhas já marcadas como ausentes; `total_*_present`
  /// continuam sendo derivados pelo checklist (MD.2).
  Future<void> saveAbsenteeTriage({
    required String attendanceCountId,
    required Map<String, AbsenteeTriage> triageByUser,
  }) async {
    if (triageByUser.isEmpty) return;

    final existing = await getPersonRows(attendanceCountId);
    final existingByUser = {for (final r in existing) r.userId: r};

    final upserts = <Map<String, dynamic>>[];

    for (final entry in triageByUser.entries) {
      final userId = entry.key;
      final triage = entry.value;
      final existingRow = existingByUser[userId];

      if (triage.action == DiaconatoAbsentAction.none) {
        if (existingRow != null && !existingRow.present) {
          await _supabase
              .from('worship_attendance_person')
              .delete()
              .eq('id', existingRow.id)
              .eq('tenant_id', _tenantId);
        }
        // Se existingRow.present == true, não mexemos: pessoa está marcada como
        // presente pelo checklist, MD.3 não sobrescreve.
        continue;
      }

      // Pula se a pessoa está marcada como presente — triagem só faz sentido
      // para ausentes.
      if (existingRow != null && existingRow.present) continue;

      upserts.add({
        'tenant_id': _tenantId,
        'attendance_count_id': attendanceCountId,
        'user_id': userId,
        'person_type': triage.personType.value,
        'present': false,
        'absent_action': triage.action.value,
      });
    }

    if (upserts.isNotEmpty) {
      await _supabase
          .from('worship_attendance_person')
          .upsert(upserts, onConflict: 'attendance_count_id,user_id');
    }
  }

  // =====================================================
  // Lotes de ceia (MD.4)
  // =====================================================

  /// Recupera (ou cria) o lote de ceia para `(ministry, attendance_count)`.
  /// Idempotente — `UNIQUE(ministry_id, attendance_count_id)` na tabela.
  Future<CommunionDeliveryBatch> getOrCreateCommunionBatch({
    required String ministryId,
    required String attendanceCountId,
  }) async {
    final existing = await _supabase
        .from('communion_delivery_batch')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('ministry_id', ministryId)
        .eq('attendance_count_id', attendanceCountId)
        .maybeSingle();
    if (existing != null) {
      return CommunionDeliveryBatch.fromJson(existing);
    }

    final count = await _supabase
        .from('worship_attendance_count')
        .select('service_date')
        .eq('id', attendanceCountId)
        .eq('tenant_id', _tenantId)
        .single();
    final serviceDate = count['service_date'] as String;

    final createdBy = await _resolveCurrentUserAccountId();

    final payload = <String, dynamic>{
      'tenant_id': _tenantId,
      'ministry_id': ministryId,
      'attendance_count_id': attendanceCountId,
      'service_date': serviceDate,
      if (createdBy != null) 'created_by': createdBy,
    };

    final inserted = await _supabase
        .from('communion_delivery_batch')
        .insert(payload)
        .select()
        .single();

    return CommunionDeliveryBatch.fromJson(inserted);
  }

  /// Reconstrói os items do lote a partir das triagens com
  /// `absent_action IN ('communion', 'call_and_communion')` em
  /// `worship_attendance_person` para a contagem do lote.
  ///
  /// **Idempotente + preserva progresso:**
  /// - Pessoas já triadas: upsert mantendo `assigned_to`/`status` se item já
  ///   existe (não rebaixa um `delivered` para `pending`).
  /// - Pessoas não mais triadas:
  ///   - Se item está `pending` → deleta (sem progresso, sem perda).
  ///   - Em outros status (`assigned`/`delivered`/`not_found`/`cancelled`) →
  ///     mantém (já tem histórico; remover destruiria registro de entrega).
  Future<List<CommunionDeliveryItem>> rebuildBatchItemsFromTriage({
    required String batchId,
    required String attendanceCountId,
  }) async {
    final triagedResp = await _supabase
        .from('worship_attendance_person')
        .select('user_id, absent_action')
        .eq('tenant_id', _tenantId)
        .eq('attendance_count_id', attendanceCountId)
        .eq('present', false)
        .inFilter('absent_action', const ['communion', 'call_and_communion']);

    final triagedRows = (triagedResp as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final triagedByUser = <String, String>{
      for (final r in triagedRows)
        (r['user_id'] as String): (r['absent_action'] as String),
    };
    final triagedUserIds = triagedByUser.keys.toSet();

    final existingResp = await _supabase
        .from('communion_delivery_item')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('batch_id', batchId);
    final existing = (existingResp as List)
        .map((j) => CommunionDeliveryItem.fromJson(j as Map<String, dynamic>))
        .toList();
    final existingByUser = {for (final i in existing) i.userId: i};

    // Upserts dos triados (preserva progresso quando item já existe).
    if (triagedByUser.isNotEmpty) {
      final upserts = triagedByUser.entries.map((e) {
        final existingItem = existingByUser[e.key];
        final payload = <String, dynamic>{
          'tenant_id': _tenantId,
          'batch_id': batchId,
          'user_id': e.key,
          'reason': e.value,
        };
        if (existingItem != null) {
          payload['status'] = existingItem.status.value;
          if (existingItem.assignedTo != null) {
            payload['assigned_to'] = existingItem.assignedTo;
          }
        }
        return payload;
      }).toList();
      await _supabase
          .from('communion_delivery_item')
          .upsert(upserts, onConflict: 'batch_id,user_id');
    }

    // Remove items que deixaram de ser triados E ainda estão pending.
    for (final item in existing) {
      if (triagedUserIds.contains(item.userId)) continue;
      if (item.status == CommunionDeliveryStatus.pending) {
        await _supabase
            .from('communion_delivery_item')
            .delete()
            .eq('id', item.id)
            .eq('tenant_id', _tenantId);
      }
      // Items com progresso (assigned/delivered/not_found/cancelled)
      // são preservados — não destruir histórico.
    }

    return getBatchItems(batchId);
  }

  /// Lotes abertos de um ministério (mais recentes primeiro).
  Future<List<CommunionDeliveryBatch>> getOpenBatchesForMinistry(
    String ministryId,
  ) async {
    final response = await _supabase
        .from('communion_delivery_batch')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('ministry_id', ministryId)
        .eq('status', 'open')
        .order('service_date', ascending: false);
    return (response as List)
        .map((j) =>
            CommunionDeliveryBatch.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Items de um lote, do mais antigo para o mais recente.
  Future<List<CommunionDeliveryItem>> getBatchItems(String batchId) async {
    final response = await _supabase
        .from('communion_delivery_item')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('batch_id', batchId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((j) =>
            CommunionDeliveryItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Atribui (ou desatribui, com `assignedTo = null`) o responsável de um item.
  /// Ajusta `status` para `assigned` (se atribuir) ou `pending` (se desatribuir),
  /// **desde que o item ainda não esteja em estado terminal** (delivered/
  /// cancelled/not_found). Em estados terminais, só atualiza `assigned_to`.
  Future<CommunionDeliveryItem> updateItemAssignment({
    required String itemId,
    required String? assignedTo,
  }) async {
    final current = await _supabase
        .from('communion_delivery_item')
        .select('status')
        .eq('id', itemId)
        .eq('tenant_id', _tenantId)
        .single();
    final currentStatus =
        CommunionDeliveryStatus.fromValue(current['status'] as String);
    final isTerminal = currentStatus == CommunionDeliveryStatus.delivered ||
        currentStatus == CommunionDeliveryStatus.cancelled ||
        currentStatus == CommunionDeliveryStatus.notFound;

    final payload = <String, dynamic>{'assigned_to': assignedTo};
    if (!isTerminal) {
      payload['status'] = assignedTo == null
          ? CommunionDeliveryStatus.pending.value
          : CommunionDeliveryStatus.assigned.value;
    }

    final updated = await _supabase
        .from('communion_delivery_item')
        .update(payload)
        .eq('id', itemId)
        .eq('tenant_id', _tenantId)
        .select()
        .single();
    return CommunionDeliveryItem.fromJson(updated);
  }

  /// Atualiza o status de um item. Se `delivered`, preenche `delivered_at`;
  /// senão, limpa.
  Future<CommunionDeliveryItem> updateItemStatus({
    required String itemId,
    required CommunionDeliveryStatus status,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'status': status.value,
      'delivered_at': status == CommunionDeliveryStatus.delivered
          ? DateTime.now().toIso8601String()
          : null,
      if (notes != null) 'notes': notes,
    };

    final updated = await _supabase
        .from('communion_delivery_item')
        .update(payload)
        .eq('id', itemId)
        .eq('tenant_id', _tenantId)
        .select()
        .single();
    return CommunionDeliveryItem.fromJson(updated);
  }

  /// Marca o lote como fechado (`status = 'closed'`, `closed_at = now()`).
  /// Não muda items — apenas sinaliza no nível do lote que processo terminou.
  Future<CommunionDeliveryBatch> closeBatch(String batchId) async {
    final updated = await _supabase
        .from('communion_delivery_batch')
        .update({
          'status': CommunionBatchStatus.closed.value,
          'closed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', batchId)
        .eq('tenant_id', _tenantId)
        .select()
        .single();
    return CommunionDeliveryBatch.fromJson(updated);
  }

  /// Dispara a RPC server-side que cria notificações in-app para items
  /// atribuídos em lotes abertos. Idempotente via `reminder_app_sent_at`.
  /// Retorna a quantidade de notificações criadas nesta chamada.
  ///
  /// Falha silenciosa para responsáveis sem `auth_user_id` — eles serão
  /// notificados quando vincularem uma conta auth.
  Future<int> dispatchCommunionAssignments() async {
    final response =
        await _supabase.rpc('diaconato_dispatch_communion_assignments');
    if (response is int) return response;
    if (response is num) return response.toInt();
    return 0;
  }

  /// Reabre um lote fechado (status volta para `open`, `closed_at` zerado).
  Future<CommunionDeliveryBatch> reopenBatch(String batchId) async {
    final updated = await _supabase
        .from('communion_delivery_batch')
        .update({
          'status': CommunionBatchStatus.open.value,
          'closed_at': null,
        })
        .eq('id', batchId)
        .eq('tenant_id', _tenantId)
        .select()
        .single();
    return CommunionDeliveryBatch.fromJson(updated);
  }

  // =====================================================
  // Dashboard do Diaconato
  // =====================================================

  /// KPIs do dashboard do Diaconato para o ministério dado.
  ///
  /// Roda em duas fases paralelas (mesma postura do `RaizesRepository.getDashboardStats`):
  /// 1. Em paralelo: último count, eligible count, lotes abertos, 30d não-cadastrados.
  /// 2. Em paralelo (dependendo da fase 1): triagem pendente, items abertos
  ///    (em batches abertos), items atribuídos a mim.
  Future<DiaconatoDashboardStats> getDashboardStats(String ministryId) async {
    final tenantId = _tenantId;
    final today = DateTime.now();
    final thirtyDaysAgoIso = _isoDate(
      today.subtract(const Duration(days: 30)),
    );

    final phase1 = await Future.wait([
      _fetchLastCount(tenantId, ministryId),
      _countEligible(tenantId),
      _fetchOpenBatchIds(tenantId, ministryId),
      _sumUnregisteredVisitorsSince(tenantId, ministryId, thirtyDaysAgoIso),
      _resolveCurrentUserAccountId(),
    ]);
    final lastCount = phase1[0] as WorshipAttendanceCount?;
    final eligibleCount = phase1[1] as int;
    final openBatchIds = phase1[2] as List<String>;
    final unregistered30d = phase1[3] as int;
    final myUserAccountId = phase1[4] as String?;

    final phase2 = await Future.wait([
      lastCount == null
          ? Future.value(0)
          : _countMarkedPersons(tenantId, lastCount.id),
      openBatchIds.isEmpty
          ? Future.value(0)
          : _countOpenItems(tenantId, openBatchIds),
      (openBatchIds.isEmpty || myUserAccountId == null)
          ? Future.value(0)
          : _countMyOpenItems(tenantId, openBatchIds, myUserAccountId),
    ]);
    final markedCount = phase2[0];
    final openItems = phase2[1];
    final myAssigned = phase2[2];

    final pending = lastCount == null
        ? 0
        : (eligibleCount - markedCount).clamp(0, eligibleCount);

    return DiaconatoDashboardStats(
      lastCount: lastCount,
      pendingTriageInLastCount: pending,
      openCommunionItems: openItems,
      myAssignedItems: myAssigned,
      unregisteredVisitorsLast30Days: unregistered30d,
      openBatchesCount: openBatchIds.length,
    );
  }

  Future<WorshipAttendanceCount?> _fetchLastCount(
    String tenantId,
    String ministryId,
  ) async {
    final response = await _supabase
        .from('worship_attendance_count')
        .select()
        .eq('tenant_id', tenantId)
        .eq('ministry_id', ministryId)
        .order('service_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return WorshipAttendanceCount.fromJson(response);
  }

  Future<int> _countEligible(String tenantId) async {
    final response = await _supabase
        .from('user_account')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('status', const ['member_active', 'visitor', 'new_convert'])
        .count(CountOption.exact);
    return response.count;
  }

  Future<List<String>> _fetchOpenBatchIds(
    String tenantId,
    String ministryId,
  ) async {
    final response = await _supabase
        .from('communion_delivery_batch')
        .select('id')
        .eq('tenant_id', tenantId)
        .eq('ministry_id', ministryId)
        .eq('status', CommunionBatchStatus.open.value);
    return (response as List)
        .map((b) => (b as Map)['id'] as String)
        .toList();
  }

  Future<int> _sumUnregisteredVisitorsSince(
    String tenantId,
    String ministryId,
    String isoDateInclusive,
  ) async {
    final response = await _supabase
        .from('worship_attendance_count')
        .select('total_unregistered_visitors')
        .eq('tenant_id', tenantId)
        .eq('ministry_id', ministryId)
        .gte('service_date', isoDateInclusive);
    return (response as List).fold<int>(0, (sum, row) {
      final v = (row as Map)['total_unregistered_visitors'];
      return sum + ((v as num?)?.toInt() ?? 0);
    });
  }

  Future<int> _countMarkedPersons(
    String tenantId,
    String attendanceCountId,
  ) async {
    final response = await _supabase
        .from('worship_attendance_person')
        .select()
        .eq('tenant_id', tenantId)
        .eq('attendance_count_id', attendanceCountId)
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countOpenItems(
    String tenantId,
    List<String> openBatchIds,
  ) async {
    final response = await _supabase
        .from('communion_delivery_item')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('batch_id', openBatchIds)
        .inFilter('status', const ['pending', 'assigned'])
        .count(CountOption.exact);
    return response.count;
  }

  Future<int> _countMyOpenItems(
    String tenantId,
    List<String> openBatchIds,
    String myUserAccountId,
  ) async {
    final response = await _supabase
        .from('communion_delivery_item')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('batch_id', openBatchIds)
        .inFilter('status', const ['pending', 'assigned'])
        .eq('assigned_to', myUserAccountId)
        .count(CountOption.exact);
    return response.count;
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // =====================================================
  // Helpers privados
  // =====================================================

  Future<String?> _resolveCurrentUserAccountId() async {
    final currentAuthId = _supabase.auth.currentUser?.id;
    if (currentAuthId == null) return null;
    final me = await _supabase
        .from('user_account')
        .select('id')
        .eq('auth_user_id', currentAuthId)
        .eq('tenant_id', _tenantId)
        .maybeSingle();
    return me?['id'] as String?;
  }
}
