import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/worship_provider.dart';
import '../../domain/models/worship_service.dart';
import '../../../../core/design/community_design.dart';

/// Tela de estatísticas de cultos
class WorshipStatisticsScreen extends ConsumerStatefulWidget {
  const WorshipStatisticsScreen({super.key});

  @override
  ConsumerState<WorshipStatisticsScreen> createState() =>
      _WorshipStatisticsScreenState();
}

class _WorshipStatisticsScreenState
    extends ConsumerState<WorshipStatisticsScreen> {
  String _selectedPeriod = 'last_30_days';

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'last_7_days':
        return now.subtract(const Duration(days: 7));
      case 'last_30_days':
        return now.subtract(const Duration(days: 30));
      case 'last_90_days':
        return now.subtract(const Duration(days: 90));
      case 'this_year':
        return DateTime(now.year, 1, 1);
      case 'all_time':
        return DateTime(2020, 1, 1);
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allWorshipServicesProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Estatísticas de Cultos',
          style: CommunityDesign.titleStyle(context),
        ),
      ),
      body: servicesAsync.when(
        data: (allServices) {
          // Filter by period
          final startDate = _getStartDate();
          final services = allServices
              .where((s) => s.serviceDate.isAfter(startDate))
              .toList();

          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum culto no período selecionado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Period Filter
              _buildPeriodFilter(),
              const SizedBox(height: 24),

              // Summary Cards
              _buildSummaryCards(services),
              const SizedBox(height: 24),

              // Attendance Trend Chart
              _buildAttendanceTrendCard(services),
              const SizedBox(height: 24),

              // Attendance by Type Chart
              _buildAttendanceByTypeCard(services),
              const SizedBox(height: 24),

              // Average Attendance by Day of Week
              _buildAverageByDayOfWeekCard(services),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar estatísticas: $error'),
            ],
          ),
        ),
      ),
    );
  }

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
              children: [
                _buildPeriodChip('Últimos 7 dias', 'last_7_days'),
                _buildPeriodChip('Últimos 30 dias', 'last_30_days'),
                _buildPeriodChip('Últimos 90 dias', 'last_90_days'),
                _buildPeriodChip('Este ano', 'this_year'),
                _buildPeriodChip('Todo período', 'all_time'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
          });
        }
      },
    );
  }

  Widget _buildSummaryCards(List<WorshipService> services) {
    final totalServices = services.length;
    final totalAttendance = services.fold<int>(
      0,
      (sum, service) => sum + service.totalAttendance,
    );
    final averageAttendance = totalServices > 0
        ? (totalAttendance / totalServices).round()
        : 0;
    final maxAttendance = services.isEmpty
        ? 0
        : services.map((s) => s.totalAttendance).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total de Cultos',
            totalServices.toString(),
            Icons.church,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total de Presentes',
            totalAttendance.toString(),
            Icons.people,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Média por Culto',
            averageAttendance.toString(),
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Maior Presença',
            maxAttendance.toString(),
            Icons.groups,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTrendCard(List<WorshipService> services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tendência de Presença',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: _buildAttendanceTrendChart(services),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTrendChart(List<WorshipService> services) {
    if (services.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    // Sort by date
    final sortedServices = List<WorshipService>.from(services)
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));

    // Take last 10 services for better visualization
    final displayServices = sortedServices.length > 10
        ? sortedServices.sublist(sortedServices.length - 10)
        : sortedServices;

    final spots = displayServices.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.totalAttendance.toDouble(),
      );
    }).toList();

    final maxY = displayServices.isEmpty
        ? 100.0
        : displayServices
            .map((s) => s.totalAttendance)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 5,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < displayServices.length) {
                  final service = displayServices[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${service.serviceDate.day}/${service.serviceDate.month}',
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
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceByTypeCard(List<WorshipService> services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Presença por Tipo de Culto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: _buildAttendanceByTypeChart(services),
            ),
            const SizedBox(height: 16),
            _buildAttendanceByTypeList(services),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceByTypeChart(List<WorshipService> services) {
    final typeData = <WorshipType, int>{};

    for (final service in services) {
      typeData[service.serviceType] =
          (typeData[service.serviceType] ?? 0) + service.totalAttendance;
    }

    if (typeData.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    final total = typeData.values.fold<int>(0, (sum, value) => sum + value);

    final sections = typeData.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      final color = _getTypeColor(entry.key);

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildAttendanceByTypeList(List<WorshipService> services) {
    final typeData = <WorshipType, int>{};

    for (final service in services) {
      typeData[service.serviceType] =
          (typeData[service.serviceType] ?? 0) + service.totalAttendance;
    }

    final total = typeData.values.fold<int>(0, (sum, value) => sum + value);

    final sortedEntries = typeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        final percentage = total > 0 ? (entry.value / total) : 0.0;
        final color = _getTypeColor(entry.key);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAverageByDayOfWeekCard(List<WorshipService> services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Média de Presença por Dia da Semana',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: _buildAverageByDayOfWeekChart(services),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageByDayOfWeekChart(List<WorshipService> services) {
    final dayData = <int, List<int>>{};

    for (final service in services) {
      final dayOfWeek = service.serviceDate.weekday;
      dayData[dayOfWeek] = (dayData[dayOfWeek] ?? [])..add(service.totalAttendance);
    }

    if (dayData.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    final averages = <int, double>{};
    for (final entry in dayData.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      averages[entry.key] = sum / entry.value.length;
    }

    final barGroups = averages.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: Colors.blue,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final maxY = averages.values.isEmpty
        ? 100.0
        : averages.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 5,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
                if (value.toInt() >= 1 && value.toInt() <= 7) {
                  return Text(
                    days[value.toInt()],
                    style: const TextStyle(fontSize: 12),
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
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.2,
      ),
    );
  }

  Color _getTypeColor(WorshipType type) {
    switch (type) {
      case WorshipType.sundayMorning:
        return Colors.orange;
      case WorshipType.sundayEvening:
        return Colors.purple;
      case WorshipType.wednesday:
        return Colors.blue;
      case WorshipType.friday:
        return Colors.green;
      case WorshipType.special:
        return Colors.red;
      case WorshipType.other:
        return Colors.grey;
    }
  }
}
