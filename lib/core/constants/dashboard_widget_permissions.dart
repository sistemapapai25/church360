/// CHU-305: mapa de qual permissão RBAC (`permissions.code`, ver
/// `backend-scripts/16_permissions_seed.sql`) cada widget do Dashboard de
/// Liderança exige para aparecer. `null` significa que o widget não passa
/// por checagem de permissão — hoje só `birthdays_month`, que continua
/// sempre visível a quem acessa o Dashboard (decisão CHU-302).
///
/// Widget keys conforme seed em
/// `supabase/migrations/20260119000000_create_dashboard_widgets.sql`.
const Map<String, String?> dashboardWidgetPermissionMap = {
  'birthdays_month': null,
  'recent_members': 'members.view',
  'member_growth': 'members.view',
  'top_tags': 'tags.view',
  'upcoming_events': 'events.view',
  'events_stats': 'events.view_statistics',
  'top_active_groups': 'groups.view',
  'average_attendance': 'groups.view',
  'upcoming_expenses': 'financial.view_reports',
  'financial_summary': 'financial.view_reports',
  'contributions_by_type': 'financial.view_reports',
  'financial_goals': 'financial.view_reports',
};

// CHU-384 (29/09/2026): aqui existia `dashboardWidgetsRequiringCoordinator`,
// o conjunto de widgets que, além da permissão acima, exigiam ser
// `MinistryRole.coordinator` de algum ministério. Continha só
// `upcoming_events`.
//
// Esse segundo filtro escondia o card de TODO MUNDO, inclusive do Owner,
// desde 20/08: nenhuma linha de `ministry_member` tem `role = 'coordinator'`
// em produção — os papéis em uso são `leader` e `member`. O servidor tinha o
// mesmo filtro, e ainda comparava a chave errada (`auth.uid()` contra uma
// coluna que guarda `user_account.id`).
//
// Decisão: a Agenda deixa de ter regra própria e segue `events.view`, como os
// outros onze cards — é o que [dashboardWidgetPermissionMap] já dizia.
// Se um dia voltar a existir card com régua além do RBAC, ele precisa de
// prova de que o dado que a régua lê existe; foi isso que faltou aqui.
