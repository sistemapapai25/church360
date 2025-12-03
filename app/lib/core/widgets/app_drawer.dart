import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/access_levels/presentation/providers/access_level_provider.dart';

/// Menu lateral do aplicativo
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userAccessLevelAsync = ref.watch(currentUserAccessLevelProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header do Drawer
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Icon(
                Icons.church,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            accountName: Text(
              'Church 360',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            accountEmail: Text(
              currentUser?.email ?? 'Não autenticado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
            ),
          ),

          // Dashboard
          _DrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            route: '/',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // GESTÃO
          _DrawerSection(title: 'GESTÃO'),
          _DrawerItem(
            icon: Icons.people,
            title: 'Membros',
            route: '/members',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.person_add,
            title: 'Visitantes',
            route: '/visitors',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          userAccessLevelAsync.when(
            data: (accessLevel) {
              if (accessLevel?.accessLevelNumber != null && accessLevel!.accessLevelNumber >= 5) {
                return _DrawerItem(
                  icon: Icons.admin_panel_settings,
                  title: 'Níveis de Acesso',
                  route: '/access-levels',
                  currentRoute: GoRouterState.of(context).uri.toString(),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const Divider(),

          // MINISTÉRIO
          _DrawerSection(title: 'MINISTÉRIO'),
          _DrawerItem(
            icon: Icons.church,
            title: 'Ministérios',
            route: '/ministries',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.groups,
            title: 'Grupos de Comunhão',
            route: '/groups',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.menu_book,
            title: 'Grupos de Estudo',
            route: '/study-groups',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.church_outlined,
            title: 'Cultos',
            route: '/worship',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // ATIVIDADES
          _DrawerSection(title: 'ATIVIDADES'),
          _DrawerItem(
            icon: Icons.event,
            title: 'Eventos',
            route: '/events',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.favorite,
            title: 'Pedidos de Oração',
            route: '/prayer-requests',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.book,
            title: 'Devocionais',
            route: '/devotionals',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // FINANCEIRO
          _DrawerSection(title: 'FINANCEIRO'),
          _DrawerItem(
            icon: Icons.attach_money,
            title: 'Financeiro',
            route: '/financial',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // RELATÓRIOS
          _DrawerSection(title: 'RELATÓRIOS'),
          _DrawerItem(
            icon: Icons.analytics,
            title: 'Analytics & Relatórios',
            route: '/analytics',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // CONFIGURAÇÕES
          _DrawerSection(title: 'CONFIGURAÇÕES'),
          _DrawerItem(
            icon: Icons.label,
            title: 'Tags',
            route: '/tags',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),
          _DrawerItem(
            icon: Icons.notifications,
            title: 'Notificações',
            route: '/notifications',
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar Saída'),
                  content: const Text('Deseja realmente sair do aplicativo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),

          const SizedBox(height: 16),

          // Versão do App
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Church 360 v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seção do drawer (título de categoria)
class _DrawerSection extends StatelessWidget {
  final String title;

  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

/// Item do drawer
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentRoute == route || currentRoute.startsWith('$route/');

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        context.push(route);
      },
    );
  }
}
