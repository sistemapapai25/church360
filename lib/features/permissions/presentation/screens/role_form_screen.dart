import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/permissions_providers.dart';

/// Tela de Formulário de Cargo
/// Criar ou editar um cargo
class RoleFormScreen extends ConsumerStatefulWidget {
  final String? roleId;

  const RoleFormScreen({super.key, this.roleId});

  @override
  ConsumerState<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends ConsumerState<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedParentRoleId;
  bool _allowsContext = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.roleId != null) {
      _loadRole();
    }
  }

  Future<void> _loadRole() async {
    try {
      final role = await ref.read(roleByIdProvider(widget.roleId!).future);

      if (role != null && mounted) {
        setState(() {
          _nameController.text = role.name;
          _descriptionController.text = role.description ?? '';
          _selectedParentRoleId = role.parentRoleId;
          _allowsContext = role.allowsContext;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar cargo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.roleId != null;
    final allRolesAsync = ref.watch(allRolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Cargo' : 'Novo Cargo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de informações básicas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações Básicas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nome do cargo
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Cargo *',
                        hintText: 'Ex: Líder de Louvor',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nome é obrigatório';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Descreva as responsabilidades deste cargo',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card de hierarquia
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hierarquia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Defina se este cargo está subordinado a outro cargo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cargo superior
                    allRolesAsync.when(
                      data: (roles) {
                        // Filtrar cargos ativos e excluir o cargo atual (se editando)
                        final availableRoles = roles.where((r) {
                          return r.isActive && r.id != widget.roleId;
                        }).toList();

                        return DropdownMenu<String?>(
                          initialSelection: _selectedParentRoleId,
                          label: const Text('Cargo Superior'),
                          dropdownMenuEntries: [
                            const DropdownMenuEntry<String?>(
                              value: null,
                              label: 'Nenhum (cargo raiz)',
                            ),
                            ...availableRoles.map((role) => DropdownMenuEntry<String?>(
                                  value: role.id,
                                  label: '${role.name} (Nível ${role.hierarchyLevel})',
                                )),
                          ],
                          onSelected: (value) {
                            setState(() {
                              _selectedParentRoleId = value;
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => Text(
                        'Erro ao carregar cargos: $error',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),

                    if (_selectedParentRoleId != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'O nível hierárquico será calculado automaticamente',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card de contextos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contextos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contextos permitem criar instâncias específicas deste cargo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      value: _allowsContext,
                      onChanged: (value) {
                        setState(() {
                          _allowsContext = value;
                        });
                      },
                      title: const Text('Permite Contextos'),
                      subtitle: const Text(
                        'Ex: "Líder Casa de Oração - Dona Joana"',
                      ),
                      secondary: const Icon(Icons.location_on),
                    ),

                    if (_allowsContext) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Exemplos de uso:',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Líder Casa de Oração - Dona Joana\n'
                              '• Líder Capelania - Hospital São Lucas\n'
                              '• Coordenador Zona - Zona Sul',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveRole,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Salvar' : 'Criar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(rolesRepositoryProvider);
      
      if (widget.roleId != null) {
        // Editar cargo existente
        await repository.updateRole(
          roleId: widget.roleId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          parentRoleId: _selectedParentRoleId,
          allowsContext: _allowsContext,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargo atualizado com sucesso!')),
          );
        }
      } else {
        // Criar novo cargo
        await repository.createRole(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          parentRoleId: _selectedParentRoleId,
          allowsContext: _allowsContext,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargo criado com sucesso!')),
          );
        }
      }

      // Invalidar cache
      ref.invalidate(allRolesProvider);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar cargo: $e'),
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
