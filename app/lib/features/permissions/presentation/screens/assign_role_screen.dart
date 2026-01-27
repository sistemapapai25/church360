import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/role.dart';
import '../../../members/domain/models/member.dart';
import '../../../members/presentation/providers/members_provider.dart';

class _ContextOption {
  const _ContextOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _ContextOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Tela de Atribuir Cargo a Usuário
/// Permite atribuir um cargo (com contexto opcional) a um usuário
class AssignRoleScreen extends ConsumerStatefulWidget {
  const AssignRoleScreen({super.key});

  @override
  ConsumerState<AssignRoleScreen> createState() => _AssignRoleScreenState();
}

class _AssignRoleScreenState extends ConsumerState<AssignRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserEmail;
  String? _selectedRoleId;
  String? _selectedContextId;
  DateTime? _expiresAt;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRolesAsync = ref.watch(allRolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Atribuir Cargo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de seleção de usuário
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecionar Usuário',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de seleção de usuário
                    TextFormField(
                      controller: TextEditingController(text: _selectedUserName ?? ''),
                      decoration: InputDecoration(
                        labelText: 'Usuário *',
                        hintText: 'Clique para buscar um usuário',
                        prefixIcon: const Icon(Icons.person_search),
                        border: const OutlineInputBorder(),
                        suffixIcon: _selectedUserId != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _selectedUserId = null;
                                    _selectedUserName = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      validator: (value) {
                        if (_selectedUserId == null) {
                          return 'Selecione um usuário';
                        }
                        return null;
                      },
                      onTap: () => _showUserSearchDialog(),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card de seleção de cargo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecionar Cargo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    allRolesAsync.when(
                      data: (roles) {
                        final activeRoles = roles.where((r) => r.isActive).toList();

                        return DropdownMenu<String>(
                          initialSelection: _selectedRoleId,
                          label: const Text('Cargo *'),
                          leadingIcon: const Icon(Icons.badge),
                          dropdownMenuEntries: activeRoles
                              .map((role) => DropdownMenuEntry<String>(
                                    value: role.id,
                                    label: role.name,
                                  ))
                              .toList(),
                          onSelected: (value) {
                            setState(() {
                              _selectedRoleId = value;
                              _selectedContextId = null; // Reset context
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

                    // Contexto (se o cargo permitir)
                    if (_selectedRoleId != null) ...[
                      const SizedBox(height: 16),
                      allRolesAsync.when(
                        data: (roles) {
                          final selectedRole = roles.firstWhere((r) => r.id == _selectedRoleId);
                          
                          if (!selectedRole.allowsContext) {
                            return const SizedBox.shrink();
                          }

                          return _buildContextSelector(selectedRole);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card de configurações adicionais
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configurações Adicionais',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data de expiração
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Data de Expiração'),
                      subtitle: Text(
                        _expiresAt == null
                            ? 'Sem expiração'
                            : 'Expira em: ${_formatDate(_expiresAt!)}',
                      ),
                      trailing: _expiresAt == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _expiresAt = null;
                                });
                              },
                            ),
                      onTap: () => _selectExpirationDate(),
                    ),

                    const Divider(),

                    // Notas
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        hintText: 'Observações sobre esta atribuição',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
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
                    onPressed: _isLoading ? null : _assignRole,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Atribuir'),
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

  Widget _buildContextSelector(Role role) {
    final contextsAsync = ref.watch(contextsByRoleProvider(role.id));

    return contextsAsync.when(
      data: (contexts) {
        if (contexts.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nenhum contexto cadastrado para este cargo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  context.push('/permissions/context-form');
                },
                icon: const Icon(Icons.add),
                label: const Text('Criar Contexto'),
              ),
            ],
          );
        }

        final options = <_ContextOption>[
          const _ContextOption(null, 'Nenhum contexto específico'),
          ...contexts.map((context) => _ContextOption(context.id, context.contextName)),
        ];
        final selectedOption = options.firstWhere(
          (option) => option.value == _selectedContextId,
          orElse: () => options.first,
        );

        return DropdownMenu<_ContextOption>(
          initialSelection: selectedOption,
          label: const Text('Contexto'),
          leadingIcon: const Icon(Icons.location_on),
          dropdownMenuEntries: options
            .map((option) => DropdownMenuEntry<_ContextOption>(
              value: option,
              label: option.label,
            ))
            .toList(),
          onSelected: (option) {
            setState(() {
              _selectedContextId = option?.value;
            });
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text(
        'Erro ao carregar contextos: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Future<void> _showUserSearchDialog() async {
    final selected = await showDialog<Member>(
      context: context,
      builder: (context) => const _UserSearchDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedUserId = selected.id;
        _selectedUserName = '${selected.firstName} ${selected.lastName}';
        _selectedUserEmail = selected.email;
      });
    }
  }

  Future<void> _selectExpirationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 anos
    );

    if (date != null) {
      setState(() {
        _expiresAt = date;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _assignRole() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(userRolesRepositoryProvider);

      String? authUserId;

      if (_selectedUserId != null) {
        final supabase = ref.read(supabaseClientProvider);
        final existingAccess = await supabase
            .from('user_access_level')
            .select('user_id')
            .eq('user_id', _selectedUserId!)
            .maybeSingle();

        if (existingAccess != null) {
          authUserId = existingAccess['user_id'] as String;
        }
      }

      if (authUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _selectedUserEmail == null || _selectedUserEmail!.isEmpty
                    ? 'O membro selecionado não possui email cadastrado'
                    : 'Este membro ainda não possui conta criada no Auth. Peça para ele se cadastrar.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      await repository.assignRole(
        userId: authUserId,
        roleId: _selectedRoleId!,
        contextId: _selectedContextId,
        expiresAt: _expiresAt,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cargo atribuído com sucesso!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atribuir cargo: $e'),
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

/// Dialog de busca de usuários
class _UserSearchDialog extends ConsumerStatefulWidget {
  const _UserSearchDialog();

  @override
  ConsumerState<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<_UserSearchDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(searchMembersProvider(_searchQuery));

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título
            Row(
              children: [
                const Icon(Icons.person_search),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Buscar Usuário',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Digite o nome do usuário...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.trim().isNotEmpty
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
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Lista de resultados
            Expanded(
              child: membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Digite para buscar usuários'
                                : 'Nenhum usuário encontrado',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        leading: Builder(builder: (context) {
                          final rawUrl = member.photoUrl;
                          String? resolvedUrl;
                          if (rawUrl != null && rawUrl.isNotEmpty) {
                            final parsed = Uri.tryParse(rawUrl);
                            if (parsed != null && parsed.hasScheme) {
                              resolvedUrl = rawUrl;
                            } else {
                              resolvedUrl = Supabase.instance.client.storage
                                  .from('member-photos')
                                  .getPublicUrl(rawUrl);
                            }
                          }

                          return CircleAvatar(
                            child: resolvedUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      resolvedUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Text(member.initials);
                                      },
                                    ),
                                  )
                                : Text(member.initials),
                          );
                        }),
                        title: Text(member.displayName),
                        subtitle: Text(member.email),
                        onTap: () => Navigator.pop(context, member),
                      );
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
                        'Erro ao buscar usuários',
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
            ),
          ],
        ),
      ),
    );
  }
}
