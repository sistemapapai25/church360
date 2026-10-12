import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/ministry_routine.dart';

/// Erro da Rotina já traduzido para a tela.
class MinistryRoutineException implements Exception {
  final String message;

  const MinistryRoutineException(this.message);

  @override
  String toString() => message;
}

/// O que a pessoa pode na Rotina deste ministério (RPC `ministry_routine_caps`,
/// a mesma régua que a RLS e as RPCs usam).
class MinistryRoutineCaps {
  final bool canView;
  final bool canMark;
  final bool canManage;

  const MinistryRoutineCaps({
    required this.canView,
    required this.canMark,
    required this.canManage,
  });
}

/// Rotina do ministério. O cliente só faz SELECT; toda escrita passa pelas
/// RPCs da migration `20261008004000_ministerio_rotina`.
class MinistryRoutineRepository {
  final SupabaseClient _supabase;

  MinistryRoutineRepository(this._supabase);

  static const _runSelect =
      'id, worship_service_id, leader_of_day, needs_notes, confirmed_at, '
      'worship_service(service_date, service_time), '
      'ministry_routine_check(id, item_id, stage, title, asks_value, '
      'sort_order, done, value_text, responsible_user_id)';

  Future<MinistryRoutineCaps> caps(String ministryId) async {
    final r = await _rpc('ministry_routine_caps', {
      'p_ministry_id': ministryId,
    });
    final m = r is Map ? r : const {};
    return MinistryRoutineCaps(
      canView: m['can_view'] == true,
      canMark: m['can_mark'] == true,
      canManage: m['can_manage'] == true,
    );
  }

  Future<List<RoutineItem>> getItems(String ministryId) async {
    try {
      final rows = await _supabase
          .from('ministry_routine_item')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .order('sort_order');
      return [
        for (final r in rows as List)
          RoutineItem.fromJson(r as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// As rotinas mais recentes, do culto mais novo para o mais antigo.
  Future<List<RoutineRun>> getRuns(String ministryId) async {
    try {
      final rows = await _supabase
          .from('ministry_routine_run')
          .select(_runSelect)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .order('created_at', ascending: false)
          .limit(30);
      final runs = [
        for (final r in rows as List)
          RoutineRun.fromJson(r as Map<String, dynamic>),
      ];
      runs.sort(
        (a, b) => (b.serviceDate ?? DateTime(0)).compareTo(
          a.serviceDate ?? DateTime(0),
        ),
      );
      return runs;
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  Future<RoutineRun> getRun(String runId) async {
    try {
      final row = await _supabase
          .from('ministry_routine_run')
          .select(_runSelect)
          .eq('id', runId)
          .single();
      return RoutineRun.fromJson(row);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Abre (ou devolve) a rotina do culto e alinha os itens com o modelo.
  Future<String> open(String ministryId, String worshipServiceId) async =>
      await _rpc('ministry_routine_open', {
            'p_ministry_id': ministryId,
            'p_worship_service_id': worshipServiceId,
          })
          as String;

  Future<void> setCheck({
    required String checkId,
    required bool done,
    String? valueText,
    String? responsibleUserId,
  }) => _rpc('ministry_routine_check_set', {
    'p_check_id': checkId,
    'p_done': done,
    'p_value_text': valueText,
    'p_responsible_user_id': responsibleUserId,
  });

  Future<void> setRun({
    required String runId,
    String? leaderOfDay,
    String? needsNotes,
  }) => _rpc('ministry_routine_run_set', {
    'p_run_id': runId,
    'p_leader_of_day': leaderOfDay,
    'p_needs_notes': needsNotes,
  });

  Future<void> confirm(String runId) =>
      _rpc('ministry_routine_confirm', {'p_run_id': runId});

  Future<void> reopen(String runId) =>
      _rpc('ministry_routine_reopen', {'p_run_id': runId});

  Future<void> saveItem({
    required String ministryId,
    String? itemId,
    required RoutineStage stage,
    required String title,
    bool asksValue = false,
  }) => _rpc('ministry_routine_item_save', {
    'p_ministry_id': ministryId,
    'p_item_id': itemId,
    'p_stage': stage.value,
    'p_title': title,
    'p_asks_value': asksValue,
  });

  Future<void> deleteItem(String itemId) =>
      _rpc('ministry_routine_item_delete', {'p_item_id': itemId});

  Future<void> reorder(
    String ministryId,
    RoutineStage stage,
    List<String> ids,
  ) => _rpc('ministry_routine_item_reorder', {
    'p_ministry_id': ministryId,
    'p_stage': stage.value,
    'p_ids': ids,
  });

  /// Acrescenta os itens da Ficha 3 do Diaconato que ainda faltam. Devolve
  /// quantos entraram.
  Future<int> useTemplate(String ministryId) async =>
      ((await _rpc('ministry_routine_use_template', {
                'p_ministry_id': ministryId,
              }))
              as num)
          .toInt();

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  MinistryRoutineException _traduzir(PostgrestException e) {
    switch (e.code) {
      case '28000':
        return const MinistryRoutineException(
          'Sua sessão expirou. Entre de novo.',
        );
      case '42501':
        return MinistryRoutineException(
          e.message.contains('row-level') || e.message.contains('permission')
              ? 'Você não tem permissão para esta ação na rotina.'
              : _acentuar(e.message),
        );
      case 'P0002':
        return MinistryRoutineException(
          '${_acentuar(e.message)} Atualize a tela.',
        );
    }
    return MinistryRoutineException(_acentuar(e.message));
  }

  static const _acentos = {
    'Nao autenticado': 'Não autenticado',
    'So o lider do ministerio': 'Só o líder do ministério',
    'So o lider do dia ou o lider do ministerio':
        'Só o líder do dia ou o líder do ministério',
    'So quem e da equipe': 'Só quem é da equipe',
    'Etapa invalida': 'Etapa inválida',
    'nao encontrad': 'não encontrad',
    'esta desligada neste ministerio': 'está desligada neste ministério',
    'ja confirmada; so o lider': 'já confirmada; só o líder',
    'responsavel': 'responsável',
    'lider do dia': 'líder do dia',
  };

  String _acentuar(String s) {
    var out = s;
    _acentos.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
