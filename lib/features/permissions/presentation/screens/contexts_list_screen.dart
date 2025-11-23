import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/role_context.dart';
import '../../providers/permissions_providers.dart';

/// Tela de Lista de Contextos
/// Exibe todos os contextos criados com opções de busca, filtro e CRUD
class ContextsListScreen extends ConsumerStatefulWidget {
  const ContextsListScreen({super.key});

  @override
  ConsumerState<ContextsListScreen> createState() => _ContextsListScreenState();
}

class _ContextsListScreenState extends ConsumerState<ContextsListScreen> {
  String _searchQuery = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final contextsAsync = ref.watch(roleContextsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contextos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Ocultar inativos' : 'Mostrar inativos',
            onPressed: () {
              setState(() {
                _showInactive = !_showInactive;
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
                hintText: 'Buscar contextos...',
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

          // Lista de contextos
          Expanded(
            child: contextsAsync.when(
              data: (contexts) {
                // Filtrar contextos
                final filteredContexts = contexts.where((context) {
                  final matchesSearch = context.contextName.toLowerCase().contains(_searchQuery) ||
                      (context.description?.toLowerCase().contains(_searchQuery) ?? false);
                  final matchesActive = _showInactive || context.isActive;
                  return matchesSearch && matchesActive;
                }).toList();

                if (filteredContexts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Nenhum contexto encontrado'
                              : 'Nenhum contexto corresponde à busca',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crie um novo contexto usando o botão +',
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
                  itemCount: filteredContexts.length,
                  itemBuilder: (context, index) {
                    final roleContext = filteredContexts[index];
                    return _buildContextCard(context, roleContext);
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
                      'Erro ao carregar contextos',
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
                      onPressed: () => ref.refresh(roleContextsProvider),
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
        onPressed: () => context.push('/permissions/context-form'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Contexto'),
      ),
    );
  }

  Widget _buildContextCard(BuildContext context, RoleContext roleContext) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: roleContext.isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.location_on,
            color: roleContext.isActive
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                roleContext.contextName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: roleContext.isActive
                      ? null
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            if (!roleContext.isActive)
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
        subtitle: roleContext.description != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  roleContext.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: roleContext.isActive
                        ? null
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, value, roleContext),
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
            PopupMenuItem(
              value: roleContext.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(roleContext.isActive ? Icons.block : Icons.check_circle),
                  const SizedBox(width: 12),
                  Text(roleContext.isActive ? 'Desativar' : 'Ativar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Excluir', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => context.push('/permissions/context-form?id=${roleContext.id}'),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, RoleContext roleContext) {
    switch (action) {
      case 'edit':
        context.push('/permissions/context-form?id=${roleContext.id}');
        break;
      case 'activate':
      case 'deactivate':
        _toggleContextStatus(roleContext);
        break;
      case 'delete':
        _confirmDelete(context, roleContext);
        break;
    }
  }

  Future<void> _toggleContextStatus(RoleContext roleContext) async {
    try {
      final repository = ref.read(roleContextsRepositoryProvider);
      await repository.toggleContextStatus(roleContext.id, !roleContext.isActive);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              roleContext.isActive
                  ? 'Contexto desativado com sucesso'
                  : 'Contexto ativado com sucesso',
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(roleContextsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, RoleContext roleContext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o contexto "${roleContext.contextName}"?\n\n'
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(roleContextsRepositoryProvider);

        // Verificar se o contexto está em uso
        final isInUse = await repository.isContextInUse(roleContext.id);

        if (isInUse) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível excluir um contexto que está em uso'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        await repository.deleteContext(roleContext.id);

        if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contexto excluído com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(roleContextsProvider);
        
      } catch (e) {
        if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir contexto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        
      }
    }
  }
}
