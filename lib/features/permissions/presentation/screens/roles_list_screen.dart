import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/role.dart';

/// Tela de Lista de Cargos
/// Exibe todos os cargos com hierarquia visual
class RolesListScreen extends ConsumerStatefulWidget {
  const RolesListScreen({super.key});

  @override
  ConsumerState<RolesListScreen> createState() => _RolesListScreenState();
}

class _RolesListScreenState extends ConsumerState<RolesListScreen> {
  String _searchQuery = '';
  bool _showInactive = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(allRolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cargos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showInactive = !_showInactive;
              });
            },
            tooltip: _showInactive ? 'Ocultar inativos' : 'Mostrar inativos',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/permissions/roles/create'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Cargo'),
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cargo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
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

          // Lista de cargos
          Expanded(
            child: rolesAsync.when(
              data: (roles) {
                // Filtrar por busca e status
                final filteredRoles = roles.where((role) {
                  final matchesSearch = role.name.toLowerCase().contains(_searchQuery) ||
                      (role.description?.toLowerCase().contains(_searchQuery) ?? false);
                  final matchesStatus = _showInactive || role.isActive;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (filteredRoles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Nenhum cargo cadastrado'
                              : 'Nenhum cargo encontrado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Clique no botão + para criar um cargo',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Organizar por hierarquia
                final rootRoles = filteredRoles.where((r) => r.parentRoleId == null).toList();
                rootRoles.sort((a, b) => a.name.compareTo(b.name));

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allRolesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rootRoles.length,
                    itemBuilder: (context, index) {
                      return _buildRoleCard(
                        context,
                        rootRoles[index],
                        filteredRoles,
                        level: 0,
                      );
                    },
                  ),
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
                      'Erro ao carregar cargos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(allRolesProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    Role role,
    List<Role> allRoles, {
    required int level,
  }) {
    final childRoles = allRoles.where((r) => r.parentRoleId == role.id).toList();
    childRoles.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(
            left: level * 24.0,
            bottom: 8,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: role.isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.badge,
                color: role.isActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    role.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: role.isActive ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (!role.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'INATIVO',
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
                if (role.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    role.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.layers, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'Nível ${role.hierarchyLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (role.allowsContext) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Permite contexto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                  onTap: () {
                    Future.microtask(() {
                      if (!context.mounted) return;
                      context.push('/permissions/roles/edit/${role.id}');
                    });
                  },
                ),
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.security, size: 20),
                      SizedBox(width: 8),
                      Text('Permissões'),
                    ],
                  ),
                  onTap: () {
                    Future.microtask(() {
                      if (!context.mounted) return;
                      context.push('/permissions/roles/${role.id}/permissions');
                    });
                  },
                ),
                if (role.isActive)
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_off, size: 20),
                        SizedBox(width: 8),
                        Text('Desativar'),
                      ],
                    ),
                    onTap: () => _toggleRoleStatus(role, false),
                  )
                else
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('Ativar'),
                      ],
                    ),
                    onTap: () => _toggleRoleStatus(role, true),
                  ),
              ],
            ),
            onTap: () => context.push('/permissions/roles/edit/${role.id}'),
          ),
        ),
        // Cargos filhos (hierarquia)
        ...childRoles.map((childRole) => _buildRoleCard(
          context,
          childRole,
          allRoles,
          level: level + 1,
        )),
      ],
    );
  }

  Future<void> _toggleRoleStatus(Role role, bool isActive) async {
    final repository = ref.read(rolesRepositoryProvider);
    try {
      await repository.updateRole(roleId: role.id, isActive: isActive);
      ref.invalidate(allRolesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Cargo ativado' : 'Cargo desativado'),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
