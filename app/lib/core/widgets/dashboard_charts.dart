import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/dashboard_stats_provider.dart';
import '../../features/financial/presentation/providers/financial_provider.dart';
import '../../features/financial/domain/models/contribution.dart';

/// Widget de gráfico de crescimento de membros
class MemberGrowthChart extends ConsumerWidget {
  const MemberGrowthChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(memberGrowthStatsProvider);

    return Card(
      child: InkWell(
        onTap: () {
          context.push('/member-growth-report');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Crescimento de Membros',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: statsAsync.when(
                data: (stats) {
                  if (stats.isEmpty) {
                    return const Center(
                      child: Text('Sem dados para exibir'),
                    );
                  }

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= stats.length) {
                                return const Text('');
                              }
                              final monthNumber = stats[index]['monthNumber'] as int;
                              final monthNames = [
                                'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                              ];
                              return Text(
                                monthNames[monthNumber - 1],
                                style: const TextStyle(fontSize: 10),
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
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      minX: 0,
                      maxX: (stats.length - 1).toDouble(),
                      minY: 0,
                      maxY: (stats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: stats.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              (entry.value['count'] as int).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de estatísticas de eventos
class EventsStatsCard extends ConsumerWidget {
  const EventsStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(eventsStatsProvider);

    return Card(
      child: InkWell(
        onTap: () {
          context.push('/events-analysis-report');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Eventos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _EventStatItem(
                      label: 'Próximos',
                      value: stats['upcoming']!,
                      color: Colors.blue,
                      icon: Icons.upcoming,
                    ),
                    _EventStatItem(
                      label: 'Ativos',
                      value: stats['active']!,
                      color: Colors.green,
                      icon: Icons.play_circle,
                    ),
                    _EventStatItem(
                      label: 'Finalizados',
                      value: stats['completed']!,
                      color: Colors.grey,
                      icon: Icons.check_circle,
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventStatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _EventStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}

/// Widget de grupos mais ativos
class TopActiveGroupsCard extends ConsumerWidget {
  const TopActiveGroupsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(topActiveGroupsProvider);

    return Card(
      child: InkWell(
        onTap: () {
          context.push('/active-groups-report');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Grupos Mais Ativos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const Text('Nenhum grupo com reuniões registradas');
                }

                return Column(
                  children: groups.map((group) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              group['group_name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${group['meeting_count']} reuniões',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de frequência média nas reuniões
class AverageAttendanceCard extends ConsumerWidget {
  const AverageAttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(averageAttendanceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Frequência nas Reuniões',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) {
                if (stats['total_meetings'] == 0) {
                  return const Text('Nenhuma reunião registrada nos últimos 3 meses');
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AttendanceStatItem(
                          label: 'Reuniões',
                          value: stats['total_meetings'].toString(),
                          icon: Icons.event_note,
                          color: Colors.blue,
                        ),
                        _AttendanceStatItem(
                          label: 'Total Presentes',
                          value: stats['total_attendance'].toString(),
                          icon: Icons.people,
                          color: Colors.green,
                        ),
                        _AttendanceStatItem(
                          label: 'Média',
                          value: (stats['average_attendance'] as double).toStringAsFixed(1),
                          icon: Icons.trending_up,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AttendanceStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Widget de tags mais usadas
class TopTagsCard extends ConsumerWidget {
  const TopTagsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(topTagsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.label,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tags Mais Usadas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return const Text('Nenhuma tag em uso');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    final colorValue = int.tryParse(tag['color'] as String? ?? '0xFF2196F3');
                    final color = Color(colorValue ?? 0xFF2196F3);

                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          (tag['member_count'] as int).toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      label: Text(tag['name'] as String),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide(color: color),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cards de resumo financeiro
class FinancialSummaryCards extends ConsumerWidget {
  const FinancialSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalContributionsAsync = ref.watch(totalContributionsProvider);
    final totalExpensesAsync = ref.watch(totalExpensesProvider);
    final balanceAsync = ref.watch(balanceProvider);

    return Column(
      children: [
        Row(
          children: [
            // Total Contribuições
            Expanded(
              child: totalContributionsAsync.when(
                data: (total) => _buildFinancialCard(
                  context,
                  'Contribuições',
                  total,
                  Colors.green,
                  Icons.trending_up,
                ),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ),
            const SizedBox(width: 16),
            // Total Despesas
            Expanded(
              child: totalExpensesAsync.when(
                data: (total) => _buildFinancialCard(
                  context,
                  'Despesas',
                  total,
                  Colors.red,
                  Icons.trending_down,
                ),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Saldo
        balanceAsync.when(
          data: (balance) => _buildFinancialCard(
            context,
            'Saldo',
            balance,
            balance >= 0 ? Colors.blue : Colors.orange,
            balance >= 0 ? Icons.account_balance : Icons.warning,
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(
    BuildContext context,
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(value),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de contribuições por tipo
class ContributionsByTypeChart extends ConsumerWidget {
  const ContributionsByTypeChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(allContributionsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Contribuições por Tipo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: contributionsAsync.when(
                data: (contributions) {
                  if (contributions.isEmpty) {
                    return const Center(
                      child: Text('Sem dados para exibir'),
                    );
                  }

                  // Agrupar contribuições por tipo
                  final Map<ContributionType, double> totals = {};
                  for (final contribution in contributions) {
                    totals[contribution.type] =
                        (totals[contribution.type] ?? 0) + contribution.amount;
                  }

                  // Criar seções do gráfico de pizza
                  final sections = totals.entries.map((entry) {
                    final color = _getTypeColor(entry.key);
                    final percentage = (entry.value /
                            contributions.fold<double>(
                                0, (sum, c) => sum + c.amount)) *
                        100;

                    return PieChartSectionData(
                      color: color,
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: totals.entries.map((entry) {
                            final formatter = NumberFormat.currency(
                              locale: 'pt_BR',
                              symbol: 'R\$',
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(entry.key),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.key.label,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          formatter.format(entry.value),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(ContributionType type) {
    switch (type) {
      case ContributionType.tithe:
        return Colors.green;
      case ContributionType.offering:
        return Colors.blue;
      case ContributionType.missions:
        return Colors.purple;
      case ContributionType.building:
        return Colors.orange;
      case ContributionType.special:
        return Colors.pink;
      case ContributionType.other:
        return Colors.grey;
    }
  }
}

/// Widget de metas financeiras ativas
class FinancialGoalsWidget extends ConsumerWidget {
  const FinancialGoalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Metas Financeiras Ativas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nenhuma meta ativa'),
                    ),
                  );
                }

                return Column(
                  children: goals.map((goal) {
                    final formatter = NumberFormat.currency(
                      locale: 'pt_BR',
                      symbol: 'R\$',
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${goal.progressPercentage}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: goal.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatter.format(goal.currentAmount),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Meta: ${formatter.format(goal.targetAmount)}',
                                style: TextStyle(
                                  fontSize: 14,
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
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de aniversariantes do mês
class BirthdaysThisMonthCard extends ConsumerWidget {
  const BirthdaysThisMonthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(birthdaysThisMonthProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cake,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Aniversariantes do Mês',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            birthdaysAsync.when(
              data: (birthdays) {
                if (birthdays.isEmpty) {
                  return const Text('Nenhum aniversariante este mês');
                }

                final displayBirthdays = birthdays.take(5).toList();

                return Column(
                  children: [
                    ...displayBirthdays.map((birthday) {
                      final birthdate = birthday['birthdate'] as DateTime;
                      final firstName = (birthday['first_name'] as String?) ?? '';
                      final lastName = (birthday['last_name'] as String?) ?? '';
                      final photoUrl = birthday['photo_url'] as String?;
                      final type = birthday['type'] as String? ?? 'Membro';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(firstName[0] + lastName[0])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$firstName $lastName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${birthdate.day}/${birthdate.month}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: type == 'Visitante' ? Colors.blue[100] : Colors.green[100],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: type == 'Visitante' ? Colors.blue[700] : Colors.green[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.celebration,
                              color: Colors.orange[300],
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    }),
                    if (birthdays.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${birthdays.length - 5} aniversariantes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de próximas despesas/contas a pagar
class UpcomingExpensesCard extends ConsumerWidget {
  const UpcomingExpensesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(upcomingExpensesProvider);
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      child: InkWell(
        onTap: () {
          context.push('/upcoming-expenses-report');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Próximas Contas a Pagar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Text('Nenhuma despesa agendada');
                }

                final displayExpenses = expenses.take(5).toList();
                final totalAmount = expenses.fold<double>(
                  0,
                  (sum, expense) => sum + (expense['amount'] as double),
                );

                return Column(
                  children: [
                    ...displayExpenses.map((expense) {
                      final date = expense['date'] as DateTime;
                      final amount = expense['amount'] as double;
                      final category = expense['category'] as String;
                      final description = expense['description'] as String;
                      final isOverdue = expense['is_overdue'] as bool;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.attach_money,
                                color: isOverdue ? Colors.red : Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${date.day}/${date.month}/${date.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOverdue ? Colors.red : Colors.grey[500],
                                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatter.format(amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOverdue ? Colors.red : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (expenses.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${expenses.length - 5} despesas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatter.format(totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de novos membros (últimos 30 dias)
class RecentMembersCard extends ConsumerWidget {
  const RecentMembersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(recentMembersProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Novos Membros (30 dias)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Text('Nenhum novo membro nos últimos 30 dias');
                }

                final displayMembers = members.take(3).toList();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.green[700],
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${members.length} ${members.length == 1 ? 'novo membro' : 'novos membros'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...displayMembers.map((member) {
                      final firstName = member['first_name'] as String;
                      final lastName = member['last_name'] as String;
                      final photoUrl = member['photo_url'] as String?;
                      final createdAt = member['created_at'] as DateTime;
                      final daysAgo = DateTime.now().difference(createdAt).inDays;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(firstName[0] + lastName[0])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$firstName $lastName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    daysAgo == 0
                                        ? 'Hoje'
                                        : daysAgo == 1
                                            ? 'Ontem'
                                            : 'Há $daysAgo dias',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'NOVO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de próximos eventos (próximos 7 dias)
class UpcomingEventsCard extends ConsumerWidget {
  const UpcomingEventsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Card(
      child: InkWell(
        onTap: () {
          context.push('/upcoming-events-report');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Próximos Eventos (7 dias)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const Text('Nenhum evento nos próximos 7 dias');
                }

                final displayEvents = events.take(3).toList();

                return Column(
                  children: displayEvents.map((event) {
                    final title = event['title'] as String;
                    final startDate = event['start_date'] as DateTime;
                    final location = event['location'] as String?;
                    final daysUntil = startDate.difference(DateTime.now()).inDays;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${startDate.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  _getMonthAbbr(startDate.month),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (location != null)
                                  Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  daysUntil == 0
                                      ? 'Hoje'
                                      : daysUntil == 1
                                          ? 'Amanhã'
                                          : 'Em $daysUntil dias',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro: $error'),
            ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[month - 1];
  }
}
