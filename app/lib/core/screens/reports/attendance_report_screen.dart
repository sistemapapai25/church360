import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_stats_provider.dart';

/// Tela de relatório de presença
class AttendanceReportScreen extends ConsumerWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceByGroupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Presença'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendanceByGroupProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de Média de Presença
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Média de Presença (Últimos 3 Meses)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    attendanceAsync.when(
                      data: (attendance) {
                        if (attendance.isEmpty) {
                          return const Center(
                            child: Text('Sem dados de presença'),
                          );
                        }

                        // Calcular média geral
                        final totalPresent = attendance.fold<int>(
                          0,
                          (sum, item) => sum + (item['total_present'] as int),
                        );
                        final totalExpected = attendance.fold<int>(
                          0,
                          (sum, item) => sum + (item['total_expected'] as int),
                        );
                        final averagePercentage = totalExpected > 0
                            ? (totalPresent / totalExpected * 100).toStringAsFixed(1)
                            : '0.0';

                        return Column(
                          children: [
                            // Indicador de Média Geral
                            SizedBox(
                              height: 200,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 60,
                                      sections: [
                                        PieChartSectionData(
                                          value: totalPresent.toDouble(),
                                          color: Colors.green,
                                          title: '',
                                          radius: 30,
                                        ),
                                        PieChartSectionData(
                                          value: (totalExpected - totalPresent).toDouble(),
                                          color: Colors.grey[300],
                                          title: '',
                                          radius: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$averagePercentage%',
                                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                      ),
                                      Text(
                                        'Média Geral',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Lista de Reuniões
                            ...attendance.map((item) {
                              final groupName = item['group_name'] as String;
                              final present = item['total_present'] as int;
                              final expected = item['total_expected'] as int;
                              final percentage = expected > 0
                                  ? (present / expected * 100).toStringAsFixed(1)
                                  : '0.0';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                                    child: const Icon(Icons.groups, color: Colors.green),
                                  ),
                                  title: Text(
                                    groupName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: LinearProgressIndicator(
                                    value: present / expected,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$percentage%',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$present/$expected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Erro: $error')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

