import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/branches/presentation/providers/branches_provider.dart';
import '../../../features/permissions/providers/permissions_providers.dart';
import '../../../features/support_chat/data/support_agents_data.dart';

/// Um item do Menu de Gestão da Dashboard.
///
/// Visível quando o usuário tem [permission] (RBAC) **ou**, nos poucos itens
/// fora do RBAC, quando [visibleWhen] resolve `true` (Filiais = admin da
/// matriz; Configurações de Desenvolvedor = owner). Nunca os dois.
@immutable
class ManagementMenuItem {
  const ManagementMenuItem({
    required this.icon,
    required this.title,
    required this.route,
    this.permission,
    this.visibleWhen,
  }) : assert(
          (permission == null) != (visibleWhen == null),
          'Um item tem permissão RBAC ou um gate próprio, nunca os dois',
        );

  final IconData icon;
  final String title;
  final String route;
  final String? permission;
  final ProviderListenable<AsyncValue<bool>>? visibleWhen;
}

/// Uma categoria do Menu de Gestão (uma seção do drawer, uma bolinha da
/// fileira). Some por inteiro quando o usuário não tem nenhuma das
/// [permissions] nem satisfaz [extraVisibilityCheck] (CHU-310).
@immutable
class ManagementMenuCategory {
  const ManagementMenuCategory({
    required this.icon,
    required this.title,
    required this.permissions,
    required this.items,
    this.extraVisibilityCheck,
  });

  final IconData icon;

  /// Em Title Case; o drawer põe em caixa alta.
  final String title;
  final List<String> permissions;
  final ProviderListenable<AsyncValue<bool>>? extraVisibilityCheck;
  final List<ManagementMenuItem> items;
}

/// Fonte única do Menu de Gestão (B5a, roadmap Home/culto/Dashboard de
/// 14/10/2026): o drawer e a fileira de bolinhas da Dashboard leem daqui, com
/// o mesmo gating. Mudou um item, mudou nos dois.
final List<ManagementMenuCategory> kManagementMenu = [
  const ManagementMenuCategory(
    icon: Icons.groups,
    title: 'Pessoas',
    permissions: ['members.view', 'visitors.view', 'tags.view'],
    items: [
      ManagementMenuItem(
        icon: Icons.groups,
        title: 'Membros',
        route: '/members',
        permission: 'members.view',
      ),
      ManagementMenuItem(
        icon: Icons.person_add,
        title: 'Visitantes',
        route: '/visitors',
        permission: 'visitors.view',
      ),
      ManagementMenuItem(
        icon: Icons.label_outline,
        title: 'Tags',
        route: '/tags',
        permission: 'tags.view',
      ),
    ],
  ),
  const ManagementMenuCategory(
    icon: Icons.church,
    title: 'Ministério',
    permissions: [
      'church_info.edit',
      'ministries.view',
      'groups.view',
      'study_groups.view',
      'support_materials.view',
    ],
    items: [
      ManagementMenuItem(
        icon: Icons.church,
        title: 'A Igreja',
        route: '/church-info/manage',
        permission: 'church_info.edit',
      ),
      ManagementMenuItem(
        icon: Icons.checklist,
        title: 'Primeiros passos',
        route: '/primeiros-passos',
        permission: 'church_info.edit',
      ),
      ManagementMenuItem(
        icon: Icons.groups,
        title: 'Ministérios',
        route: '/ministries',
        permission: 'ministries.view',
      ),
      ManagementMenuItem(
        icon: Icons.group,
        title: 'Grupos de Comunhão',
        route: '/groups?from=dashboard',
        permission: 'groups.view',
      ),
      ManagementMenuItem(
        icon: Icons.menu_book,
        title: 'Turmas',
        route: '/courses?tab=turmas&from=dashboard',
        permission: 'study_groups.view',
      ),
      ManagementMenuItem(
        icon: Icons.library_books,
        title: 'Material de Apoio',
        route: '/support-materials?from=dashboard',
        permission: 'support_materials.view',
      ),
    ],
  ),
  const ManagementMenuCategory(
    icon: Icons.calendar_today,
    title: 'Agenda',
    permissions: ['events.view', 'worship.view'],
    items: [
      ManagementMenuItem(
        icon: Icons.event_note,
        title: 'Agenda',
        route: '/events',
        permission: 'events.view',
      ),
      ManagementMenuItem(
        icon: Icons.church,
        title: 'Cultos',
        route: '/worship-services',
        permission: 'worship.view',
      ),
    ],
  ),
  const ManagementMenuCategory(
    icon: Icons.phone_android,
    title: 'Conteúdo do app',
    permissions: [
      'community.moderate',
      'testimonies.moderate',
      'quick_news.create',
      'prayer_requests.moderate',
      'devotionals.create',
      'live_stream.manage',
      'support.attend',
      'financial.edit',
      'financial.manage',
    ],
    items: [
      ManagementMenuItem(
        icon: Icons.groups,
        title: 'Comunidade',
        route: '/community/admin',
        permission: 'community.moderate',
      ),
      ManagementMenuItem(
        icon: Icons.volunteer_activism_outlined,
        title: 'Pedidos de oração',
        route: '/prayer-requests?from=dashboard',
        permission: 'prayer_requests.moderate',
      ),
      ManagementMenuItem(
        icon: Icons.record_voice_over_outlined,
        title: 'Testemunhos',
        route: '/home/testimonies',
        permission: 'testimonies.moderate',
      ),
      ManagementMenuItem(
        icon: Icons.campaign_outlined,
        title: 'Avisos',
        route: '/home/quick-news',
        permission: 'quick_news.create',
      ),
      ManagementMenuItem(
        icon: Icons.book,
        title: 'Devocionais',
        route: '/devotionals/admin',
        permission: 'devotionals.create',
      ),
      ManagementMenuItem(
        icon: Icons.live_tv,
        title: 'Culto ao vivo',
        route: '/live-stream/manage',
        permission: 'live_stream.manage',
      ),
      ManagementMenuItem(
        icon: Icons.support_agent,
        title: 'Atendimentos',
        route: '/support/attend',
        permission: 'support.attend',
      ),
      ManagementMenuItem(
        icon: Icons.volunteer_activism,
        title: 'Contribuição',
        route: '/manage-contribution',
        permission: 'financial.edit',
      ),
      ManagementMenuItem(
        icon: Icons.account_balance,
        title: 'Financeiro',
        route: '/financial',
        permission: 'financial.manage',
      ),
    ],
  ),
  const ManagementMenuCategory(
    icon: Icons.apps,
    title: 'Módulos',
    permissions: [
      'agents.manage_center',
      'courses.view',
      'kids.manage',
      'news.edit',
      'reading_plans.manage',
    ],
    items: [
      // CHU-310 follow-up: agents.manage_center, kids.manage e
      // reading_plans.manage são códigos novos, ver
      // backend-scripts/add_missing_drawer_permissions.sql
      if (kMultiAgentsEnabled)
        ManagementMenuItem(
          icon: Icons.smart_toy,
          title: 'Agentes IA',
          route: '/agents-center',
          permission: 'agents.manage_center',
        ),
      ManagementMenuItem(
        icon: Icons.school,
        title: 'Cursos',
        route: '/courses?from=dashboard',
        permission: 'courses.view',
      ),
      ManagementMenuItem(
        icon: Icons.child_care,
        title: 'Kid',
        route: '/kids',
        permission: 'kids.manage',
      ),
      ManagementMenuItem(
        icon: Icons.article,
        title: 'Notícias',
        route: '/news/admin',
        permission: 'news.edit',
      ),
      ManagementMenuItem(
        icon: Icons.menu_book,
        title: 'Planos de Leitura',
        route: '/reading-plans/admin',
        permission: 'reading_plans.manage',
      ),
    ],
  ),
  ManagementMenuCategory(
    icon: Icons.settings,
    title: 'Configurações',
    permissions: const [
      'settings.manage_permissions',
      'events.checkin',
      'dispatch.configure',
      'reports.view_analytics',
      'reports.view',
      'members.merge_duplicates',
    ],
    extraVisibilityCheck: currentUserSeesConfigCategoryExtrasProvider,
    items: [
      const ManagementMenuItem(
        icon: Icons.security,
        title: 'Permissões',
        route: '/permissions',
        permission: 'settings.manage_permissions',
      ),
      ManagementMenuItem(
        icon: Icons.account_tree,
        title: 'Filiais',
        route: '/branches',
        visibleWhen: isMatrizAdminProvider,
      ),
      const ManagementMenuItem(
        icon: Icons.qr_code_scanner,
        title: 'Leitor de QR Code',
        route: '/qr-scanner',
        permission: 'events.checkin',
      ),
      const ManagementMenuItem(
        icon: Icons.send,
        title: 'Configuração de Disparos',
        route: '/dispatch-config',
        permission: 'dispatch.configure',
      ),
      const ManagementMenuItem(
        icon: Icons.people_alt_outlined,
        title: 'Vincular Cadastros',
        route: '/duplicate-accounts',
        permission: 'members.merge_duplicates',
      ),
      ManagementMenuItem(
        icon: Icons.developer_mode,
        title: 'Configurações de Desenvolvedor',
        route: '/developer-settings',
        visibleWhen: currentUserIsOwnerProvider,
      ),
      const ManagementMenuItem(
        icon: Icons.analytics,
        title: 'Analytics & Relatórios',
        route: '/analytics',
        permission: 'reports.view_analytics',
      ),
      const ManagementMenuItem(
        icon: Icons.assessment,
        title: 'Relatórios Customizados',
        route: '/custom-reports',
        permission: 'reports.view',
      ),
    ],
  ),
];
