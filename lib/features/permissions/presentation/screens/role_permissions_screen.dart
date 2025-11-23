import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/permission.dart';

/// Tela de Permissões do Cargo
/// Gerenciar quais permissões um cargo possui
class RolePermissionsScreen extends ConsumerStatefulWidget {
  final String roleId;

  const RolePermissionsScreen({super.key, required this.roleId});

  @override
  ConsumerState<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  final Map<String, bool> _selectedPermissions = {};
  bool _isLoading = false;
  bool _hasChanges = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(roleByIdProvider(widget.roleId));
    final allPermissionsAsync = ref.watch(allPermissionsProvider);
    final rolePermissionsAsync = ref.watch(rolePermissionsProvider(widget.roleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Permissões do Cargo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _savePermissions,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SALVAR'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header com nome do cargo
          roleAsync.when(
            data: (role) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.badge,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          role?.name ?? 'Cargo',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (role?.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      role!.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                'Erro ao carregar cargo',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),

          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar permissão...',
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

          // Lista de permissões
          Expanded(
            child: allPermissionsAsync.when(
              data: (allPermissions) {
                return rolePermissionsAsync.when(
                  data: (rolePermissions) {
                    // Inicializar seleções se ainda não foi feito
                    if (_selectedPermissions.isEmpty) {
                      for (final perm in allPermissions) {
                        final isGranted = rolePermissions.any((rp) => rp.id == perm.id);
                        _selectedPermissions[perm.id] = isGranted;
                      }
                    }

                    // Agrupar por categoria
                    final permissionsByCategory = <String, List<Permission>>{};
                    for (final perm in allPermissions) {
                      final matchesSearch = _searchQuery.isEmpty ||
                          perm.name.toLowerCase().contains(_searchQuery) ||
                          perm.code.toLowerCase().contains(_searchQuery) ||
                          (perm.description?.toLowerCase().contains(_searchQuery) ?? false);
                      
                      if (matchesSearch) {
                        permissionsByCategory.putIfAbsent(perm.category, () => []);
                        permissionsByCategory[perm.category]!.add(perm);
                      }
                    }

                    if (permissionsByCategory.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma permissão encontrada',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final categories = permissionsByCategory.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final permissions = permissionsByCategory[category]!;
                        permissions.sort((a, b) => a.name.compareTo(b.name));

                        return _buildCategoryCard(context, category, permissions);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Erro ao carregar permissões do cargo: $error'),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Erro ao carregar permissões: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String category, List<Permission> permissions) {
    final allSelected = permissions.every((p) => _selectedPermissions[p.id] == true);
    final someSelected = permissions.any((p) => _selectedPermissions[p.id] == true);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Header da categoria com checkbox "selecionar todos"
          CheckboxListTile(
            value: allSelected,
            tristate: true,
            onChanged: (value) {
              setState(() {
                final newValue = value ?? false;
                for (final perm in permissions) {
                  _selectedPermissions[perm.id] = newValue;
                }
                _hasChanges = true;
              });
            },
            title: Text(
              _formatCategoryName(category),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${permissions.where((p) => _selectedPermissions[p.id] == true).length}/${permissions.length} selecionadas',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            secondary: Icon(
              _getCategoryIcon(category),
              color: someSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const Divider(height: 1),
          // Lista de permissões da categoria
          ...permissions.map((permission) {
            return CheckboxListTile(
              value: _selectedPermissions[permission.id] ?? false,
              onChanged: (value) {
                setState(() {
                  _selectedPermissions[permission.id] = value ?? false;
                  _hasChanges = true;
                });
              },
              title: Text(permission.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (permission.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      permission.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
            );
          }),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    final words = category.split('_');
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'members': return Icons.people;
      case 'groups': return Icons.group;
      case 'events': return Icons.event;
      case 'financial': return Icons.attach_money;
      case 'visitors': return Icons.person_add;
      case 'ministries': return Icons.church;
      case 'worship': return Icons.music_note;
      case 'reports': return Icons.assessment;
      case 'devotionals': return Icons.book;
      case 'prayer_requests': return Icons.favorite;
      case 'testimonies': return Icons.record_voice_over;
      case 'study_groups': return Icons.school;
      case 'courses': return Icons.class_;
      case 'support_materials': return Icons.folder;
      case 'banners': return Icons.image;
      case 'news': return Icons.article;
      case 'church_info': return Icons.info;
      case 'settings': return Icons.settings;
      case 'dashboard': return Icons.dashboard;
      case 'tags': return Icons.label;
      default: return Icons.security;
    }
  }

  Future<void> _savePermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(permissionsRepositoryProvider);

      // Preparar lista de IDs das permissões selecionadas (is_granted = true)
      final permissionIds = _selectedPermissions.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      await repository.setRolePermissions(
        roleId: widget.roleId,
        permissionIds: permissionIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissões salvas com sucesso!')),
        );
        setState(() {
          _hasChanges = false;
        });
      }

      // Invalidar cache
      ref.invalidate(rolePermissionsProvider(widget.roleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar permissões: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
