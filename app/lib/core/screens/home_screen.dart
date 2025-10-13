import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/members/presentation/screens/members_list_screen.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/groups/presentation/screens/groups_list_screen.dart';
import '../../features/groups/presentation/providers/groups_provider.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/tags/presentation/screens/tags_list_screen.dart';

/// Tela principal do app (Dashboard)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const _DashboardTab(),
    const MembersListScreen(),
    const GroupsListScreen(),
    const EventsListScreen(),
    const TagsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Membros',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Grupos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Eventos',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outline),
            selectedIcon: Icon(Icons.label),
            label: 'Tags',
          ),
        ],
      ),
    );
  }
}

/// Tab do Dashboard
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final totalMembersAsync = ref.watch(totalMembersCountProvider);
    final activeMembersAsync = ref.watch(activeMembersCountProvider);
    final visitorsAsync = ref.watch(visitorsCountProvider);
    final totalGroupsAsync = ref.watch(totalGroupsCountProvider);
    final activeGroupsAsync = ref.watch(activeGroupsCountProvider);
    final allMembersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Church 360'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boas-vindas
            Text(
              'Bem-vindo!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (user?.email != null) ...[
              const SizedBox(height: 4),
              Text(
                user!.email!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            const SizedBox(height: 24),

            // Cards de estatísticas
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total',
                    icon: Icons.people,
                    color: Colors.blue,
                    valueAsync: totalMembersAsync,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Ativos',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    valueAsync: activeMembersAsync,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Visitantes',
                    icon: Icons.person_add,
                    color: Colors.orange,
                    valueAsync: visitorsAsync,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Grupos',
                    icon: Icons.group_work,
                    color: Colors.purple,
                    valueAsync: activeGroupsAsync,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Aniversariantes do Mês
            Text(
              'Aniversariantes do Mês 🎂',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),

            allMembersAsync.when(
              data: (members) {
                final now = DateTime.now();
                final birthdays = members.where((m) {
                  if (m.birthdate == null) return false;
                  return m.birthdate!.month == now.month;
                }).toList();

                birthdays.sort((a, b) => a.birthdate!.day.compareTo(b.birthdate!.day));

                if (birthdays.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum aniversariante este mês',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: birthdays.length > 5 ? 5 : birthdays.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = birthdays[index];
                      final day = member.birthdate!.day;
                      final age = member.age;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.cake),
                        ),
                        title: Text(member.fullName),
                        subtitle: Text('$day de ${_getMonthName(now.month)}${age != null ? ' • $age anos' : ''}'),
                        trailing: day == now.day
                            ? const Chip(
                                label: Text('HOJE! 🎉'),
                                backgroundColor: Colors.orange,
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Novos Membros
            Text(
              'Novos Membros (30 dias) 🆕',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),

            allMembersAsync.when(
              data: (members) {
                final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                final newMembers = members.where((m) {
                  return m.membershipDate != null && m.membershipDate!.isAfter(thirtyDaysAgo);
                }).toList();

                newMembers.sort((a, b) => b.membershipDate!.compareTo(a.membershipDate!));

                if (newMembers.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum novo membro nos últimos 30 dias',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: newMembers.length > 5 ? 5 : newMembers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = newMembers[index];
                      final daysAgo = DateTime.now().difference(member.membershipDate!).inDays;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(
                            member.firstName.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(member.fullName),
                        subtitle: Text(
                          daysAgo == 0
                              ? 'Hoje!'
                              : daysAgo == 1
                                  ? 'Ontem'
                                  : 'Há $daysAgo dias',
                        ),
                        trailing: member.isVisitor
                            ? const Chip(
                                label: Text('Visitante'),
                                backgroundColor: Colors.orange,
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }
}

/// Card de estatística
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<int> valueAsync;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.valueAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            valueAsync.when(
              data: (value) => Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Text('--'),
            ),
          ],
        ),
      ),
    );
  }
}

