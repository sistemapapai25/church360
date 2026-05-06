// =====================================================
// CHURCH 360 - FINANCIAL DASHBOARD SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/dashboard_data.dart';
import '../../domain/models/lancamento.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

class FinanceiroDashboardScreen extends ConsumerStatefulWidget {
  const FinanceiroDashboardScreen({super.key});

  @override
  ConsumerState<FinanceiroDashboardScreen> createState() => _FinanceiroDashboardScreenState();
}

class _FinanceiroDashboardScreenState extends ConsumerState<FinanceiroDashboardScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  DateTime? _startDate;
  DateTime? _endDate;

  double _saldoTotalAtual(DashboardData dashboard) {
    return dashboard.saldosPorConta.fold(0.0, (sum, item) => sum + item.saldo);
  }

  String _formatPeriodLabel() {
    if (_startDate == null || _endDate == null) return 'Mês atual';
    final fmt = DateFormat('dd/MM/yyyy');
    return '${fmt.format(_startDate!)} - ${fmt.format(_endDate!)}';
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final initialEnd = _endDate ?? DateTime(now.year, now.month + 1, 0);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  void _openLancamentos({
    TipoLancamento? tipo,
    StatusLancamento? status,
  }) {
    final qp = <String, String>{};
    if (_startDate != null) {
      qp['start'] = _startDate!.toIso8601String().split('T')[0];
    }
    if (_endDate != null) {
      qp['end'] = _endDate!.toIso8601String().split('T')[0];
    }
    if (tipo != null) qp['tipo'] = tipo.value;
    if (status != null) qp['status'] = status.value;
    final uri = Uri(path: '/financial/lancamentos', queryParameters: qp);
    context.push(uri.toString());
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Builder(
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildDesktopLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Financeiro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrar período',
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickPeriod,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/financial/lancamentos/new'),
          ),
        ],
      ),
      body: _buildDashboardContent(),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Financeiro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _pickPeriod,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(_formatPeriodLabel()),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/financial/lancamentos/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Lançamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _financialGreen,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _buildDashboardContent(),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final dashboardAsync = (_startDate != null || _endDate != null)
        ? ref.watch(
            dashboardDataByPeriodProvider(
              DashboardPeriodFilter(startDate: _startDate, endDate: _endDate),
            ),
          )
        : ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (dashboard) => _buildDashboardLoaded(dashboard),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppErrorHandler.userMessage(
                error,
                feature: 'finance.dashboard.load',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(dashboardDataProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardLoaded(DashboardData dashboard) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cards de resumo
          _buildSummaryCards(dashboard),
          const SizedBox(height: 24),

          // Previsão do mês (ZeroPaper-style: previsto vs realizado)
          _buildMonthlyForecastCard(dashboard),
          const SizedBox(height: 24),

          // Ações rápidas
          _buildQuickActions(),
          const SizedBox(height: 24),

          // Lançamentos vencidos (se houver)
          if (dashboard.temLancamentosVencidos) ...[
            _buildVencidosAlert(dashboard),
            const SizedBox(height: 24),
          ],

          // Gráficos/Listas
          _buildChartsSection(dashboard),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(DashboardData dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final crossAxisCount = isDesktop ? 4 : 2;
        final saldoTotal = _saldoTotalAtual(dashboard);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.5 : 1.3,
          children: [
            _buildSummaryCard(
              title: 'Recebidas',
              value: _currencyFormat.format(dashboard.receitasRecebidas),
              icon: Icons.arrow_upward,
              color: Colors.green,
              onTap: () => _openLancamentos(
                tipo: TipoLancamento.receita,
                status: StatusLancamento.pago,
              ),
            ),
            _buildSummaryCard(
              title: 'Pagas',
              value: _currencyFormat.format(dashboard.despesasPagas),
              icon: Icons.arrow_downward,
              color: Colors.red,
              onTap: () => _openLancamentos(
                tipo: TipoLancamento.despesa,
                status: StatusLancamento.pago,
              ),
            ),
            _buildSummaryCard(
              title: 'Saldo Atual',
              value: _currencyFormat.format(saldoTotal),
              icon: saldoTotal >= 0 ? Icons.trending_up : Icons.trending_down,
              color: saldoTotal >= 0 ? _financialGreen : Colors.orange,
              onTap: () => context.push('/financial/contas'),
            ),
            _buildSummaryCard(
              title: 'Em Aberto',
              value: '${dashboard.lancamentosEmAberto}',
              icon: Icons.pending_actions,
              color: Colors.blue,
              onTap: () => _openLancamentos(status: StatusLancamento.emAberto),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyForecastCard(DashboardData dashboard) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Previsão do mês', style: CommunityDesign.titleStyle(context)),
              Text(
                'Previsto: ${_currencyFormat.format(dashboard.saldoPrevisto)}',
                style: CommunityDesign.metaStyle(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildForecastMini(
                  title: 'Receitas',
                  topLabel: 'Previstas',
                  topValue: dashboard.receitasPrevistas,
                  bottomLabel: 'Recebidas',
                  bottomValue: dashboard.receitasRecebidas,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildForecastMini(
                  title: 'Despesas',
                  topLabel: 'Previstas',
                  topValue: dashboard.despesasPrevistas,
                  bottomLabel: 'Pagas',
                  bottomValue: dashboard.despesasPagas,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo realizado: ${_currencyFormat.format(dashboard.saldoRealizado)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Variação: ${dashboard.variacaoPrevistoVsRealizado.toStringAsFixed(1)}%',
                style: CommunityDesign.metaStyle(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastMini({
    required String title,
    required String topLabel,
    required double topValue,
    required String bottomLabel,
    required double bottomValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('$topLabel: ${_currencyFormat.format(topValue)}', style: CommunityDesign.metaStyle(context)),
          const SizedBox(height: 4),
          Text('$bottomLabel: ${_currencyFormat.format(bottomValue)}', style: CommunityDesign.metaStyle(context)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CommunityDesign.radius),
      child: Container(
        decoration: CommunityDesign.overlayDecoration(colorScheme),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: CommunityDesign.metaStyle(context),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas',
          style: CommunityDesign.titleStyle(context),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildQuickActionButton(
              label: 'Lançamentos',
              icon: Icons.list_alt,
              onTap: () => context.push('/financial/lancamentos'),
            ),
            _buildQuickActionButton(
              label: 'Categorias',
              icon: Icons.category,
              onTap: () => context.push('/financial/categorias'),
            ),
            _buildQuickActionButton(
              label: 'Contas',
              icon: Icons.account_balance,
              onTap: () => context.push('/financial/contas'),
            ),
            _buildQuickActionButton(
              label: 'Extrato',
              icon: Icons.receipt_long,
              onTap: () => context.push('/financial/extrato'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // final colorScheme = Theme.of(context).colorScheme; // Unused for now

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _financialGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _financialGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _financialGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: _financialGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVencidosAlert(DashboardData dashboard) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atenção!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  'Você tem ${dashboard.lancamentosVencidos} lançamento(s) vencido(s)',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/financial/lancamentos?filter=vencidos'),
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(DashboardData dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo por Categoria',
          style: CommunityDesign.titleStyle(context),
        ),
        const SizedBox(height: 12),
        _buildCategoriesLists(dashboard),
      ],
    );
  }

  Widget _buildCategoriesLists(DashboardData dashboard) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildReceitasList(dashboard, colorScheme)),
              const SizedBox(width: 16),
              Expanded(child: _buildDespesasList(dashboard, colorScheme)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildReceitasList(dashboard, colorScheme),
              const SizedBox(height: 16),
              _buildDespesasList(dashboard, colorScheme),
            ],
          );
        }
      },
    );
  }

  Widget _buildReceitasList(DashboardData dashboard, ColorScheme colorScheme) {
    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Receitas por Categoria',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dashboard.receitasPorCategoria.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nenhuma receita registrada', style: TextStyle(fontSize: 13)),
            )
          else
            ...dashboard.receitasPorCategoria.map((receita) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        receita.categoriaNome,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(receita.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDespesasList(DashboardData dashboard, ColorScheme colorScheme) {
    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_downward, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Despesas por Categoria',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dashboard.despesasPorCategoria.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nenhuma despesa registrada', style: TextStyle(fontSize: 13)),
            )
          else
            ...dashboard.despesasPorCategoria.map((despesa) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        despesa.categoriaNome,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(despesa.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
