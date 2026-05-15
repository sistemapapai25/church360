import 'worship_attendance.dart';

/// KPIs do dashboard do ministério Diaconato (Lote MD).
///
/// Pontos de origem:
/// - `lastCount` → última `worship_attendance_count` deste ministério (qualquer status).
/// - `pendingTriageInLastCount` → eligible MINUS pessoas marcadas em
///   `worship_attendance_person` para o último count.
/// - `openCommunionItems` / `myAssignedItems` → `communion_delivery_item`
///   em lotes `status='open'` com `status IN ('pending','assigned')`.
/// - `unregisteredVisitorsLast30Days` → soma de
///   `worship_attendance_count.total_unregistered_visitors` (últimos 30 dias)
///   deste ministério.
class DiaconatoDashboardStats {
  /// Última contagem registrada. `null` se nenhuma foi feita ainda.
  final WorshipAttendanceCount? lastCount;

  /// Pendências de triagem no último culto: pessoas elegíveis (membros +
  /// visitantes) que não aparecem em `worship_attendance_person` para a
  /// contagem do último culto. Zero quando `lastCount` é null.
  final int pendingTriageInLastCount;

  /// Items de ceia em aberto (status pending ou assigned) em lotes abertos
  /// deste ministério.
  final int openCommunionItems;

  /// Subconjunto de `openCommunionItems` atribuídos ao usuário logado.
  /// Zero se o usuário ainda não foi atribuído a nenhum item.
  final int myAssignedItems;

  /// Soma de `total_unregistered_visitors` das contagens deste ministério
  /// nos últimos 30 dias. Alerta de captação para o Raízes.
  final int unregisteredVisitorsLast30Days;

  /// Quantidade de lotes de ceia ainda abertos deste ministério.
  final int openBatchesCount;

  const DiaconatoDashboardStats({
    required this.lastCount,
    required this.pendingTriageInLastCount,
    required this.openCommunionItems,
    required this.myAssignedItems,
    required this.unregisteredVisitorsLast30Days,
    required this.openBatchesCount,
  });

  static const empty = DiaconatoDashboardStats(
    lastCount: null,
    pendingTriageInLastCount: 0,
    openCommunionItems: 0,
    myAssignedItems: 0,
    unregisteredVisitorsLast30Days: 0,
    openBatchesCount: 0,
  );
}
