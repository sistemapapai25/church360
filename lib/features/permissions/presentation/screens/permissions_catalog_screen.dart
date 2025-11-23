import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/permission.dart';

/// Tela de Catálogo de Permissões
/// Exibe todas as permissões disponíveis no sistema
class PermissionsCatalogScreen extends ConsumerStatefulWidget {
  const PermissionsCatalogScreen({super.key});

  @override
  ConsumerState<PermissionsCatalogScreen> createState() => _PermissionsCatalogScreenState();
}

class _PermissionsCatalogScreenState extends ConsumerState<PermissionsCatalogScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(allPermissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Catálogo de Permissões',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
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
            child: permissionsAsync.when(
              data: (permissions) {
                // Agrupar por categoria
                final permissionsByCategory = <String, List<Permission>>{};
                for (final perm in permissions) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      perm.name.toLowerCase().contains(_searchQuery) ||
                      perm.code.toLowerCase().contains(_searchQuery) ||
                      (perm.description?.toLowerCase().contains(_searchQuery) ?? false);
                  
                  final matchesCategory = _selectedCategory == null || perm.category == _selectedCategory;
                  
                  if (matchesSearch && matchesCategory) {
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

                return Row(
                  children: [
                    // Sidebar de categorias
                    Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'CATEGORIAS',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          ListTile(
                            selected: _selectedCategory == null,
                            leading: const Icon(Icons.all_inclusive),
                            title: const Text('Todas'),
                            trailing: Text(
                              '${permissions.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ...categories.map((category) {
                            final count = permissionsByCategory[category]!.length;
                            return ListTile(
                              selected: _selectedCategory == category,
                              leading: Icon(_getCategoryIcon(category)),
                              title: Text(_formatCategoryName(category)),
                              trailing: Text(
                                '$count',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),

                    // Lista de permissões
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final categoryPermissions = permissionsByCategory[category]!;
                          categoryPermissions.sort((a, b) => a.name.compareTo(b.name));

                          return _buildCategoryCard(context, category, categoryPermissions);
                        },
                      ),
                    ),
                  ],
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
                      'Erro ao carregar permissões',
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
                      onPressed: () => ref.invalidate(allPermissionsProvider),
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

  Widget _buildCategoryCard(BuildContext context, String category, List<Permission> permissions) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da categoria
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatCategoryName(category),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${permissions.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de permissões
          ...permissions.map((permission) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.key,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(
                permission.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    permission.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (permission.description != null) ...[
                    const SizedBox(height: 4),
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
}

