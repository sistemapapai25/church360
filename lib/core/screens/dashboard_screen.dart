import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_branding.dart';
import '../errors/app_error_handler.dart';
import '../widgets/dashboard_charts.dart';
import '../providers/dashboard_widget_provider.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/custom_reports/presentation/providers/custom_report_providers.dart';
import '../../features/permissions/presentation/widgets/permission_gate.dart';
import '../../features/branches/presentation/providers/branches_provider.dart';
import '../../features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;

/// Tela de Dashboard com estatísticas e gráficos
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home?tab=more');
      },
      child: Scaffold(
        key: _scaffoldKey,
        // Drawer lateral com opções de Gestão (abre da esquerda)
        drawer: _buildManagementDrawer(context),
        appBar: AppBar(
          title: const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          // Botão de menu no canto superior esquerdo
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            tooltip: 'Menu de Gestão',
          ),
          actions: [
            // Botão voltar para Menu Mais
            IconButton(
              icon: const Icon(
                Icons.exit_to_app_outlined,
              ), // Ícone indicando saída/retorno
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go('/home?tab=more');
                }
              },
              tooltip: 'Voltar para Menu',
            ),
            // Botão de configurar Dashboard: admin/leader com
            // dashboard.configure vai pra config geral do tenant; qualquer
            // outro usuário com acesso ao Dashboard vai pra tela pessoal
            // (CHU-308).
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _openDashboardSettings(context),
              tooltip: 'Configurar Dashboard',
            ),
            const NotificationBadge(),
            const SizedBox(width: 8),
          ],
        ),
        body: ref
            .watch(enabledDashboardWidgetsProvider)
            .when(
              data: (widgets) {
                if (widgets.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.widgets_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum widget ativo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Configure os widgets da Dashboard nas configurações',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(enabledDashboardWidgetsProvider);
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final widget in widgets) ...[
                          _buildWidgetByKey(context, widget.widgetKey),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar widgets',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppErrorHandler.userMessage(
                          error,
                          feature: 'dashboard.load_widgets',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  /// Método auxiliar para mapear widget_key para Widget
  Widget _buildWidgetByKey(BuildContext context, String widgetKey) {
    // Verificar se é um relatório customizado
    if (widgetKey.startsWith('custom_report_')) {
      final reportId = widgetKey.replaceFirst('custom_report_', '');
      return _buildCustomReportWidget(context, reportId);
    }

    // Widgets padrão
    final widgetMap = {
      'birthdays_month': InkWell(
        onTap: () => context.push('/reports/members?tab=birthdays'),
        child: const BirthdaysThisMonthCard(),
      ),
      'recent_members': InkWell(
        onTap: () => context.push('/reports/members?tab=recent'),
        child: const RecentMembersCard(),
      ),
      'upcoming_events': InkWell(
        onTap: () => context.push('/reports/events'),
        child: const UpcomingEventsCard(),
      ),
      'upcoming_expenses': InkWell(
        onTap: () => context.push('/financial-reports?tab=expenses'),
        child: const UpcomingExpensesCard(),
      ),
      'member_growth': InkWell(
        onTap: () => context.push('/reports/members'),
        child: const MemberGrowthChart(),
      ),
      'events_stats': InkWell(
        onTap: () => context.push('/reports/events'),
        child: const EventsStatsCard(),
      ),
      'top_active_groups': InkWell(
        onTap: () => context.push('/reports/groups'),
        child: const TopActiveGroupsCard(),
      ),
      'average_attendance': InkWell(
        onTap: () => context.push('/reports/attendance'),
        child: const AverageAttendanceCard(),
      ),
      // 'top_tags': InkWell(
      //   onTap: () => context.push('/reports/members?tab=tags'),
      //   child: const TopTagsCard(),
      // ),
      'financial_summary': InkWell(
        onTap: () => context.push('/financial-reports'),
        child: const FinancialSummaryCards(),
      ),
      'contributions_by_type': InkWell(
        onTap: () => context.push('/financial-reports'),
        child: const ContributionsByTypeChart(),
      ),
      'financial_goals': InkWell(
        onTap: () => context.push('/financial-reports'),
        child: const FinancialGoalsWidget(),
      ),
      'dispatch_auto_scheduler': InkWell(
        onTap: () => context.push('/dispatch-config'),
        child: const AutoSchedulerSummaryCard(),
      ),
    };

    return widgetMap[widgetKey] ?? const SizedBox.shrink();
  }

  /// Construir widget de relatório customizado
  Widget _buildCustomReportWidget(BuildContext context, String reportId) {
    return Consumer(
      builder: (context, ref, child) {
        final reportAsync = ref.watch(customReportByIdProvider(reportId));

        return reportAsync.when(
          data: (report) {
            if (report == null) return const SizedBox.shrink();

            return InkWell(
              onTap: () => context.push('/custom-reports/$reportId/view'),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assessment,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (report.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          report.description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Chip(
                            label: Text(report.dataSource.label),
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            labelStyle: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(report.visualizationType.label),
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.1,
                            ),
                            labelStyle: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _openDashboardSettings(BuildContext context) async {
    final canConfigureTenant = await ref.read(
      currentUserHasPermissionProvider('dashboard.configure').future,
    );
    if (!context.mounted) return;
    context.push(
      canConfigureTenant ? '/dashboard-settings' : '/dashboard-settings/personal',
    );
  }

  /// Construir Drawer de Gestão (menu lateral)
  Widget _buildManagementDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header do Drawer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppBranding.appName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    AppBranding.organizationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 👥 PESSOAS
            _DrawerCategory(
              icon: Icons.people,
              title: 'PESSOAS',
              permissions: const ['members.view', 'visitors.view'],
              children: [
                PermissionGate(
                  permission: 'members.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.people,
                    title: 'Membros',
                    route: '/members',
                  ),
                ),
                PermissionGate(
                  permission: 'visitors.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.person_add,
                    title: 'Visitantes',
                    route: '/visitors',
                  ),
                ),
              ],
            ),

            // ⛪ MINISTÉRIO
            _DrawerCategory(
              icon: Icons.church,
              title: 'MINISTÉRIO',
              permissions: const [
                'church_info.edit',
                'ministries.view',
                'groups.view',
                'study_groups.view',
                'support_materials.view',
              ],
              children: [
                PermissionGate(
                  permission: 'church_info.edit',
                  child: const _DrawerMenuItem(
                    icon: Icons.church,
                    title: 'A Igreja',
                    route: '/church-info/manage',
                  ),
                ),
                PermissionGate(
                  permission: 'ministries.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.groups,
                    title: 'Ministérios',
                    route: '/ministries',
                  ),
                ),
                PermissionGate(
                  permission: 'groups.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.group,
                    title: 'Grupos de Comunhão',
                    route: '/groups',
                  ),
                ),
                PermissionGate(
                  permission: 'study_groups.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.menu_book,
                    title: 'Grupos de Estudo',
                    route: '/study-groups?from=dashboard',
                  ),
                ),
                PermissionGate(
                  permission: 'support_materials.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.library_books,
                    title: 'Material de Apoio',
                    route: '/support-materials',
                  ),
                ),
              ],
            ),

            // 📅 AGENDA
            _DrawerCategory(
              icon: Icons.calendar_month,
              title: 'AGENDA',
              permissions: const ['events.view'],
              children: [
                PermissionGate(
                  permission: 'events.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.event_note,
                    title: 'Agenda',
                    route: '/events',
                  ),
                ),
              ],
            ),

            // 📱 CONTEÚDO DO APP
            _DrawerCategory(
              icon: Icons.phone_android,
              title: 'CONTEÚDO DO APP',
              permissions: const [
                'testimonies.moderate',
                'prayer_requests.moderate',
                'devotionals.edit',
                'live_stream.manage',
                'financial.manage',
                'financial.view',
              ],
              children: [
                // Comunidade (Testemunhos, Pedidos, Classificados)
                MultiPermissionGate(
                  permissions: const ['testimonies.moderate', 'prayer_requests.moderate'],
                  requireAll: false,
                  child: const _DrawerMenuItem(
                    icon: Icons.people_outline,
                    title: 'Comunidade',
                    route: '/community/admin',
                  ),
                ),
                // Devocionais
                PermissionGate(
                  permission: 'devotionals.edit',
                  child: const _DrawerMenuItem(
                    icon: Icons.book,
                    title: 'Devocionais',
                    route: '/devotionals/admin',
                  ),
                ),
                // Culto ao vivo
                PermissionGate(
                  permission: 'live_stream.manage',
                  child: const _DrawerMenuItem(
                    icon: Icons.live_tv,
                    title: 'Culto ao vivo',
                    route: '/live-stream/manage',
                  ),
                ),
                // Contribuição
                PermissionGate(
                  permission: 'financial.manage',
                  child: const _DrawerMenuItem(
                    icon: Icons.volunteer_activism,
                    title: 'Contribuição',
                    route: '/manage-contribution',
                  ),
                ),
                // Financeiro
                PermissionGate(
                  permission: 'financial.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.account_balance,
                    title: 'Financeiro',
                    route: '/financial',
                  ),
                ),
              ],
            ),

            // 📚 MÓDULOS
            _DrawerCategory(
              icon: Icons.apps,
              title: 'MÓDULOS',
              permissions: const [
                'agents.manage_center',
                'courses.view',
                'kids.manage',
                'news.edit',
                'reading_plans.manage',
              ],
              children: [
                PermissionGate(
                  // CHU-310 follow-up: novo código, ver
                  // backend-scripts/add_missing_drawer_permissions.sql
                  permission: 'agents.manage_center',
                  child: const _DrawerMenuItem(
                    icon: Icons.smart_toy,
                    title: 'Agentes IA',
                    route: '/agents-center',
                  ),
                ),
                PermissionGate(
                  permission: 'courses.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.school,
                    title: 'Cursos',
                    route: '/courses?from=dashboard',
                  ),
                ),
                PermissionGate(
                  // CHU-310 follow-up: novo código, ver
                  // backend-scripts/add_missing_drawer_permissions.sql
                  permission: 'kids.manage',
                  child: const _DrawerMenuItem(
                    icon: Icons.child_care,
                    title: 'Kid',
                    route: '/kids',
                  ),
                ),
                PermissionGate(
                  permission: 'news.edit',
                  child: const _DrawerMenuItem(
                    icon: Icons.article,
                    title: 'Notícias',
                    route: '/news/admin',
                  ),
                ),
                PermissionGate(
                  // CHU-310 follow-up: novo código, ver
                  // backend-scripts/add_missing_drawer_permissions.sql
                  permission: 'reading_plans.manage',
                  child: const _DrawerMenuItem(
                    icon: Icons.menu_book,
                    title: 'Planos de Leitura',
                    route: '/reading-plans/admin',
                  ),
                ),
              ],
            ),

            // ⚙️ CONFIGURAÇÕES
            _DrawerCategory(
              icon: Icons.settings,
              title: 'CONFIGURAÇÕES',
              permissions: const [
                'settings.manage_permissions',
                'events.checkin',
                'dispatch.configure',
                'reports.view_analytics',
                'reports.view',
              ],
              extraVisibilityCheck: currentUserSeesConfigCategoryExtrasProvider,
              children: [
                PermissionGate(
                  permission: 'settings.manage_permissions',
                  child: const _DrawerMenuItem(
                    icon: Icons.security,
                    title: 'Permissões',
                    route: '/permissions',
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isMatrizAdminAsync = ref.watch(isMatrizAdminProvider);
                    return isMatrizAdminAsync.when(
                      data: (isMatrizAdmin) {
                        if (!isMatrizAdmin) return const SizedBox.shrink();
                        return const _DrawerMenuItem(
                          icon: Icons.account_tree,
                          title: 'Filiais',
                          route: '/branches',
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                PermissionGate(
                  permission: 'events.checkin',
                  child: const _DrawerMenuItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Leitor de QR Code',
                    route: '/qr-scanner',
                  ),
                ),
                PermissionGate(
                  permission: 'dispatch.configure',
                  child: const _DrawerMenuItem(
                    icon: Icons.send,
                    title: 'Configuração de Disparos',
                    route: '/dispatch-config',
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isOwnerAsync = ref.watch(currentUserIsOwnerProvider);
                    return isOwnerAsync.when(
                      data: (isOwner) {
                        if (!isOwner) return const SizedBox.shrink();
                        return _DrawerMenuItem(
                          icon: Icons.developer_mode,
                          title: 'Configurações de Desenvolvedor',
                          route: '/developer-settings',
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                PermissionGate(
                  permission: 'reports.view_analytics',
                  child: const _DrawerMenuItem(
                    icon: Icons.analytics,
                    title: 'Analytics & Relatórios',
                    route: '/analytics',
                  ),
                ),
                PermissionGate(
                  permission: 'reports.view',
                  child: const _DrawerMenuItem(
                    icon: Icons.assessment,
                    title: 'Relatórios Customizados',
                    route: '/custom-reports',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Versão do App
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppBranding.versionLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de categoria expansível do drawer.
///
/// Fica oculta por inteiro se o usuário não tiver nenhuma das [permissions]
/// (OR lógico) nem satisfizer [extraVisibilityCheck] — evita mostrar um
/// cabeçalho de categoria expansível que não revela nenhum item ao abrir
/// (achado real de QA: CHU-310).
class _DrawerCategory extends ConsumerWidget {
  final IconData icon;
  final String title;
  final List<String> permissions;
  final ProviderListenable<AsyncValue<bool>>? extraVisibilityCheck;
  final List<Widget> children;

  const _DrawerCategory({
    required this.icon,
    required this.title,
    required this.permissions,
    this.extraVisibilityCheck,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = [
      for (final permission in permissions)
        ref.watch(currentUserHasPermissionProvider(permission)),
      if (extraVisibilityCheck != null) ref.watch(extraVisibilityCheck!),
    ];

    if (checks.any((check) => check.isLoading)) {
      return const SizedBox.shrink();
    }
    final anyVisible = checks.any((check) => check.value == true);
    if (!anyVisible) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }
}

/// Widget de item do drawer
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: () {
        Navigator.pop(context); // Fechar drawer
        context.push(route);
      },
    );
  }
}
