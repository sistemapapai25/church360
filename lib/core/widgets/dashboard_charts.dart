import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/dashboard_stats_provider.dart';
import '../theme/app_theme.dart';
import '../../features/financial/presentation/providers/financial_provider.dart';
import '../../features/financial/domain/models/contribution.dart';
import '../../features/dispatch/presentation/providers/auto_scheduler_providers.dart';

/// Tokens visuais compartilhados pelos cards do Dashboard (CHU-302+),
/// alinhados ao canvas de referência "Dashboard Liderança" aprovado em 05/09.
class _DashStyle {
  static const Color textMuted = Color(0xFF8A8797);
  static const Color textFaint = Color(0xFFAEACBC);
  static const Color divider = Color(0xFFF0EFF7);
  static const Color accentPurple = Color(0xFF7C4DFF);
  static const Color statusGreenBg = Color(0xFFE7F8EE);
  static const Color statusGreenFg = Color(0xFF0F9D58);
  static const Color statusBlueBg = Color(0xFFE9F0FE);
  static const Color statusBlueFg = Color(0xFF3B82F6);
  static const Color statusRedBg = Color(0xFFFDE8E8);
  static const Color statusRedFg = Color(0xFFC0392B);
  static const Color tooltipBg = Color(0xFF1E1B29);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D201F32), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static BoxDecoration card({double radius = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      );
}

/// Cabeçalho padrão dos cards do Dashboard: badge de ícone colorido + título.
class _DashCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool showArrow;

  const _DashCardHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        if (showArrow)
          const Icon(Icons.arrow_forward_ios, size: 14, color: _DashStyle.textFaint),
      ],
    );
  }
}

/// Selo (pill) de status usado nas listas de atividade do Dashboard.
class _DashPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _DashPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: foreground),
      ),
    );
  }
}

/// Widget de gráfico de crescimento de membros
class MemberGrowthChart extends ConsumerWidget {
  const MemberGrowthChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(memberGrowthStatsProvider);

    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () {
          context.push('/member-growth-report');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.trending_up,
                iconColor: AppTheme.primaryColor,
                title: 'Crescimento de Membros',
                showArrow: true,
              ),
            const SizedBox(height: 20),
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
                          return const FlLine(
                            color: _DashStyle.divider,
                            strokeWidth: 1,
                            dashArray: [4, 4],
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
                                style: const TextStyle(fontSize: 10, color: _DashStyle.textMuted),
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
                                style: const TextStyle(fontSize: 10, color: _DashStyle.textMuted),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (stats.length - 1).toDouble(),
                      minY: 0,
                      maxY: (stats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => _DashStyle.tooltipBg,
                          tooltipRoundedRadius: 10,
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toInt()} membros',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: stats.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              (entry.value['count'] as int).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              final isLast = index == stats.length - 1;
                              return FlDotCirclePainter(
                                radius: isLast ? 5.5 : 3.5,
                                color: isLast ? AppTheme.primaryColor : Colors.white,
                                strokeColor: AppTheme.primaryColor,
                                strokeWidth: 2.5,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.22),
                                AppTheme.primaryColor.withValues(alpha: 0.0),
                              ],
                            ),
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

    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () {
          context.push('/events-analysis-report');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.event,
                iconColor: _DashStyle.accentPurple,
                title: 'Eventos',
                showArrow: true,
              ),
            const SizedBox(height: 20),
            statsAsync.when(
              data: (stats) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _EventStatItem(
                      label: 'Próximos',
                      value: stats['upcoming']!,
                      color: AppTheme.primaryColor,
                      icon: Icons.upcoming,
                    ),
                    _EventStatItem(
                      label: 'Ativos',
                      value: stats['active']!,
                      color: AppTheme.secondaryColor,
                      icon: Icons.play_circle,
                    ),
                    _EventStatItem(
                      label: 'Finalizados',
                      value: stats['completed']!,
                      color: _DashStyle.textMuted,
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

class AutoSchedulerSummaryCard extends ConsumerWidget {
  const AutoSchedulerSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allAutoSchedulesProvider);
    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () => context.push('/dispatch-config'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.schedule,
                iconColor: AppTheme.warningColor,
                title: 'Agendamentos Automáticos',
                showArrow: true,
              ),
              const SizedBox(height: 20),
              itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Text('Nenhum agendamento configurado');
                  }
                  final active = items.where((e) => e.active).toList();
                  final nexts = active.where((e) => e.nextRun != null).toList()
                    ..sort((a, b) => a.nextRun!.compareTo(b.nextRun!));
                  final display = nexts.take(3).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ativos: ${active.length} · Total: ${items.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (final c in display)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              _DashPill(
                                label: c.sendTime,
                                background: _DashStyle.statusGreenBg,
                                foreground: _DashStyle.statusGreenFg,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.nextRun != null
                                    ? DateFormat('dd/MM HH:mm').format(c.nextRun!)
                                    : '-',
                                style: const TextStyle(color: _DashStyle.textMuted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Erro: $err'),
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _DashStyle.textMuted),
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

    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () {
          context.push('/active-groups-report');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.groups,
                iconColor: _DashStyle.accentPurple,
                title: 'Grupos Mais Ativos',
                showArrow: true,
              ),
            const SizedBox(height: 20),
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
                          _DashPill(
                            label: '${group['meeting_count']} reuniões',
                            background: _DashStyle.statusBlueBg,
                            foreground: _DashStyle.statusBlueFg,
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.analytics,
              iconColor: AppTheme.primaryColor,
              title: 'Frequência nas Reuniões',
            ),
            const SizedBox(height: 20),
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
                          color: AppTheme.primaryColor,
                        ),
                        _AttendanceStatItem(
                          label: 'Total Presentes',
                          value: stats['total_attendance'].toString(),
                          icon: Icons.people,
                          color: AppTheme.secondaryColor,
                        ),
                        _AttendanceStatItem(
                          label: 'Média',
                          value: (stats['average_attendance'] as double).toStringAsFixed(1),
                          icon: Icons.trending_up,
                          color: AppTheme.warningColor,
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
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _DashStyle.textMuted),
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.label,
              iconColor: AppTheme.primaryColor,
              title: 'Tags Mais Usadas',
            ),
            const SizedBox(height: 20),
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
                  AppTheme.secondaryColor,
                  Icons.trending_up,
                ),
                loading: () => Container(
                  decoration: _DashStyle.card(),
                  child: const Padding(
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
                  AppTheme.errorColor,
                  Icons.trending_down,
                ),
                loading: () => Container(
                  decoration: _DashStyle.card(),
                  child: const Padding(
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
            balance >= 0 ? AppTheme.primaryColor : AppTheme.warningColor,
            balance >= 0 ? Icons.account_balance : Icons.warning,
          ),
          loading: () => Container(
            decoration: _DashStyle.card(),
            child: const Padding(
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              formatter.format(value),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: _DashStyle.textMuted),
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.pie_chart,
              iconColor: AppTheme.primaryColor,
              title: 'Contribuições por Tipo',
            ),
            const SizedBox(height: 20),
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
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(entry.key),
                                      shape: BoxShape.circle,
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
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _DashStyle.textMuted,
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
        return AppTheme.secondaryColor;
      case ContributionType.offering:
        return AppTheme.primaryColor;
      case ContributionType.missions:
        return _DashStyle.accentPurple;
      case ContributionType.building:
        return AppTheme.warningColor;
      case ContributionType.special:
        return Colors.pink;
      case ContributionType.other:
        return _DashStyle.textMuted;
    }
  }
}

/// Widget de metas financeiras ativas
class FinancialGoalsWidget extends ConsumerWidget {
  const FinancialGoalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.flag,
              iconColor: AppTheme.warningColor,
              title: 'Metas Financeiras Ativas',
            ),
            const SizedBox(height: 20),
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
                              _DashPill(
                                label: '${goal.progressPercentage}%',
                                background: _DashStyle.statusBlueBg,
                                foreground: _DashStyle.statusBlueFg,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: goal.progress,
                              backgroundColor: _DashStyle.divider,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                              minHeight: 8,
                            ),
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
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              Text(
                                'Meta: ${formatter.format(goal.targetAmount)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _DashStyle.textMuted,
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.cake,
              iconColor: AppTheme.warningColor,
              title: 'Aniversariantes do Mês',
            ),
            const SizedBox(height: 20),
            birthdaysAsync.when(
              data: (birthdays) {
                if (birthdays.isEmpty) {
                  return const Text('Nenhum aniversariante este mês');
                }

                final today = DateTime.now().day;

                return Column(
                  children: [
                    ...birthdays.map((birthday) {
                      final birthdate = birthday['birthdate'] as DateTime;
                      final firstName = (birthday['first_name'] as String?) ?? '';
                      final lastName = (birthday['last_name'] as String?) ?? '';
                      final photoUrl = birthday['photo_url'] as String?;
                      final type = birthday['type'] as String? ?? 'Membro';

                      final isToday = birthdate.day == today;
                      final isPast = birthdate.day < today;

                      final nameColor = isPast
                          ? Colors.grey[500]
                          : (isToday ? Colors.orange[800] : null);
                      final dateColor = isPast ? Colors.grey[400] : _DashStyle.textMuted;
                      final iconColor = isPast
                          ? Colors.grey[400]
                          : (isToday ? Colors.orange[700] : Colors.orange[300]);

                      return Opacity(
                        opacity: isPast ? 0.55 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isToday ? Colors.orange[100] : null,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: nameColor,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          isToday
                                              ? 'Hoje!'
                                              : '${birthdate.day}/${birthdate.month}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isToday ? FontWeight.bold : null,
                                            color: dateColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _DashPill(
                                          label: type,
                                          background: type == 'Visitante'
                                              ? _DashStyle.statusBlueBg
                                              : _DashStyle.statusGreenBg,
                                          foreground: type == 'Visitante'
                                              ? _DashStyle.statusBlueFg
                                              : _DashStyle.statusGreenFg,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.celebration,
                                color: iconColor,
                                size: 20,
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

    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () {
          context.push('/upcoming-expenses-report');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.receipt_long,
                iconColor: AppTheme.warningColor,
                title: 'Próximas Contas a Pagar',
                showArrow: true,
              ),
            const SizedBox(height: 20),
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? _DashStyle.statusRedBg
                                    : _DashStyle.statusBlueBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.attach_money,
                                color: isOverdue
                                    ? _DashStyle.statusRedFg
                                    : _DashStyle.statusBlueFg,
                                size: 18,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _DashStyle.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${date.day}/${date.month}/${date.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOverdue
                                          ? _DashStyle.statusRedFg
                                          : _DashStyle.textFaint,
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
                                color: isOverdue ? _DashStyle.statusRedFg : Colors.black87,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: _DashStyle.textMuted,
                          ),
                        ),
                      ),
                    const Divider(height: 24, color: _DashStyle.divider),
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
                            color: _DashStyle.statusRedFg,
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

    return Container(
      decoration: _DashStyle.card(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashCardHeader(
              icon: Icons.person_add,
              iconColor: AppTheme.secondaryColor,
              title: 'Novos Membros (30 dias)',
            ),
            const SizedBox(height: 20),
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
                        color: _DashStyle.statusGreenBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.trending_up,
                            color: _DashStyle.statusGreenFg,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${members.length} ${members.length == 1 ? 'novo membro' : 'novos membros'}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _DashStyle.statusGreenFg,
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
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                              foregroundColor: AppTheme.primaryColor,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _DashStyle.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _DashPill(
                              label: 'NOVO',
                              background: _DashStyle.statusGreenBg,
                              foreground: _DashStyle.statusGreenFg,
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

    return Container(
      decoration: _DashStyle.card(),
      child: InkWell(
        onTap: () {
          context.push('/upcoming-events-report');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashCardHeader(
                icon: Icons.event,
                iconColor: AppTheme.primaryColor,
                title: 'Próximos Eventos (7 dias)',
                showArrow: true,
              ),
            const SizedBox(height: 20),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _DashStyle.statusBlueBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${startDate.day}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _DashStyle.statusBlueFg,
                                  ),
                                ),
                                Text(
                                  _getMonthAbbr(startDate.month),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _DashStyle.statusBlueFg,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _DashStyle.textMuted,
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _DashStyle.statusBlueFg,
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
