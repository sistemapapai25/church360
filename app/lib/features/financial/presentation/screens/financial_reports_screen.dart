import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../domain/models/contribution.dart';
import '../providers/financial_provider.dart';

/// Enum para períodos de filtro
enum ReportPeriod {
  thisMonth('Este Mês'),
  lastMonth('Último Mês'),
  last3Months('Últimos 3 Meses'),
  last6Months('Últimos 6 Meses'),
  thisYear('Este Ano'),
  lastYear('Ano Passado'),
  custom('Personalizado');

  final String label;
  const ReportPeriod(this.label);
}

/// Tela de relatórios financeiros
class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState
    extends ConsumerState<FinancialReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Financeiros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Exportar Relatório',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filtro de Período
          _buildPeriodFilter(),
          const SizedBox(height: 24),

          // Cards de Resumo
          _buildSummaryCards(startDate, endDate),
          const SizedBox(height: 24),

          // Gráfico de Receitas vs Despesas
          _buildRevenueExpenseChart(startDate, endDate),
          const SizedBox(height: 24),

          // Gráfico de Tendência
          _buildTrendChart(startDate, endDate),
          const SizedBox(height: 24),

          // Top Contribuintes
          _buildTopContributors(startDate, endDate),
          const SizedBox(height: 24),

          // Despesas por Categoria
          _buildExpensesByCategory(startDate, endDate),
        ],
      ),
    );
  }

  /// Retorna o intervalo de datas baseado no período selecionado
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case ReportPeriod.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0),
        );
      case ReportPeriod.lastMonth:
        return (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        );
      case ReportPeriod.last3Months:
        return (
          DateTime(now.year, now.month - 3, 1),
          now,
        );
      case ReportPeriod.last6Months:
        return (
          DateTime(now.year, now.month - 6, 1),
          now,
        );
      case ReportPeriod.thisYear:
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31),
        );
      case ReportPeriod.lastYear:
        return (
          DateTime(now.year - 1, 1, 1),
          DateTime(now.year - 1, 12, 31),
        );
      case ReportPeriod.custom:
        return (
          _customStartDate ?? DateTime(now.year, now.month, 1),
          _customEndDate ?? now,
        );
    }
  }

  /// Filtro de período
  Widget _buildPeriodFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReportPeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == ReportPeriod.custom) {
                        _showCustomDatePicker();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedPeriod == ReportPeriod.custom &&
                _customStartDate != null &&
                _customEndDate != null) ...[
              const SizedBox(height: 12),
              Text(
                'De ${DateFormat('dd/MM/yyyy').format(_customStartDate!)} até ${DateFormat('dd/MM/yyyy').format(_customEndDate!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Cards de resumo
  Widget _buildSummaryCards(DateTime startDate, DateTime endDate) {
    final contributionsAsync = ref.watch(allContributionsProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    return contributionsAsync.when(
      data: (contributions) {
        return expensesAsync.when(
          data: (expenses) {
            // Filtrar por período
            final filteredContributions = contributions.where((c) {
              return c.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  c.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            final filteredExpenses = expenses.where((e) {
              return e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  e.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            final totalRevenue = filteredContributions.fold<double>(
              0,
              (sum, c) => sum + c.amount,
            );

            final totalExpenses = filteredExpenses.fold<double>(
              0,
              (sum, e) => sum + e.amount,
            );

            final balance = totalRevenue - totalExpenses;

            final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

            return Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Receitas',
                    value: formatter.format(totalRevenue),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Despesas',
                    value: formatter.format(totalExpenses),
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Saldo',
                    value: formatter.format(balance),
                    icon: balance >= 0 ? Icons.check_circle : Icons.warning,
                    color: balance >= 0 ? Colors.blue : Colors.orange,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  /// Gráfico de Receitas vs Despesas
  Widget _buildRevenueExpenseChart(DateTime startDate, DateTime endDate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receitas vs Despesas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _RevenueExpenseBarChart(
                startDate: startDate,
                endDate: endDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gráfico de Tendência
  Widget _buildTrendChart(DateTime startDate, DateTime endDate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tendência de Saldo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _TrendLineChart(
                startDate: startDate,
                endDate: endDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Contribuintes
  Widget _buildTopContributors(DateTime startDate, DateTime endDate) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Contribuintes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('Em desenvolvimento...'),
          ],
        ),
      ),
    );
  }

  /// Despesas por Categoria
  Widget _buildExpensesByCategory(DateTime startDate, DateTime endDate) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Despesas por Categoria',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('Em desenvolvimento...'),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Selecione a data inicial',
    );

    if (startDate == null) return;

    if (!mounted) return;

    final endDate = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? now,
      firstDate: startDate,
      lastDate: now,
      helpText: 'Selecione a data final',
    );

    if (endDate == null) return;

    setState(() {
      _customStartDate = startDate;
      _customEndDate = endDate;
    });
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exportação em desenvolvimento...'),
      ),
    );
  }
}

/// Card de resumo
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de barras de Receitas vs Despesas
class _RevenueExpenseBarChart extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _RevenueExpenseBarChart({
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(allContributionsProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    return contributionsAsync.when(
      data: (contributions) {
        return expensesAsync.when(
          data: (expenses) {
            // Filtrar por período
            final filteredContributions = contributions.where((c) {
              return c.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  c.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            final filteredExpenses = expenses.where((e) {
              return e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  e.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            // Agrupar por mês
            final Map<String, double> revenueByMonth = {};
            final Map<String, double> expensesByMonth = {};

            for (final contribution in filteredContributions) {
              final monthKey = DateFormat('MM/yyyy').format(contribution.date);
              revenueByMonth[monthKey] = (revenueByMonth[monthKey] ?? 0) + contribution.amount;
            }

            for (final expense in filteredExpenses) {
              final monthKey = DateFormat('MM/yyyy').format(expense.date);
              expensesByMonth[monthKey] = (expensesByMonth[monthKey] ?? 0) + expense.amount;
            }

            // Combinar todas as chaves de meses
            final allMonths = {...revenueByMonth.keys, ...expensesByMonth.keys}.toList()..sort();

            if (allMonths.isEmpty) {
              return const Center(
                child: Text('Nenhum dado disponível para o período selecionado'),
              );
            }

            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(revenueByMonth, expensesByMonth),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final monthKey = allMonths[group.x.toInt()];
                      final value = rod.toY;
                      final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                      return BarTooltipItem(
                        '$monthKey\n${formatter.format(value)}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= allMonths.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            allMonths[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact(locale: 'pt_BR').format(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(allMonths.length, (index) {
                  final monthKey = allMonths[index];
                  final revenue = revenueByMonth[monthKey] ?? 0;
                  final expense = expensesByMonth[monthKey] ?? 0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenue,
                        color: Colors.green,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: expense,
                        color: Colors.red,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxY(revenueByMonth, expensesByMonth) / 5,
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  double _getMaxY(Map<String, double> revenue, Map<String, double> expenses) {
    final maxRevenue = revenue.values.isEmpty ? 0.0 : revenue.values.reduce((a, b) => a > b ? a : b);
    final maxExpense = expenses.values.isEmpty ? 0.0 : expenses.values.reduce((a, b) => a > b ? a : b);
    final max = maxRevenue > maxExpense ? maxRevenue : maxExpense;
    return max * 1.2; // 20% de margem
  }
}

/// Gráfico de linha de tendência
class _TrendLineChart extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _TrendLineChart({
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(allContributionsProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    return contributionsAsync.when(
      data: (contributions) {
        return expensesAsync.when(
          data: (expenses) {
            // Filtrar por período
            final filteredContributions = contributions.where((c) {
              return c.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  c.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            final filteredExpenses = expenses.where((e) {
              return e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  e.date.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();

            // Agrupar por mês e calcular saldo acumulado
            final Map<String, double> balanceByMonth = {};

            for (final contribution in filteredContributions) {
              final monthKey = DateFormat('MM/yyyy').format(contribution.date);
              balanceByMonth[monthKey] = (balanceByMonth[monthKey] ?? 0) + contribution.amount;
            }

            for (final expense in filteredExpenses) {
              final monthKey = DateFormat('MM/yyyy').format(expense.date);
              balanceByMonth[monthKey] = (balanceByMonth[monthKey] ?? 0) - expense.amount;
            }

            final sortedMonths = balanceByMonth.keys.toList()..sort();

            if (sortedMonths.isEmpty) {
              return const Center(
                child: Text('Nenhum dado disponível para o período selecionado'),
              );
            }

            // Calcular saldo acumulado
            double accumulatedBalance = 0;
            final List<FlSpot> spots = [];

            for (int i = 0; i < sortedMonths.length; i++) {
              accumulatedBalance += balanceByMonth[sortedMonths[i]]!;
              spots.add(FlSpot(i.toDouble(), accumulatedBalance));
            }

            final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
            final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

            return LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedMonths.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            sortedMonths[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact(locale: 'pt_BR').format(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final monthKey = sortedMonths[spot.x.toInt()];
                        final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                        return LineTooltipItem(
                          '$monthKey\n${formatter.format(spot.y)}',
                          const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: minY < 0 ? minY * 1.2 : 0,
                maxY: maxY * 1.2,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

