import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_branding.dart';
import '../errors/app_error_handler.dart';
import '../widgets/dashboard_charts.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../core/constants/supabase_constants.dart';
import '../providers/dashboard_widget_provider.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/custom_reports/presentation/providers/custom_report_providers.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/permissions/presentation/widgets/permission_gate.dart';

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
            // Botão de configurar Dashboard
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/dashboard-settings'),
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
              children: [
                _DrawerMenuItem(
                  icon: Icons.people,
                  title: 'Membros',
                  route: '/members',
                ),
                _DrawerMenuItem(
                  icon: Icons.person_add,
                  title: 'Visitantes',
                  route: '/visitors',
                ),
              ],
            ),

            // ⛪ MINISTÉRIO
            _DrawerCategory(
              icon: Icons.church,
              title: 'MINISTÉRIO',
              children: [
                _DrawerMenuItem(
                  icon: Icons.church,
                  title: 'A Igreja',
                  route: '/church-info/manage',
                ),
                _DrawerMenuItem(
                  icon: Icons.groups,
                  title: 'Ministérios',
                  route: '/ministries',
                ),
                _DrawerMenuItem(
                  icon: Icons.group,
                  title: 'Grupos de Comunhão',
                  route: '/groups',
                ),
                _DrawerMenuItem(
                  icon: Icons.menu_book,
                  title: 'Grupos de Estudo',
                  route: '/study-groups?from=dashboard',
                ),
                _DrawerMenuItem(
                  icon: Icons.library_books,
                  title: 'Material de Apoio',
                  route: '/support-materials',
                ),
              ],
            ),

            // 📅 AGENDA
            _DrawerCategory(
              icon: Icons.calendar_month,
              title: 'AGENDA',
              children: [
                _DrawerMenuItem(
                  icon: Icons.event_note,
                  title: 'Agenda',
                  route: '/events',
                ),
              ],
            ),

            // 📱 CONTEÚDO DO APP
            _DrawerCategory(
              icon: Icons.phone_android,
              title: 'CONTEÚDO DO APP',
              children: [
                // Comunidade (Testemunhos, Pedidos, Classificados)
                _DrawerMenuItem(
                  icon: Icons.people_outline,
                  title: 'Comunidade',
                  route: '/community/admin',
                ),
                // Devocionais
                _DrawerMenuItem(
                  icon: Icons.book,
                  title: 'Devocionais',
                  route: '/devotionals/admin',
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
                _DrawerMenuItem(
                  icon: Icons.volunteer_activism,
                  title: 'Contribuição',
                  route: '/manage-contribution',
                ),
                // Financeiro
                _DrawerMenuItem(
                  icon: Icons.account_balance,
                  title: 'Financeiro',
                  route: '/financial',
                ),
              ],
            ),

            // 📚 MÓDULOS
            _DrawerCategory(
              icon: Icons.apps,
              title: 'MÓDULOS',
              children: [
                _DrawerMenuItem(
                  icon: Icons.smart_toy,
                  title: 'Agentes IA',
                  route: '/agents-center',
                ),
                _DrawerMenuItem(
                  icon: Icons.school,
                  title: 'Cursos',
                  route: '/courses?from=dashboard',
                ),
                _DrawerMenuItem(
                  icon: Icons.child_care,
                  title: 'Kid',
                  route: '/kids',
                ),
                _DrawerMenuItem(
                  icon: Icons.article,
                  title: 'Notícias',
                  route: '/news/admin',
                ),
                _DrawerMenuItem(
                  icon: Icons.menu_book,
                  title: 'Planos de Leitura',
                  route: '/reading-plans/admin',
                ),
              ],
            ),

            // ⚙️ CONFIGURAÇÕES
            _DrawerCategory(
              icon: Icons.settings,
              title: 'CONFIGURAÇÕES',
              children: [
                _DrawerMenuItem(
                  icon: Icons.security,
                  title: 'Permissões',
                  route: '/permissions',
                ),
                _DrawerMenuItem(
                  icon: Icons.qr_code_scanner,
                  title: 'Leitor de QR Code',
                  route: '/qr-scanner',
                ),
                _DrawerMenuItem(
                  icon: Icons.send,
                  title: 'Configuração de Disparos',
                  route: '/dispatch-config',
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final supabase = ref.watch(supabaseClientProvider);
                    final memberAsync = ref.watch(currentMemberProvider);
                    return memberAsync.when(
                      data: (member) {
                        if (member == null) return const SizedBox.shrink();
                        return FutureBuilder<Map<String, dynamic>?>(
                          future: supabase
                              .from('user_account')
                              .select('role_global')
                              .eq('id', member.id)
                              .eq(
                                'tenant_id',
                                SupabaseConstants.currentTenantId,
                              )
                              .maybeSingle(),
                          builder: (context, snapshot) {
                            final role =
                                (snapshot.data?['role_global']?.toString() ??
                                        '')
                                    .trim()
                                    .toLowerCase();
                            final isOwner = role == 'owner';
                            if (!isOwner) return const SizedBox.shrink();
                            return _DrawerMenuItem(
                              icon: Icons.developer_mode,
                              title: 'Configurações de Desenvolvedor',
                              route: '/developer-settings',
                            );
                          },
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                _DrawerMenuItem(
                  icon: Icons.analytics,
                  title: 'Analytics & Relatórios',
                  route: '/analytics',
                ),
                _DrawerMenuItem(
                  icon: Icons.assessment,
                  title: 'Relatórios Customizados',
                  route: '/custom-reports',
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

/// Widget de categoria expansível do drawer
class _DrawerCategory extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _DrawerCategory({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
