import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';

/// Tela de estatísticas de visitantes
class VisitorsStatisticsScreen extends ConsumerStatefulWidget {
  const VisitorsStatisticsScreen({super.key});

  @override
  ConsumerState<VisitorsStatisticsScreen> createState() => _VisitorsStatisticsScreenState();
}

class _VisitorsStatisticsScreenState extends ConsumerState<VisitorsStatisticsScreen> {
  String _selectedPeriod = '30'; // dias

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(allVisitorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas de Visitantes'),
      ),
      body: visitorsAsync.when(
        data: (visitors) {
          // Filtrar por período
          final now = DateTime.now();
          final filteredVisitors = _selectedPeriod == 'all'
              ? visitors
              : visitors.where((v) {
                  final days = int.parse(_selectedPeriod);
                  final cutoffDate = now.subtract(Duration(days: days));
                  return v.firstVisitDate?.isAfter(cutoffDate) ?? false;
                }).toList();

          // Calcular estatísticas
          final totalVisitors = filteredVisitors.length;
          final totalVisits = filteredVisitors.fold<int>(
            0,
            (sum, v) => sum + v.totalVisits,
          );
          final avgVisitsPerVisitor = totalVisitors > 0 ? totalVisits / totalVisitors : 0.0;

          // Contar por status
          final statusCounts = <VisitorStatus, int>{};
          for (final visitor in filteredVisitors) {
            statusCounts[visitor.status] = (statusCounts[visitor.status] ?? 0) + 1;
          }

          // Contar por "como conheceu"
          final howFoundCounts = <HowFoundChurch, int>{};
          for (final visitor in filteredVisitors) {
            if (visitor.howFound != null) {
              howFoundCounts[visitor.howFound!] = (howFoundCounts[visitor.howFound!] ?? 0) + 1;
            }
          }

          // Visitantes recentes (últimos 30 dias)
          final recentCount = visitors.where((v) {
            final cutoffDate = now.subtract(const Duration(days: 30));
            return v.firstVisitDate?.isAfter(cutoffDate) ?? false;
          }).length;

          // Visitantes inativos (sem visita há mais de 60 dias)
          final inactiveCount = visitors.where((v) {
            if (v.lastVisitDate == null) return false;
            final cutoffDate = now.subtract(const Duration(days: 60));
            return v.lastVisitDate!.isBefore(cutoffDate);
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filtros de Período
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PeriodChip(
                      label: '7 dias',
                      value: '7',
                      selected: _selectedPeriod == '7',
                      onSelected: () => setState(() => _selectedPeriod = '7'),
                    ),
                    const SizedBox(width: 8),
                    _PeriodChip(
                      label: '30 dias',
                      value: '30',
                      selected: _selectedPeriod == '30',
                      onSelected: () => setState(() => _selectedPeriod = '30'),
                    ),
                    const SizedBox(width: 8),
                    _PeriodChip(
                      label: '90 dias',
                      value: '90',
                      selected: _selectedPeriod == '90',
                      onSelected: () => setState(() => _selectedPeriod = '90'),
                    ),
                    const SizedBox(width: 8),
                    _PeriodChip(
                      label: 'Este ano',
                      value: '365',
                      selected: _selectedPeriod == '365',
                      onSelected: () => setState(() => _selectedPeriod = '365'),
                    ),
                    const SizedBox(width: 8),
                    _PeriodChip(
                      label: 'Todo período',
                      value: 'all',
                      selected: _selectedPeriod == 'all',
                      onSelected: () => setState(() => _selectedPeriod = 'all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cards de Resumo
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total de Visitantes',
                      value: totalVisitors.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Total de Visitas',
                      value: totalVisits.toString(),
                      icon: Icons.event,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Média de Visitas',
                      value: avgVisitsPerVisitor.toStringAsFixed(1),
                      icon: Icons.analytics,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Novos (30 dias)',
                      value: recentCount.toString(),
                      icon: Icons.new_releases,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Inativos (60+ dias)',
                      value: inactiveCount.toString(),
                      icon: Icons.warning,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Convertidos',
                      value: (statusCounts[VisitorStatus.converted] ?? 0).toString(),
                      icon: Icons.check_circle,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Gráfico de Pizza - Status
              if (statusCounts.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visitantes por Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sections: statusCounts.entries.map((entry) {
                                final percentage = (entry.value / totalVisitors) * 100;
                                return PieChartSectionData(
                                  value: entry.value.toDouble(),
                                  title: '${percentage.toStringAsFixed(1)}%',
                                  color: _getStatusColor(entry.key),
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: statusCounts.entries.map((entry) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.key.label}: ${entry.value}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Gráfico de Barras - Como Conheceu
              if (howFoundCounts.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Como Conheceram a Igreja',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: howFoundCounts.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                              barGroups: howFoundCounts.entries.toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final data = entry.value;
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: data.value.toDouble(),
                                      color: Colors.blue,
                                      width: 20,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 12),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < howFoundCounts.length) {
                                        final label = howFoundCounts.keys.toList()[index].label;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            label.length > 10 ? '${label.substring(0, 10)}...' : label,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erro ao carregar estatísticas: $error'),
        ),
      ),
    );
  }

  Color _getStatusColor(VisitorStatus status) {
    switch (status) {
      case VisitorStatus.firstVisit:
        return Colors.blue;
      case VisitorStatus.returning:
        return Colors.orange;
      case VisitorStatus.regular:
        return Colors.green;
      case VisitorStatus.converted:
        return Colors.purple;
      case VisitorStatus.inactive:
        return Colors.grey;
    }
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
