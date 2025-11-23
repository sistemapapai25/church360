import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';

/// Enum para períodos de filtro
enum GrowthPeriod {
  last7Days('Últimos 7 dias'),
  last15Days('Últimos 15 dias'),
  last30Days('Últimos 30 dias'),
  last60Days('Últimos 60 dias'),
  last90Days('Últimos 90 dias'),
  custom('Personalizado');

  final String label;
  const GrowthPeriod(this.label);
}

/// Provider para crescimento de membros por período (dia a dia)
final memberGrowthByPeriodProvider = FutureProvider.family<List<Map<String, dynamic>>, (DateTime, DateTime)>(
  (ref, dates) async {
    final supabase = ref.watch(supabaseClientProvider);
    final (startDate, endDate) = dates;

    // Buscar todos os membros criados até a data final
    final response = await supabase
        .from('user_account')
        .select('created_at, status')
        .inFilter('status', ['member_active', 'member_inactive']) // Apenas membros
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: true);

    final members = response as List;

    // Criar mapa de contagem por dia
    final Map<String, int> dayCounts = {};
    
    // Inicializar todos os dias do período com 0
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (currentDate.isBefore(endDateOnly) || currentDate.isAtSameMomentAs(endDateOnly)) {
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      dayCounts[dateKey] = 0;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Contar membros criados em cada dia do período
    for (var member in members) {
      final createdAt = DateTime.parse(member['created_at'] as String);
      final createdDateOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final dateKey = DateFormat('yyyy-MM-dd').format(createdDateOnly);
      
      // Só contar se estiver dentro do período
      if (dayCounts.containsKey(dateKey)) {
        dayCounts[dateKey] = (dayCounts[dateKey] ?? 0) + 1;
      }
    }

    // Calcular total acumulado até o início do período
    int accumulatedBeforePeriod = 0;
    for (var member in members) {
      final createdAt = DateTime.parse(member['created_at'] as String);
      if (createdAt.isBefore(startDate)) {
        accumulatedBeforePeriod++;
      }
    }

    // Converter para lista ordenada com total acumulado
    int accumulated = accumulatedBeforePeriod;
    final result = dayCounts.entries.map((entry) {
      final newMembers = entry.value;
      accumulated += newMembers;
      
      final date = DateTime.parse(entry.key);
      return {
        'date': entry.key,
        'dateObj': date,
        'day': date.day,
        'month': date.month,
        'year': date.year,
        'newMembers': newMembers,
        'totalMembers': accumulated,
      };
    }).toList();

    result.sort((a, b) => (a['dateObj'] as DateTime).compareTo(b['dateObj'] as DateTime));

    return result;
  },
);

/// Tela de relatório de crescimento de membros
class MemberGrowthReportScreen extends ConsumerStatefulWidget {
  const MemberGrowthReportScreen({super.key});

  @override
  ConsumerState<MemberGrowthReportScreen> createState() =>
      _MemberGrowthReportScreenState();
}

class _MemberGrowthReportScreenState
    extends ConsumerState<MemberGrowthReportScreen> {
  GrowthPeriod _selectedPeriod = GrowthPeriod.last30Days;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();
    final growthAsync = ref.watch(memberGrowthByPeriodProvider((startDate, endDate)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crescimento de Membros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(memberGrowthByPeriodProvider);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de Período
          _buildPeriodFilter(),

          // Gráfico e Estatísticas
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(memberGrowthByPeriodProvider);
              },
              child: growthAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Sem dados para exibir',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  final totalAtStart = (data.first['totalMembers'] as int) - (data.first['newMembers'] as int);
                  final totalAtEnd = data.last['totalMembers'] as int;
                  final totalNew = data.map((d) => d['newMembers'] as int).reduce((a, b) => a + b);
                  final growth = totalAtEnd - totalAtStart;
                  final growthPercentage = totalAtStart > 0 
                      ? ((growth / totalAtStart) * 100).toStringAsFixed(1)
                      : '0.0';

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Cards de Resumo
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Atual',
                              '$totalAtEnd',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Novos Membros',
                              '+$totalNew',
                              Icons.person_add,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Crescimento',
                              growth >= 0 ? '+$growth' : '$growth',
                              growth >= 0 ? Icons.trending_up : Icons.trending_down,
                              growth >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Percentual',
                              '${growth >= 0 ? '+' : ''}$growthPercentage%',
                              Icons.percent,
                              growth >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Gráfico de Crescimento
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total de Membros (Acumulado)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 250,
                                child: _buildLineChart(data),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Gráfico de Novos Membros por Dia
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Novos Membros por Dia',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: _buildBarChart(data),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tabela de Dados
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detalhamento Diário',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildDataTable(data),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro: $error'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de resumo
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Gráfico de linha (total acumulado)
  Widget _buildLineChart(List<Map<String, dynamic>> data) {
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['totalMembers'] as int).toDouble(),
      );
    }).toList();

    final maxY = data.map((d) => d['totalMembers'] as int).reduce((a, b) => a > b ? a : b);
    final minY = data.map((d) => d['totalMembers'] as int).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: data.length > 10 ? (data.length / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const Text('');
                final date = data[index]['dateObj'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: (minY - 2).toDouble(),
        maxY: (maxY + 2).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 31,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// Gráfico de barras (novos membros por dia)
  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (data.map((d) => d['newMembers'] as int).reduce((a, b) => a > b ? a : b) + 1).toDouble(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: data.length > 10 ? (data.length / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const Text('');
                final date = data[index]['dateObj'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value['newMembers'] as int).toDouble(),
                color: Colors.green,
                width: data.length > 31 ? 4 : 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Tabela de dados
  Widget _buildDataTable(List<Map<String, dynamic>> data) {
    final dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');
    
    // Mostrar apenas os últimos 10 dias
    final displayData = data.reversed.take(10).toList();

    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Data', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Novos', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ],
        ),
        ...displayData.map((row) {
          final date = row['dateObj'] as DateTime;
          final newMembers = row['newMembers'] as int;
          final totalMembers = row['totalMembers'] as int;

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(dateFormatter.format(date)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  newMembers > 0 ? '+$newMembers' : '$newMembers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: newMembers > 0 ? Colors.green : Colors.grey,
                    fontWeight: newMembers > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$totalMembers',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Retorna o intervalo de datas baseado no período selecionado
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriod) {
      case GrowthPeriod.last7Days:
        return (today.subtract(const Duration(days: 6)), today);
      case GrowthPeriod.last15Days:
        return (today.subtract(const Duration(days: 14)), today);
      case GrowthPeriod.last30Days:
        return (today.subtract(const Duration(days: 29)), today);
      case GrowthPeriod.last60Days:
        return (today.subtract(const Duration(days: 59)), today);
      case GrowthPeriod.last90Days:
        return (today.subtract(const Duration(days: 89)), today);
      case GrowthPeriod.custom:
        return (
          _customStartDate ?? today.subtract(const Duration(days: 29)),
          _customEndDate ?? today,
        );
    }
  }

  /// Filtro de período
  Widget _buildPeriodFilter() {
    return Card(
      margin: const EdgeInsets.all(16),
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
              children: GrowthPeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == GrowthPeriod.custom) {
                        _showCustomDatePicker();
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostrar seletor de datas personalizado
  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final startDate = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? today.subtract(const Duration(days: 29)),
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Data Inicial',
    );

    if (startDate != null && mounted) {
      final endDate = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? today,
        firstDate: startDate,
        lastDate: today,
        helpText: 'Data Final',
      );

      if (endDate != null && mounted) {
        setState(() {
          _customStartDate = startDate;
          _customEndDate = endDate;
        });
      }
    }
  }
}
