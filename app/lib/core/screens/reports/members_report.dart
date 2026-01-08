import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_stats_provider.dart';

/// Tela de relatório de membros
class MembersReportScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const MembersReportScreen({
    super.key,
    this.initialTab,
  });

  @override
  ConsumerState<MembersReportScreen> createState() => _MembersReportScreenState();
}

class _MembersReportScreenState extends ConsumerState<MembersReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Definir tab inicial baseado no parâmetro
    if (widget.initialTab == 'birthdays') {
      _tabController.index = 1;
    } else if (widget.initialTab == 'recent') {
      _tabController.index = 2;
    }
    // else if (widget.initialTab == 'tags') {
    //   _tabController.index = 3;
    // }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Membros'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Crescimento', icon: Icon(Icons.trending_up)),
            Tab(text: 'Aniversariantes', icon: Icon(Icons.cake)),
            Tab(text: 'Novos Membros', icon: Icon(Icons.person_add)),
            // Tab(text: 'Por Tags', icon: Icon(Icons.label)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GrowthTab(),
          _BirthdaysTab(),
          _RecentMembersTab(),
          // _TagsTab(),
        ],
      ),
    );
  }
}

/// Tab de Crescimento
class _GrowthTab extends ConsumerWidget {
  const _GrowthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growthAsync = ref.watch(annualMemberGrowthProvider);
    final statsAsync = ref.watch(memberStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(annualMemberGrowthProvider);
        ref.invalidate(memberStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cards de Estatísticas
          statsAsync.when(
            data: (stats) => _buildStatsCards(context, stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Erro: $error'),
          ),
          const SizedBox(height: 24),

          // Gráfico de Crescimento
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crescimento Histórico',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: growthAsync.when(
                      data: (growth) {
                        if (growth.isEmpty) {
                          return const Center(
                            child: Text('Sem dados para exibir'),
                          );
                        }

                        return LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
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
                                  interval: growth.length > 12 ? 3 : 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= growth.length) {
                                      return const Text('');
                                    }
                                    final monthNumber = growth[index]['monthNumber'] as int;
                                    final year = growth[index]['year'] as int;
                                    final monthNames = [
                                      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                                    ];
                                    return Text(
                                      '${monthNames[monthNumber - 1]}\n$year',
                                      style: const TextStyle(fontSize: 9),
                                      textAlign: TextAlign.center,
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: growth.asMap().entries.map((entry) {
                                  return FlSpot(
                                    entry.key.toDouble(),
                                    (entry.value['accumulated'] as int).toDouble(),
                                  );
                                }).toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withValues(alpha: 0.1),
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
        ],
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Membros Ativos',
            stats['total_active'].toString(),
            Icons.people,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Novos (30 dias)',
            stats['recent_30_days'].toString(),
            Icons.person_add,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab de Aniversariantes
class _BirthdaysTab extends ConsumerWidget {
  const _BirthdaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(birthdaysThisMonthProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(birthdaysThisMonthProvider);
      },
      child: birthdaysAsync.when(
        data: (birthdays) {
          if (birthdays.isEmpty) {
            return const Center(
              child: Text('Nenhum aniversariante este mês'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: birthdays.length,
            itemBuilder: (context, index) {
              final birthday = birthdays[index];
              final birthdate = birthday['birthdate'] as DateTime;
              final firstName = birthday['first_name'] as String;
              final lastName = birthday['last_name'] as String;
              final photoUrl = birthday['photo_url'] as String?;
              final type = birthday['type'] as String? ?? 'Membro'; // Tipo: Membro ou Visitante
              final now = DateTime.now();
              final age = now.year - birthdate.year;
              final daysUntil = DateTime(now.year, birthdate.month, birthdate.day)
                  .difference(now)
                  .inDays;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? Text(firstName[0] + lastName[0]) : null,
                  ),
                  title: Text('$firstName $lastName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${birthdate.day}/${birthdate.month} • $age anos'),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: type == 'Visitante' ? Colors.blue[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: type == 'Visitante' ? Colors.blue[700] : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cake, color: daysUntil == 0 ? Colors.orange : Colors.grey),
                      Text(
                        daysUntil == 0 ? 'HOJE!' : daysUntil > 0 ? 'Em $daysUntil dias' : 'Passou',
                        style: TextStyle(fontSize: 10, color: daysUntil == 0 ? Colors.orange : Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

/// Tab de Novos Membros
class _RecentMembersTab extends ConsumerWidget {
  const _RecentMembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(recentMembersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recentMembersProvider);
      },
      child: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Nenhum novo membro nos últimos 30 dias'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final firstName = member['first_name'] as String;
              final lastName = member['last_name'] as String;
              final photoUrl = member['photo_url'] as String?;
              final createdAt = member['created_at'] as DateTime;
              final daysAgo = DateTime.now().difference(createdAt).inDays;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? Text(firstName[0] + lastName[0]) : null,
                  ),
                  title: Text('$firstName $lastName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(createdAt)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      daysAgo == 0 ? 'HOJE' : daysAgo == 1 ? 'ONTEM' : 'HÁ $daysAgo DIAS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[700]),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

/// Tab de Tags
// class _TagsTab extends ConsumerWidget {
//   const _TagsTab();
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final tagsAsync = ref.watch(topTagsProvider);
//
//     return RefreshIndicator(
//       onRefresh: () async {
//         ref.invalidate(topTagsProvider);
//       },
//       child: tagsAsync.when(
//         data: (tags) {
//           if (tags.isEmpty) {
//             return const Center(
//               child: Text('Nenhuma tag cadastrada'),
//             );
//           }
//
//           final totalMembers = tags.fold<int>(0, (sum, tag) => sum + (tag['member_count'] as int));
//
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: tags.length,
//             itemBuilder: (context, index) {
//               final tag = tags[index];
//               final name = tag['name'] as String;
//               final memberCount = tag['member_count'] as int;
//               final colorHex = tag['color'] as String?;
//               final percentage = totalMembers > 0 ? (memberCount / totalMembers * 100).toStringAsFixed(1) : '0.0';
//
//               Color tagColor = Colors.blue;
//               if (colorHex != null && colorHex.isNotEmpty) {
//                 try {
//                   tagColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
//                 } catch (_) {}
//               }
//
//               return Card(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: tagColor,
//                     child: const Icon(Icons.label, color: Colors.white),
//                   ),
//                   title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: LinearProgressIndicator(
//                     value: memberCount / totalMembers,
//                     backgroundColor: Colors.grey[200],
//                     valueColor: AlwaysStoppedAnimation<Color>(tagColor),
//                   ),
//                   trailing: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text('$memberCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                       Text('$percentage%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (error, _) => Center(child: Text('Erro: $error')),
//       ),
//     );
//   }
// }
