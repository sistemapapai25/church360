import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/permissions_providers.dart';

/// Tela de Formulário de Contexto
/// Permite criar ou editar um contexto específico de um cargo
class ContextFormScreen extends ConsumerStatefulWidget {
  final String? contextId;

  const ContextFormScreen({
    super.key,
    this.contextId,
  });

  @override
  ConsumerState<ContextFormScreen> createState() => _ContextFormScreenState();
}

class _ContextFormScreenState extends ConsumerState<ContextFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contextId != null) {
      _loadContext();
    }
  }

  Future<void> _loadContext() async {
    try {
      final contexts = await ref.read(roleContextsProvider.future);
      final context = contexts.firstWhere((c) => c.id == widget.contextId);
      
      setState(() {
        _nameController.text = context.contextName;
        _descriptionController.text = context.description ?? '';
        _selectedRoleId = context.roleId;
        _isActive = context.isActive;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar contexto: $e'),
            backgroundColor: Colors.red,
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
    final rolesAsync = ref.watch(allRolesProvider);
    final isEditing = widget.contextId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Contexto' : 'Novo Contexto',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: rolesAsync.when(
        data: (roles) {
          // Filtrar apenas cargos que permitem contextos
          final rolesWithContext = roles.where((r) => r.allowsContext && r.isActive).toList();

          if (rolesWithContext.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum cargo permite contextos',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para criar contextos, primeiro crie um cargo e marque a opção "Permite Contextos".',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/permissions/roles'),
                      icon: const Icon(Icons.badge),
                      label: const Text('Ir para Cargos'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Informações Básicas
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

                        // Nome do Contexto
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Contexto *',
                            hintText: 'Ex: Casa de Oração - Dona Joana',
                            prefixIcon: Icon(Icons.location_on),
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
                            hintText: 'Informações adicionais sobre o contexto',
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

                // Cargo Associado
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cargo Associado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selecione o cargo ao qual este contexto pertence',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownMenu<String>(
                          initialSelection: _selectedRoleId,
                          label: const Text('Cargo *'),
                          leadingIcon: const Icon(Icons.badge),
                          dropdownMenuEntries: rolesWithContext
                              .map((role) => DropdownMenuEntry<String>(
                                    value: role.id,
                                    label: role.name,
                                  ))
                              .toList(),
                          onSelected: (value) {
                            setState(() {
                              _selectedRoleId = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status
                Card(
                  child: SwitchListTile(
                    title: const Text('Contexto Ativo'),
                    subtitle: Text(
                      _isActive
                          ? 'Este contexto pode ser atribuído a usuários'
                          : 'Este contexto não pode ser atribuído',
                    ),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
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
                        onPressed: _isLoading ? null : _saveContext,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
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
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveContext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(roleContextsRepositoryProvider);

      if (widget.contextId != null) {
        // Editar contexto existente
        await repository.updateContext(
          contextId: widget.contextId!,
          contextName: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
      } else {
        // Criar novo contexto
        await repository.createContext(
          roleId: _selectedRoleId!,
          contextName: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.contextId != null
                  ? 'Contexto atualizado com sucesso'
                  : 'Contexto criado com sucesso',
            ),
            backgroundColor: Colors.green,
          ),
        );

        ref.invalidate(roleContextsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar contexto: $e'),
            backgroundColor: Colors.red,
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
