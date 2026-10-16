import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/branches/presentation/providers/branches_provider.dart';

/// Um item do Menu de Gestão da Dashboard.
///
/// Visível quando o usuário tem [permission] (RBAC) **ou**, nos poucos itens
/// fora do RBAC, quando [visibleWhen] resolve `true` (Filiais = admin da
/// matriz). Nunca os dois.
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

/// Uma categoria do Menu de Gestão (um item da barra de baixo da Dashboard
/// ou uma seção do ☰ da igreja). Some por inteiro quando o usuário não tem nenhuma das
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

  final String title;
  final List<String> permissions;
  final ProviderListenable<AsyncValue<bool>>? extraVisibilityCheck;
  final List<ManagementMenuItem> items;
}

/// G2 (roadmap 14/10, Frente G de 16/10): o item Pessoas da barra de baixo
/// da Dashboard. "Vincular pessoas" é a tela de cadastros duplicados.
const ManagementMenuCategory kPeopleMenu = ManagementMenuCategory(
  icon: Icons.groups,
  title: 'Pessoas',
  permissions: [
    'members.merge_duplicates',
    'members.view',
    'visitors.view',
    'kids.manage',
    'tags.view',
  ],
  items: [
    ManagementMenuItem(
      icon: Icons.link,
      title: 'Vincular pessoas',
      route: '/duplicate-accounts',
      permission: 'members.merge_duplicates',
    ),
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
      icon: Icons.child_care,
      title: 'Kids',
      route: '/kids',
      permission: 'kids.manage',
    ),
    ManagementMenuItem(
      icon: Icons.label_outline,
      title: 'Tags',
      route: '/tags',
      permission: 'tags.view',
    ),
  ],
);

/// G3: o item Ministérios da barra. Cada item vira uma aba da tela
/// `/dashboard/ministerios`. Grupos de Comunhão é um ministério (tipo
/// `comunhao`); Turmas e Cursos ficam dentro do ministério de cada um.
const ManagementMenuCategory kMinistriesMenu = ManagementMenuCategory(
  icon: Icons.church,
  title: 'Ministérios',
  permissions: ['ministries.view', 'support_materials.view'],
  items: [
    ManagementMenuItem(
      icon: Icons.church,
      title: 'Ministérios',
      route: '/ministries',
      permission: 'ministries.view',
    ),
    ManagementMenuItem(
      icon: Icons.library_books,
      title: 'Materiais de apoio',
      route: '/support-materials?from=dashboard',
      permission: 'support_materials.view',
    ),
  ],
);

/// G4: as seções do ☰ "Gestão da igreja", no perfil da igreja (logo na
/// barra de baixo). As Configurações de Desenvolvedor e os Agentes IA saíram
/// daqui: vão para o Support360 (Frente G6).
final List<ManagementMenuCategory> kChurchMenu = [
  ManagementMenuCategory(
    icon: Icons.church,
    title: 'Sua igreja',
    permissions: const ['church_info.edit'],
    extraVisibilityCheck: isMatrizAdminProvider,
    items: [
      const ManagementMenuItem(
        icon: Icons.church,
        title: 'Dados da igreja',
        route: '/church-info/manage',
        permission: 'church_info.edit',
      ),
      ManagementMenuItem(
        icon: Icons.account_tree,
        title: 'Filiais',
        route: '/branches',
        visibleWhen: isMatrizAdminProvider,
      ),
      const ManagementMenuItem(
        icon: Icons.checklist,
        title: 'Primeiros passos',
        route: '/primeiros-passos',
        permission: 'church_info.edit',
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
      'news.edit',
      'reading_plans.manage',
      'courses.view',
      'live_stream.manage',
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
        icon: Icons.article,
        title: 'Notícias',
        route: '/news/admin',
        permission: 'news.edit',
      ),
      ManagementMenuItem(
        icon: Icons.menu_book,
        title: 'Planos de leitura',
        route: '/reading-plans/admin',
        permission: 'reading_plans.manage',
      ),
      // Criar curso só existe nesta tela; as turmas ficam no ministério.
      ManagementMenuItem(
        icon: Icons.school,
        title: 'Cursos',
        route: '/courses?from=dashboard',
        permission: 'courses.view',
      ),
      ManagementMenuItem(
        icon: Icons.live_tv,
        title: 'Culto ao vivo',
        route: '/live-stream/manage',
        permission: 'live_stream.manage',
      ),
    ],
  ),
  const ManagementMenuCategory(
    icon: Icons.support_agent,
    title: 'Atendimento e finanças',
    permissions: ['support.attend', 'financial.edit', 'financial.manage'],
    items: [
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
    icon: Icons.settings,
    title: 'Configurações',
    permissions: [
      'settings.manage_permissions',
      'dispatch.configure',
      'events.checkin',
      'reports.view_analytics',
      'reports.view',
    ],
    items: [
      ManagementMenuItem(
        icon: Icons.security,
        title: 'Permissões e cargos',
        route: '/permissions',
        permission: 'settings.manage_permissions',
      ),
      ManagementMenuItem(
        icon: Icons.send,
        title: 'Disparos de mensagens',
        route: '/dispatch-config',
        permission: 'dispatch.configure',
      ),
      ManagementMenuItem(
        icon: Icons.qr_code_scanner,
        title: 'Leitor de QR Code',
        route: '/qr-scanner',
        permission: 'events.checkin',
      ),
      ManagementMenuItem(
        icon: Icons.analytics,
        title: 'Analytics',
        route: '/analytics',
        permission: 'reports.view_analytics',
      ),
      ManagementMenuItem(
        icon: Icons.assessment,
        title: 'Relatórios customizados',
        route: '/custom-reports',
        permission: 'reports.view',
      ),
    ],
  ),
];