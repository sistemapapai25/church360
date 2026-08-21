import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/permission.dart';
import '../permission_category_display.dart';

/// Tela de Catálogo de Permissões
/// Exibe todas as permissões disponíveis no sistema
class PermissionsCatalogScreen extends ConsumerStatefulWidget {
  const PermissionsCatalogScreen({super.key});

  @override
  ConsumerState<PermissionsCatalogScreen> createState() => _PermissionsCatalogScreenState();
}

class _PermissionsCatalogScreenState extends ConsumerState<PermissionsCatalogScreen> {
  String _searchQuery = '';
  bool _showAll = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar permissão...',
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
                  if (_searchQuery.isNotEmpty) {
                    _showAll = true;
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _showAll = true;
                  });
                },
                child: const Text('Ver todas'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de permissões
          Expanded(
            child: permissionsAsync.when(
              data: (permissions) {
                final shouldShowResults = _showAll || _searchQuery.isNotEmpty;
                if (!shouldShowResults) {
                  return Center(
                    child: Text(
                      'Clique em "Ver todas" para listar as permissões.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                // Agrupar por categoria
                final permissionsByCategory = <String, List<Permission>>{};
                for (final perm in permissions) {
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

                final categories = permissionsByCategory.keys.toList()
                  ..sort((a, b) => PermissionCategoryDisplay.label(a)
                      .compareTo(PermissionCategoryDisplay.label(b)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryPermissions = permissionsByCategory[category]!;
                    categoryPermissions.sort((a, b) => a.name.compareTo(b.name));

                    return _buildCategoryCard(context, category, categoryPermissions);
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
                  PermissionCategoryDisplay.icon(category),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    PermissionCategoryDisplay.label(category),
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

}
