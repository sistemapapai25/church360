// Aba Rotina (F3 de ROADMAP-2026-10-12-MINISTERIO-PROCESSOS): o checklist
// pré, durante e pós-culto de um ministério. Tabelas e RPCs na migration
// 20261008004000_ministerio_rotina.

import 'package:intl/intl.dart';

/// As três etapas, na ordem da Ficha 3 do Diaconato.
enum RoutineStage {
  pre('pre', 'Pré-culto'),
  durante('durante', 'Durante o culto'),
  pos('pos', 'Pós-culto');

  final String value;
  final String label;

  const RoutineStage(this.value, this.label);

  static RoutineStage fromValue(String? v) =>
      values.firstWhere((s) => s.value == v, orElse: () => pre);
}

/// Item do modelo que o líder configura.
class RoutineItem {
  final String id;
  final RoutineStage stage;
  final String title;
  final bool asksValue;
  final int sortOrder;

  const RoutineItem({
    required this.id,
    required this.stage,
    required this.title,
    required this.asksValue,
    required this.sortOrder,
  });

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
    id: j['id'] as String,
    stage: RoutineStage.fromValue(j['stage'] as String?),
    title: j['title'] as String? ?? '',
    asksValue: j['asks_value'] as bool? ?? false,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
  );
}

/// Item da rotina de um culto. O título é cópia do momento em que a rotina
/// abriu: editar o modelo depois não muda o histórico.
class RoutineCheck {
  final String id;
  final String? itemId;
  final RoutineStage stage;
  final String title;
  final bool asksValue;
  final int sortOrder;
  final bool done;
  final String? valueText;

  /// `user_account.id` de alguém da Equipe.
  final String? responsibleUserId;

  const RoutineCheck({
    required this.id,
    this.itemId,
    required this.stage,
    required this.title,
    required this.asksValue,
    required this.sortOrder,
    required this.done,
    this.valueText,
    this.responsibleUserId,
  });

  factory RoutineCheck.fromJson(Map<String, dynamic> j) => RoutineCheck(
    id: j['id'] as String,
    itemId: j['item_id'] as String?,
    stage: RoutineStage.fromValue(j['stage'] as String?),
    title: j['title'] as String? ?? '',
    asksValue: j['asks_value'] as bool? ?? false,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    done: j['done'] as bool? ?? false,
    valueText: j['value_text'] as String?,
    responsibleUserId: j['responsible_user_id'] as String?,
  );
}

/// A rotina de um culto, com os itens.
class RoutineRun {
  final String id;
  final String worshipServiceId;
  final DateTime? serviceDate;
  final String? serviceTime;

  /// `user_account.id` do líder do dia.
  final String? leaderOfDay;
  final String? needsNotes;
  final DateTime? confirmedAt;
  final List<RoutineCheck> checks;

  /// Entrega das ofertas à Tesouraria (F5); nula enquanto ninguém preencheu.
  final OfferingDelivery? offering;

  const RoutineRun({
    required this.id,
    required this.worshipServiceId,
    this.serviceDate,
    this.serviceTime,
    this.leaderOfDay,
    this.needsNotes,
    this.confirmedAt,
    this.checks = const [],
    this.offering,
  });

  bool get confirmed => confirmedAt != null;
  int get doneCount => checks.where((c) => c.done).length;

  factory RoutineRun.fromJson(Map<String, dynamic> j) {
    final ws = j['worship_service'];
    final date = ws is Map ? ws['service_date'] as String? : null;
    final checks = [
      for (final c in (j['ministry_routine_check'] as List? ?? const []))
        RoutineCheck.fromJson(c as Map<String, dynamic>),
    ]..sort(compareRoutineChecks);
    // 1:1 pela run_id única: o PostgREST devolve objeto (ou lista, conforme
    // a versão); aceitar os dois.
    final off = j['ministry_offering_delivery'];
    final offMap = off is List ? (off.isEmpty ? null : off.first) : off;
    return RoutineRun(
      id: j['id'] as String,
      worshipServiceId: j['worship_service_id'] as String,
      serviceDate: date == null ? null : DateTime.tryParse(date),
      serviceTime: ws is Map ? ws['service_time'] as String? : null,
      leaderOfDay: j['leader_of_day'] as String?,
      needsNotes: j['needs_notes'] as String?,
      confirmedAt: DateTime.tryParse(
        j['confirmed_at'] as String? ?? '',
      )?.toLocal(),
      checks: checks,
      offering: offMap is Map
          ? OfferingDelivery.fromJson(offMap.cast<String, dynamic>())
          : null,
    );
  }
}

/// Entrega das ofertas do culto à Tesouraria (migration 004200). Os ids de
/// pessoa são `user_account.id`.
class OfferingDelivery {
  final String id;
  final int? envelopes;
  final double? cashAmount;
  final String? deliveredBy1;
  final String? deliveredBy2;
  final String? receivedBy;
  final String? notes;
  final DateTime? receivedConfirmedAt;

  const OfferingDelivery({
    required this.id,
    this.envelopes,
    this.cashAmount,
    this.deliveredBy1,
    this.deliveredBy2,
    this.receivedBy,
    this.notes,
    this.receivedConfirmedAt,
  });

  bool get received => receivedConfirmedAt != null;

  factory OfferingDelivery.fromJson(Map<String, dynamic> j) => OfferingDelivery(
    id: j['id'] as String,
    envelopes: (j['envelopes'] as num?)?.toInt(),
    cashAmount: (j['cash_amount'] as num?)?.toDouble(),
    deliveredBy1: j['delivered_by_1'] as String?,
    deliveredBy2: j['delivered_by_2'] as String?,
    receivedBy: j['received_by'] as String?,
    notes: j['notes'] as String?,
    receivedConfirmedAt: DateTime.tryParse(
      j['received_confirmed_at'] as String? ?? '',
    )?.toLocal(),
  );
}

/// "R\$ 1.234,50" (ou "—" sem valor).
String formatReais(double? v) => v == null
    ? '—'
    : NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(v);

int compareRoutineChecks(RoutineCheck a, RoutineCheck b) {
  final byStage = a.stage.index.compareTo(b.stage.index);
  return byStage != 0 ? byStage : a.sortOrder.compareTo(b.sortOrder);
}

/// Os itens que mais ficaram sem fazer nas rotinas confirmadas, do pior para
/// o melhor: (título, vezes sem fazer, vezes que apareceu).
List<(String, int, int)> mostMissedRoutineItems(
  List<RoutineRun> runs, {
  int limit = 5,
}) {
  final missed = <String, int>{};
  final seen = <String, int>{};
  for (final r in runs.where((r) => r.confirmed)) {
    for (final c in r.checks) {
      seen[c.title] = (seen[c.title] ?? 0) + 1;
      if (!c.done) missed[c.title] = (missed[c.title] ?? 0) + 1;
    }
  }
  final out = [for (final e in missed.entries) (e.key, e.value, seen[e.key]!)]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return out.take(limit).toList();
}

// ---------------------------------------------------------------------------
// Aba Pedidos (F4, migration 20261008004100_ministerio_pedidos).

enum RequestKind {
  conserto('conserto', 'Conserto'),
  reposicao('reposicao', 'Reposição'),
  outro('outro', 'Outro');

  final String value;
  final String label;

  const RequestKind(this.value, this.label);

  static RequestKind fromValue(String? v) =>
      values.firstWhere((k) => k.value == v, orElse: () => outro);
}

enum RequestStatus {
  aberto('aberto', 'Aberto'),
  andamento('andamento', 'Em andamento'),
  resolvido('resolvido', 'Resolvido'),
  cancelado('cancelado', 'Cancelado');

  final String value;
  final String label;

  const RequestStatus(this.value, this.label);

  bool get isOpen => this == aberto || this == andamento;

  static RequestStatus fromValue(String? v) =>
      values.firstWhere((s) => s.value == v, orElse: () => aberto);
}

/// Pedido de manutenção ou reposição do ministério.
class MinistryRequest {
  final String id;
  final String title;
  final RequestKind kind;
  final String? location;
  final String? details;
  final RequestStatus status;
  final String? statusNote;
  final String? stockItemName;
  final DateTime? serviceDate;

  /// Caminho no bucket privado `ministry-request-photos`.
  final String? photoPath;

  /// `user_account.id` de quem abriu.
  final String? openedBy;
  final DateTime openedAt;

  const MinistryRequest({
    required this.id,
    required this.title,
    required this.kind,
    this.location,
    this.details,
    required this.status,
    this.statusNote,
    this.stockItemName,
    this.serviceDate,
    this.photoPath,
    this.openedBy,
    required this.openedAt,
  });

  factory MinistryRequest.fromJson(Map<String, dynamic> j) {
    final item = j['ministry_stock_item'];
    final ws = j['worship_service'];
    final date = ws is Map ? ws['service_date'] as String? : null;
    return MinistryRequest(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      kind: RequestKind.fromValue(j['kind'] as String?),
      location: j['location'] as String?,
      details: j['details'] as String?,
      status: RequestStatus.fromValue(j['status'] as String?),
      statusNote: j['status_note'] as String?,
      stockItemName: item is Map ? item['name'] as String? : null,
      serviceDate: date == null ? null : DateTime.tryParse(date),
      photoPath: j['photo_path'] as String?,
      openedBy: j['opened_by'] as String?,
      openedAt: DateTime.parse(j['opened_at'] as String).toLocal(),
    );
  }
}

/// "1.234,50" / "1234.5" / "" -> 1234.5 / null.
double? parseReais(String text) {
  final t = text.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;
  // Com vírgula, o ponto é milhar; sem vírgula, o ponto é decimal.
  return double.tryParse(
    t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t,
  );
}
