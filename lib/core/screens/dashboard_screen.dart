import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_icons.dart';
import '../domain/models/management_menu.dart';
import '../errors/app_error_handler.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/dashboard_card_frame.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/management_menu_row.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../widgets/qr_scanner_fab.dart';
import '../providers/dashboard_widget_provider.dart';
import '../../features/church_info/presentation/providers/church_info_provider.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/custom_reports/presentation/providers/custom_report_data_provider.dart';
import '../../features/custom_reports/presentation/widgets/custom_report_dashboard_card.dart';
import '../../features/permissions/presentation/widgets/permission_gate.dart';
import '../../features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;

/// Tela de Dashboard com estatísticas e gráficos
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home?tab=more');
      },
      child: Scaffold(
        appBar: AppBar(
          // Cabeçalho no mesmo padrão visual já usado na aba "Mais"
          // (superficie do tema, cantos inferiores arredondados, sombra sutil ao
          // rolar) — no claro continua branco, no escuro acompanha o tema.
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          // Botão de voltar (seta normal) no lugar antes ocupado pelo
          // hambúrguer — o ícone anterior (exit_to_app) se confundia com o
          // de logout.
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/home?tab=more');
              }
            },
            tooltip: 'Voltar',
          ),
          actions: [
            // Botão de configurar Dashboard: admin/leader com
            // dashboard.configure vai pra config geral do tenant; qualquer
            // outro usuário com acesso ao Dashboard vai pra tela pessoal
            // (CHU-308).
            IconButton(
              icon: const Icon(AppIcons.settings),
              onPressed: () => _openDashboardSettings(context),
              tooltip: 'Configurar Dashboard',
            ),
            const NotificationBadge(),
            const SizedBox(width: 8),
          ],
        ),
        // G1: a gestão sai da barra de baixo (Pessoas, Ministérios, logo da
        // igreja), no vidro da Home; os cards ficam por trás dela.
        extendBody: true,
        bottomNavigationBar: _buildDock(context),
        // B6: o Leitor de QR Code flutua sobre o corpo, arrastável, só para
        // quem tem events.checkin.
        body: Stack(
          children: [
            _buildBody(context),
            const PermissionGate(
              permission: 'events.checkin',
              showLoading: false,
              child: QrScannerFab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ref
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
                          Icon(AppIcons.widgets, size: 64, color: Colors.grey),
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
                    ref.read(refreshDashboardWidgetsProvider)();
                    // B4: os gráficos dos relatórios ficam em cache pela sessão.
                    ref.invalidate(customReportDataProvider);
                  },
                  child: SingleChildScrollView(
                    // o fim da rolagem passa da barra de baixo
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // B7: 1/2/3 colunas pela faixa de largura; no
                        // celular continua a pilha de sempre.
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 16.0;
                            final cols = gridColumns(constraints.maxWidth);
                            final cardWidth =
                                (constraints.maxWidth - gap * (cols - 1)) /
                                    cols;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final widget in widgets)
                                  SizedBox(
                                    width: cardWidth,
                                    // B2: moldura com rolagem/expandir em
                                    // tablet/PC; no celular passa direto.
                                    child: DashboardCardFrame(
                                      widgetKey: widget.widgetKey,
                                      child: _buildWidgetByKey(
                                        context,
                                        widget.widgetKey,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              // A tela de erro precisa oferecer saída: sem retry e sem scroll
              // o usuário ficava preso nela, já que o RefreshIndicator só
              // existia no ramo de sucesso.
              error: (error, _) => RefreshIndicator(
                onRefresh: () async {
                  ref.read(refreshDashboardWidgetsProvider)();
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              AppIcons.error,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Erro ao carregar widgets',
                              style: TextStyle(
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
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () =>
                                  ref.read(refreshDashboardWidgetsProvider)(),
                              icon: const Icon(AppIcons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
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
      // B4: card com o gráfico do relatório (só título sem acesso à fonte).
      return CustomReportDashboardCard(reportId: reportId);
    }

    // O card abre o relatório só para quem tem reports.view (senão, Acesso Negado).
    Widget toReport(String route, Widget card) => PermissionGate(
          permission: 'reports.view',
          showLoading: false,
          fallback: card,
          child: InkWell(onTap: () => context.push(route), child: card),
        );

    // Widgets padrão
    final widgetMap = {
      'birthdays_month': toReport(
        '/reports/members?tab=birthdays',
        const BirthdaysThisMonthCard(),
      ),
      'recent_members': toReport(
        '/reports/members?tab=recent',
        const RecentMembersCard(),
      ),
      // o card abre o relatório dele (rota com a permissão do card)
      'upcoming_events': const UpcomingEventsCard(),
      'upcoming_expenses': InkWell(
        onTap: () => context.push('/financial-reports?tab=expenses'),
        child: const UpcomingExpensesCard(),
      ),
      // o card abre o relatório dele (rota com a permissão do card)
      'member_growth': const MemberGrowthChart(),
      // o card abre o relatório dele (rota com a permissão do card)
      'events_stats': const EventsStatsCard(),
      // o card abre o relatório dele (rota com a permissão do card)
      'top_active_groups': const TopActiveGroupsCard(),
      'average_attendance': toReport(
        '/reports/attendance',
        const AverageAttendanceCard(),
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
      // B3: cada item abre o seu destino; o card de ausentes abre o Check-in.
      'updates_feed': const UpdatesFeedCard(),
      'absent_last_culto': const AbsentLastCultoCard(),
    };

    return widgetMap[widgetKey] ?? const SizedBox.shrink();
  }

  /// G1 (opção B do usuário): sem item selecionado — os cards são o fundo e
  /// cada item abre a sua tela por cima. Pessoas e Ministérios somem sem
  /// permissão; a logo (perfil da igreja) aparece para todos daqui.
  Widget _buildDock(BuildContext context) {
    final pending = ref.watch(pendingLinkCountProvider).valueOrNull ?? 0;
    final church = ref.watch(churchInfoProvider).valueOrNull;
    final entries = <(PremiumNavItem, String)>[
      if (managementCategoryVisible(ref, kPeopleMenu) == true)
        (
          PremiumNavItem(
            label: 'Pessoas',
            activeColor: AppTheme.primary,
            iconBuilder: (context, _, __) => CountBadge(
              count: pending,
              child: const Icon(
                Icons.groups_outlined,
                size: 23,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
          '/dashboard/pessoas',
        ),
      if (managementCategoryVisible(ref, kMinistriesMenu) == true)
        (
          const PremiumNavItem(
            label: 'Ministérios',
            icon: Icons.church_outlined,
            activeColor: AppTheme.primary,
          ),
          '/dashboard/ministerios',
        ),
      (
        PremiumNavItem(
          label: 'Igreja',
          activeColor: AppTheme.primary,
          iconBuilder: (context, _, __) => ClipOval(
            child: SizedBox.square(
              dimension: 28,
              child: ChurchLogo(
                url: church?.logoUrl,
                name: church?.name ?? '',
              ),
            ),
          ),
        ),
        '/dashboard/igreja',
      ),
    ];
    return PremiumBottomNavBar(
      currentIndex: -1,
      items: [for (final (item, _) in entries) item],
      onTap: (i) => context.push(entries[i].$2),
    );
  }

  Future<void> _openDashboardSettings(BuildContext context) async {
    final canConfigureTenant = await ref.read(
      currentUserHasPermissionProvider('dashboard.configure').future,
    );
    if (!context.mounted) return;
    context.push(
      canConfigureTenant
          ? '/dashboard-settings'
          : '/dashboard-settings/personal',
    );
  }
}
