/// KPIs do dashboard do ministério Raízes.
///
/// Os números de visitantes vêm de `user_account` (status visitor/new_convert);
/// os números de visitas vêm de `raizes_visit_schedule` (Lote 4B).
class RaizesDashboardStats {
  /// Total de visitantes ativos (`status` em `visitor` ou `new_convert`).
  final int totalActiveVisitors;

  /// Visitantes que ainda querem contato e estão com `follow_up_status = pending`.
  /// Lista direta de trabalho para o Raízes.
  final int wantingContactPending;

  /// Visitantes sem padrinho/responsável (`assigned_mentor_id IS NULL`),
  /// considerando apenas status visitor/new_convert.
  final int withoutMentor;

  /// Novas decisões nos últimos 30 dias (`is_salvation = true` e `salvation_date >= hoje - 30`).
  final int newSalvationsLast30Days;

  /// Primeira visita nos últimos 30 dias (`first_visit_date >= hoje - 30`).
  final int newVisitorsLast30Days;

  /// Visitas agendadas para hoje (`scheduled_date = hoje` AND status em
  /// `pending`/`confirmed`). Lote 4B.
  final int visitsToday;

  /// Visitas em atraso (`scheduled_date < hoje` AND status em
  /// `pending`/`confirmed`). Lote 4B.
  final int visitsOverdue;

  const RaizesDashboardStats({
    required this.totalActiveVisitors,
    required this.wantingContactPending,
    required this.withoutMentor,
    required this.newSalvationsLast30Days,
    required this.newVisitorsLast30Days,
    required this.visitsToday,
    required this.visitsOverdue,
  });

  static const empty = RaizesDashboardStats(
    totalActiveVisitors: 0,
    wantingContactPending: 0,
    withoutMentor: 0,
    newSalvationsLast30Days: 0,
    newVisitorsLast30Days: 0,
    visitsToday: 0,
    visitsOverdue: 0,
  );
}
