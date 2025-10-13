import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/members/presentation/screens/members_list_screen.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/groups/presentation/screens/groups_list_screen.dart';

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
    const _EventsTab(),
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
                const Expanded(
                  child: SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ações rápidas
            Text(
              'Ações Rápidas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.person_add,
              title: 'Novo Membro',
              subtitle: 'Cadastrar novo membro',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Em breve!')),
                );
              },
            ),
            const SizedBox(height: 8),
            _QuickActionCard(
              icon: Icons.group_add,
              title: 'Novo Grupo',
              subtitle: 'Criar novo grupo ou célula',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Em breve!')),
                );
              },
            ),
          ],
        ),
      ),
    );
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

/// Card de ação rápida
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

/// Tab de Eventos (placeholder)
class _EventsTab extends StatelessWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: const Center(child: Text('Em breve!')),
    );
  }
}

