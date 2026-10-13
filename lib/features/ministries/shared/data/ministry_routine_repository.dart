import 'package:image_picker/image_picker.dart';
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

  /// A aba Pedidos está ligada (a Rotina mostra "Abrir pedido").
  final bool requestsOn;

  /// A Rotina mostra a entrega das ofertas à Tesouraria (Diaconato).
  final bool offeringOn;

  const MinistryRoutineCaps({
    required this.canView,
    required this.canMark,
    required this.canManage,
    this.requestsOn = false,
    this.offeringOn = false,
  });
}

/// Rotina do ministério. O cliente só faz SELECT; toda escrita passa pelas
/// RPCs da migration `20261008004000_ministerio_rotina`.
class MinistryRoutineRepository {
  final SupabaseClient _supabase;

  MinistryRoutineRepository(this._supabase);

  static const _runSelect =
      'id, event_id, leader_of_day, needs_notes, confirmed_at, '
      'event(name, start_date), '
      'ministry_routine_check(id, item_id, stage, title, asks_value, '
      'sort_order, done, value_text, responsible_user_id, validated_at), '
      'ministry_offering_delivery(id, envelopes, cash_amount, delivered_by_1, '
      'delivered_by_2, received_by, notes, received_confirmed_at)';

  static const _photoBucket = 'ministry-request-photos';

  Future<MinistryRoutineCaps> caps(String ministryId) async {
    final r = await _rpc('ministry_routine_caps', {
      'p_ministry_id': ministryId,
    });
    final m = r is Map ? r : const {};
    return MinistryRoutineCaps(
      canView: m['can_view'] == true,
      canMark: m['can_mark'] == true,
      canManage: m['can_manage'] == true,
      requestsOn: m['requests_on'] == true,
      offeringOn: m['offering_on'] == true,
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

  /// Cultos da Agenda (event_type `culto%`) das próximas 2 semanas e dos
  /// últimos 2 meses, o mais novo primeiro. `start_date` é hora de parede
  /// rotulada UTC.
  Future<List<RoutineCulto>> cultos() async {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    try {
      final rows = await _supabase
          .from('event')
          .select('id, name, start_date')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .like('event_type', 'culto%')
          .gte(
            'start_date',
            today.subtract(const Duration(days: 60)).toIso8601String(),
          )
          .lt(
            'start_date',
            today.add(const Duration(days: 15)).toIso8601String(),
          )
          .order('start_date', ascending: false);
      return [
        for (final r in rows as List)
          RoutineCulto.fromJson(r as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Abre (ou devolve) a rotina do culto e alinha os itens com o modelo.
  Future<String> open(String ministryId, String eventId) async =>
      await _rpc('ministry_routine_open', {
            'p_ministry_id': ministryId,
            'p_event_id': eventId,
          })
          as String;

  /// O líder do dia (ou do ministério) confere o item feito.
  Future<void> validateCheck(String checkId, bool valid) => _rpc(
    'ministry_routine_check_validate',
    {'p_check_id': checkId, 'p_valid': valid},
  );

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

  /// Quem da Equipe está escalado num evento do ministério no dia do culto:
  /// `user_account.id` -> função (ou null).
  Future<Map<String, String?>> scheduled(String runId) async {
    final rows = await _rpc('ministry_routine_scheduled', {'p_run_id': runId});
    return {
      for (final r in (rows as List? ?? const []))
        (r as Map)['user_account_id'] as String: r['function_name'] as String?,
    };
  }

  /// Quem pode receber as ofertas (a Tesouraria): `user_account.id` -> nome.
  Future<Map<String, String>> offeringReceivers() async {
    final rows = await _rpc('ministry_offering_receivers', const {});
    return {
      for (final r in (rows as List? ?? const []))
        (r as Map)['id'] as String: r['name'] as String? ?? '',
    };
  }

  Future<void> setOffering({
    required String runId,
    int? envelopes,
    double? cashAmount,
    String? deliveredBy1,
    String? deliveredBy2,
    String? receivedBy,
    String? notes,
  }) => _rpc('ministry_offering_set', {
    'p_run_id': runId,
    'p_envelopes': envelopes,
    'p_cash_amount': cashAmount,
    'p_delivered_by_1': deliveredBy1,
    'p_delivered_by_2': deliveredBy2,
    'p_received_by': receivedBy,
    'p_notes': notes,
  });

  /// A entrega como a Tesouraria vê (nomes prontos). Null: não achou ou não
  /// pode ver.
  Future<Map<String, dynamic>?> getOffering(String deliveryId) async {
    final r = await _rpc('ministry_offering_get', {
      'p_delivery_id': deliveryId,
    });
    return r is Map ? r.cast<String, dynamic>() : null;
  }

  Future<void> confirmOffering(String deliveryId) =>
      _rpc('ministry_offering_confirm', {'p_delivery_id': deliveryId});

  /// Sobe a foto do pedido na pasta do ministério e devolve o caminho.
  Future<String> uploadRequestPhoto(String ministryId, XFile file) async {
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = '$ministryId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _supabase.storage
          .from(_photoBucket)
          .uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
      return path;
    } on StorageException catch (e) {
      throw MinistryRoutineException(
        e.statusCode == '403'
            ? 'Só quem é da equipe envia foto.'
            : 'Não deu para enviar a foto: ${e.message}',
      );
    }
  }

  /// Link temporário (10 min) para ver a foto do pedido.
  Future<String> requestPhotoUrl(String path) =>
      _supabase.storage.from(_photoBucket).createSignedUrl(path, 600);

  /// Pedidos do ministério, os mais novos primeiro.
  Future<List<MinistryRequest>> getRequests(String ministryId) async {
    try {
      final rows = await _supabase
          .from('ministry_request')
          .select('*, ministry_stock_item(name), event(start_date)')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .order('opened_at', ascending: false)
          .limit(200);
      return [
        for (final r in rows as List)
          MinistryRequest.fromJson(r as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  Future<void> openRequest({
    required String ministryId,
    required String title,
    required RequestKind kind,
    String? location,
    String? details,
    String? eventId,
    String? stockItemId,
    String? photoPath,
  }) => _rpc('ministry_request_open', {
    'p_ministry_id': ministryId,
    'p_title': title,
    'p_kind': kind.value,
    'p_location': location,
    'p_details': details,
    'p_event_id': eventId,
    'p_stock_item_id': stockItemId,
    'p_photo_path': photoPath,
  });

  Future<void> setRequestStatus(
    String requestId,
    RequestStatus status, {
    String? note,
  }) => _rpc('ministry_request_set_status', {
    'p_request_id': requestId,
    'p_status': status.value,
    'p_note': note,
  });

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
    'So da para validar': 'Só dá para validar',
    'muda a situacao': 'muda a situação',
    'Situacao invalida': 'Situação inválida',
    'Tipo de pedido invalido': 'Tipo de pedido inválido',
    'neste ministerio': 'neste ministério',
    'Etapa invalida': 'Etapa inválida',
    'nao encontrad': 'não encontrad',
    'esta desligada neste ministerio': 'está desligada neste ministério',
    'ja confirmada; so o lider': 'já confirmada; só o líder',
    'responsavel': 'responsável',
    'lider do dia': 'líder do dia',
    'Tesouraria ja confirmou o recebimento; a entrega nao muda mais':
        'Tesouraria já confirmou o recebimento; a entrega não muda mais',
    'Quantidade de envelopes invalida': 'Quantidade de envelopes inválida',
    'em especie nao pode': 'em espécie não pode',
    'A entrega e feita': 'A entrega é feita',
    'A observacao': 'A observação',
    'So quem recebeu': 'Só quem recebeu',
    'Foto de outro ministerio': 'Foto de outro ministério',
  };

  String _acentuar(String s) {
    var out = s;
    _acentos.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
