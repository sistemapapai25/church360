// =====================================================
// CHURCH 360 - FINANCIAL DASHBOARD SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/dashboard_data.dart';
import '../../../../core/design/community_design.dart';

class FinanceiroDashboardScreen extends ConsumerStatefulWidget {
  const FinanceiroDashboardScreen({super.key});

  @override
  ConsumerState<FinanceiroDashboardScreen> createState() => _FinanceiroDashboardScreenState();
}

class _FinanceiroDashboardScreenState extends ConsumerState<FinanceiroDashboardScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (dashboard) => _buildDashboardLoaded(dashboard),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar dashboard: $error'),
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

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.5 : 1.3,
          children: [
            _buildSummaryCard(
              title: 'Receitas',
              value: _currencyFormat.format(dashboard.totalReceitas),
              icon: Icons.arrow_upward,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Despesas',
              value: _currencyFormat.format(dashboard.totalDespesas),
              icon: Icons.arrow_downward,
              color: Colors.red,
            ),
            _buildSummaryCard(
              title: 'Saldo',
              value: _currencyFormat.format(dashboard.saldo),
              icon: dashboard.temSaldoPositivo ? Icons.trending_up : Icons.trending_down,
              color: dashboard.temSaldoPositivo ? _financialGreen : Colors.orange,
            ),
            _buildSummaryCard(
              title: 'Em Aberto',
              value: '${dashboard.lancamentosEmAberto}',
              icon: Icons.pending_actions,
              color: Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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

