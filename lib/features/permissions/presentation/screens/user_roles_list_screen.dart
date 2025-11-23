import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/models/user_role.dart';
import '../../providers/permissions_providers.dart';

/// Tela de Usuários e Cargos
/// Exibe todos os usuários e seus cargos atribuídos
class UserRolesListScreen extends ConsumerStatefulWidget {
  const UserRolesListScreen({super.key});

  @override
  ConsumerState<UserRolesListScreen> createState() => _UserRolesListScreenState();
}

class _UserRolesListScreenState extends ConsumerState<UserRolesListScreen> {
  String _searchQuery = '';
  bool _showExpired = false;

  @override
  Widget build(BuildContext context) {
    final userRolesAsync = ref.watch(userRolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Usuários e Cargos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showExpired ? Icons.visibility : Icons.visibility_off),
            tooltip: _showExpired ? 'Ocultar expirados' : 'Mostrar expirados',
            onPressed: () {
              setState(() {
                _showExpired = !_showExpired;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar usuários ou cargos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de atribuições
          Expanded(
            child: userRolesAsync.when(
              data: (userRoles) {
                // Filtrar atribuições
                final filteredRoles = userRoles.where((userRole) {
                  final now = DateTime.now();
                  final isExpired = userRole.expiresAt != null && userRole.expiresAt!.isBefore(now);
                  final matchesExpired = _showExpired || !isExpired;
                  
                  final matchesSearch = userRole.role?.name.toLowerCase().contains(_searchQuery) ?? false;
                  
                  return matchesSearch && matchesExpired && userRole.isActive;
                }).toList();

                // Agrupar por usuário
                final Map<String, List<UserRole>> userRolesMap = {};
                for (final userRole in filteredRoles) {
                  if (!userRolesMap.containsKey(userRole.userId)) {
                    userRolesMap[userRole.userId] = [];
                  }
                  userRolesMap[userRole.userId]!.add(userRole);
                }

                if (userRolesMap.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Nenhum cargo atribuído'
                              : 'Nenhum resultado encontrado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Atribua cargos aos usuários',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: userRolesMap.length,
                  itemBuilder: (context, index) {
                    final userId = userRolesMap.keys.elementAt(index);
                    final roles = userRolesMap[userId]!;
                    return _buildUserCard(context, userId, roles);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar atribuições',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(userRolesProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/permissions/assign-role'),
        icon: const Icon(Icons.person_add),
        label: const Text('Atribuir Cargo'),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, String userId, List<UserRole> roles) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          'Usuário: ${userId.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${roles.length} cargo(s) atribuído(s)'),
        children: roles.map((userRole) => _buildRoleItem(context, userRole)).toList(),
      ),
    );
  }

  Widget _buildRoleItem(BuildContext context, UserRole userRole) {
    final now = DateTime.now();
    final isExpired = userRole.expiresAt != null && userRole.expiresAt!.isBefore(now);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        Icons.badge,
        color: isExpired
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              userRole.role?.name ?? 'Cargo desconhecido',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isExpired ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
          if (isExpired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'EXPIRADO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userRole.roleContext != null)
            Text('Contexto: ${userRole.roleContext!.contextName}'),
          if (userRole.expiresAt != null)
            Text(
              'Expira em: ${dateFormat.format(userRole.expiresAt!)}',
              style: TextStyle(
                color: isExpired
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          if (userRole.assignedAt != null)
            Text(
              'Atribuído em: ${dateFormat.format(userRole.assignedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) => _handleMenuAction(context, value, userRole),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 12),
                Text('Editar'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 12),
                Text('Remover', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, UserRole userRole) {
    switch (action) {
      case 'edit':
        context.push('/permissions/assign-role');
        break;
      case 'remove':
        _confirmRemove(context, userRole);
        break;
    }
  }

  Future<void> _confirmRemove(BuildContext context, UserRole userRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar remoção'),
        content: Text(
          'Tem certeza que deseja remover o cargo "${userRole.role?.name}" deste usuário?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = ref.read(userRolesRepositoryProvider);
        await repo.removeUserRole(userRole.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cargo removido com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(userRolesProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover cargo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
