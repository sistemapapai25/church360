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

/// Widgets que, além da permissão em [dashboardWidgetPermissionMap], exigem
/// que o usuário seja `MinistryRole.coordinator` de pelo menos um
/// ministério — o "líder direto" do departamento (decisão CHU-302). Hoje
/// só a Agenda completa (`upcoming_events`); quem não é coordinator não vê
/// esse card, mesmo tendo `events.view`.
const Set<String> dashboardWidgetsRequiringCoordinator = {'upcoming_events'};
