// Aba Rotina (F3 de ROADMAP-2026-10-12-MINISTERIO-PROCESSOS): o checklist
// pré, durante e pós-culto de um ministério. Tabelas e RPCs na migration
// 20261008004000_ministerio_rotina.

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

  const RoutineRun({
    required this.id,
    required this.worshipServiceId,
    this.serviceDate,
    this.serviceTime,
    this.leaderOfDay,
    this.needsNotes,
    this.confirmedAt,
    this.checks = const [],
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
    );
  }
}

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
