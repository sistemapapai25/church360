import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../constants/supabase_constants.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';

/// Enum para períodos de filtro
enum GroupActivityPeriod {
  last30Days('Últimos 30 dias'),
  last60Days('Últimos 60 dias'),
  last90Days('Últimos 90 dias'),
  last6Months('Últimos 6 meses'),
  lastYear('Último ano'),
  allTime('Todo o período');

  final String label;
  const GroupActivityPeriod(this.label);
}

/// Provider para grupos ativos com análise por período
  final activeGroupsByPeriodProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime?>(
  (ref, startDate) async {
    final supabase = ref.watch(supabaseClientProvider);

    // Buscar todos os grupos ativos
    final groupsResponse = await supabase
        .from('group')
        .select('id, name, description, group_type, created_at')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true)
        .order('name', ascending: true);

    final groups = groupsResponse as List;
    final groupStats = <Map<String, dynamic>>[];

    // Para cada grupo, buscar estatísticas
    for (var group in groups) {
      final groupId = group['id'] as String?;
      final groupName = group['name'] as String?;
      
      // Pular grupos sem ID ou nome
      if (groupId == null || groupName == null || groupName.isEmpty) continue;

      // Query base para reuniões
      var meetingsQuery = supabase
          .from('group_meeting')
          .select('id, meeting_date, total_attendance')
          .eq('group_id', groupId);

      // Aplicar filtro de período se especificado
      if (startDate != null) {
        meetingsQuery = meetingsQuery.gte('meeting_date', startDate.toIso8601String().split('T')[0]);
      }

      final meetingsResponse = await meetingsQuery.order('meeting_date', ascending: false);
      final meetings = meetingsResponse as List;

      // Contar membros do grupo
      final membersResponse = await supabase
          .from('group_member')
          .select('user_id')
          .eq('group_id', groupId);

      final memberCount = (membersResponse as List).length;

      // Calcular estatísticas
      final meetingCount = meetings.length;
      final totalAttendance = meetings.fold<int>(
        0,
        (sum, meeting) => sum + ((meeting['total_attendance'] as int?) ?? 0),
      );
      final averageAttendance = meetingCount > 0 ? (totalAttendance / meetingCount) : 0.0;

      // Última reunião
      DateTime? lastMeetingDate;
      if (meetings.isNotEmpty) {
        lastMeetingDate = DateTime.parse(meetings.first['meeting_date'] as String);
      }

      groupStats.add({
        'group_id': groupId,
        'group_name': groupName,
        'group_type': group['group_type'] as String?,
        'description': group['description'] as String?,
        'member_count': memberCount,
        'meeting_count': meetingCount,
        'total_attendance': totalAttendance,
        'average_attendance': averageAttendance,
        'last_meeting_date': lastMeetingDate,
      });
    }

    // Ordenar por número de reuniões (decrescente)
    groupStats.sort((a, b) {
      final countA = a['meeting_count'] as int? ?? 0;
      final countB = b['meeting_count'] as int? ?? 0;
      return countB.compareTo(countA);
    });

    return groupStats;
  },
);

/// Tela de relatório de grupos ativos
class ActiveGroupsReportScreen extends ConsumerStatefulWidget {
  const ActiveGroupsReportScreen({super.key});

  @override
  ConsumerState<ActiveGroupsReportScreen> createState() =>
      _ActiveGroupsReportScreenState();
}

class _ActiveGroupsReportScreenState
    extends ConsumerState<ActiveGroupsReportScreen> {
  GroupActivityPeriod _selectedPeriod = GroupActivityPeriod.last90Days;

  @override
  Widget build(BuildContext context) {
    final startDate = _getStartDate();
    final groupsAsync = ref.watch(activeGroupsByPeriodProvider(startDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos Mais Ativos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(activeGroupsByPeriodProvider);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de Período
          _buildPeriodFilter(),

          // Conteúdo
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeGroupsByPeriodProvider);
              },
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum grupo encontrado',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  final totalGroups = groups.length;
                  final totalMeetings = groups.fold<int>(0, (sum, g) => sum + ((g['meeting_count'] as int?) ?? 0));
                  final totalMembers = groups.fold<int>(0, (sum, g) => sum + ((g['member_count'] as int?) ?? 0));
                  final groupsWithMeetings = groups.where((g) => ((g['meeting_count'] as int?) ?? 0) > 0).length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Cards de Resumo
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total de Grupos',
                              '$totalGroups',
                              Icons.groups,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Com Reuniões',
                              '$groupsWithMeetings',
                              Icons.event_available,
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
                              'Total Reuniões',
                              '$totalMeetings',
                              Icons.calendar_today,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Membros',
                              '$totalMembers',
                              Icons.people,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Top 10 Grupos Mais Ativos
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top 10 Grupos Mais Ativos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTopGroupsChart(groups.take(10).toList()),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Gráfico de Frequência Média
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Frequência Média por Grupo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 250,
                                child: _buildAttendanceChart(groups.take(10).toList()),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de Todos os Grupos
                      const Text(
                        'Todos os Grupos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...groups.map((group) => _buildGroupCard(group)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro: $error'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(activeGroupsByPeriodProvider);
                        },
                        child: const Text('Tentar Novamente'),
                      ),
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
                fontSize: 11,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Gráfico de barras (top grupos)
  Widget _buildTopGroupsChart(List<Map<String, dynamic>> groups) {
    if (groups.isEmpty) {
      return const Text('Nenhum grupo com reuniões');
    }

    return Column(
      children: groups.asMap().entries.map((entry) {
        final index = entry.key;
        final group = entry.value;
        final meetings = (group['meeting_count'] as int?) ?? 0;
        final maxMeetings = (groups.first['meeting_count'] as int?) ?? 1;
        final percentage = maxMeetings > 0 ? (meetings / maxMeetings * 100).toInt() : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group['group_name'] as String? ?? 'Sem nome',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$meetings reuniões',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Gráfico de frequência média
  Widget _buildAttendanceChart(List<Map<String, dynamic>> groups) {
    if (groups.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: groups.map((g) => (g['average_attendance'] as double?) ?? 0.0).reduce((a, b) => a > b ? a : b) + 5,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final groupData = groups[group.x.toInt()];
              return BarTooltipItem(
                '${groupData['group_name']}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Média: ${rod.toY.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= groups.length) return const Text('');
                final name = groups[index]['group_name'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 8)}...' : name,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
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
        barGroups: groups.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value['average_attendance'] as double?) ?? 0.0,
                color: Colors.green,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Card de grupo
  Widget _buildGroupCard(Map<String, dynamic> group) {
    final dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');
    final meetings = (group['meeting_count'] as int?) ?? 0;
    final members = (group['member_count'] as int?) ?? 0;
    final avgAttendance = (group['average_attendance'] as double?) ?? 0.0;
    final lastMeeting = group['last_meeting_date'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navegar para detalhes do grupo
          context.push('/groups/${group['group_id']}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group['group_name'] as String? ?? 'Sem nome',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (group['description'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  group['description'] as String,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricBadge(
                    Icons.event,
                    '$meetings reuniões',
                    Colors.blue,
                  ),
                  _buildMetricBadge(
                    Icons.people,
                    '$members membros',
                    Colors.green,
                  ),
                  _buildMetricBadge(
                    Icons.analytics,
                    'Média: ${avgAttendance.toStringAsFixed(1)}',
                    Colors.orange,
                  ),
                ],
              ),
              if (lastMeeting != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Última reunião: ${dateFormatter.format(lastMeeting)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Badge de métrica
  Widget _buildMetricBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna a data inicial baseada no período selecionado
  DateTime? _getStartDate() {
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case GroupActivityPeriod.last30Days:
        return now.subtract(const Duration(days: 30));
      case GroupActivityPeriod.last60Days:
        return now.subtract(const Duration(days: 60));
      case GroupActivityPeriod.last90Days:
        return now.subtract(const Duration(days: 90));
      case GroupActivityPeriod.last6Months:
        return DateTime(now.year, now.month - 6, now.day);
      case GroupActivityPeriod.lastYear:
        return DateTime(now.year - 1, now.month, now.day);
      case GroupActivityPeriod.allTime:
        return null; // Sem filtro de data
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
              'Período de Análise',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GroupActivityPeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
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
}
