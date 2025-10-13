import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ministries_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/ministry.dart';

/// Tela de detalhes do ministério
class MinistryDetailScreen extends ConsumerWidget {
  final String ministryId;

  const MinistryDetailScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministryAsync = ref.watch(ministryByIdProvider(ministryId));

    return ministryAsync.when(
      data: (ministry) {
        if (ministry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ministério')),
            body: const Center(child: Text('Ministério não encontrado')),
          );
        }

        return _MinistryDetailContent(ministry: ministry);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Ministério')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Ministério')),
        body: Center(child: Text('Erro: $error')),
      ),
    );
  }
}

/// Conteúdo da tela de detalhes
class _MinistryDetailContent extends ConsumerWidget {
  final Ministry ministry;

  const _MinistryDetailContent({required this.ministry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorValue = int.tryParse(ministry.color) ?? 0xFF2196F3;
    final color = Color(colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(ministry.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/ministries/${ministry.id}/edit');
            },
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
            tooltip: 'Deletar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header com informações do ministério
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.church,
                      color: color,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ministry.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (ministry.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      ministry.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ministry.isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ministry.isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              ministry.isActive ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: ministry.isActive ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ministry.isActive ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ministry.isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Seção de membros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Membros do Ministério',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddMemberDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de membros
          _MembersList(ministryId: ministry.id),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o ministério "${ministry.name}"?\n\n'
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
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.deleteMinistry(ministry.id);

        ref.invalidate(allMinistriesProvider);
        ref.invalidate(activeMinistriesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ministério excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir ministério: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(ministryId: ministry.id),
    );
  }
}

/// Lista de membros do ministério
class _MembersList extends ConsumerWidget {
  final String ministryId;

  const _MembersList({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum membro neste ministério',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: members.map((member) {
            return _MemberCard(
              member: member,
              ministryId: ministryId,
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Erro: $error'),
    );
  }
}

/// Card de membro do ministério
class _MemberCard extends ConsumerWidget {
  final MinistryMember member;
  final String ministryId;

  const _MemberCard({
    required this.member,
    required this.ministryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(member.role).withOpacity(0.2),
          child: Icon(
            _getRoleIcon(member.role),
            color: _getRoleColor(member.role),
          ),
        ),
        title: Text(member.memberName),
        subtitle: Text(_getRoleLabel(member.role)),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar Função'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditRoleDialog(context, ref);
            } else if (value == 'remove') {
              _confirmRemove(context, ref);
            }
          },
        ),
      ),
    );
  }

  Color _getRoleColor(MinistryRole role) {
    switch (role) {
      case MinistryRole.leader:
        return Colors.purple;
      case MinistryRole.coordinator:
        return Colors.blue;
      case MinistryRole.member:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(MinistryRole role) {
    switch (role) {
      case MinistryRole.leader:
        return Icons.star;
      case MinistryRole.coordinator:
        return Icons.supervisor_account;
      case MinistryRole.member:
        return Icons.person;
    }
  }

  String _getRoleLabel(MinistryRole role) {
    return role.label;
  }

  Future<void> _showEditRoleDialog(BuildContext context, WidgetRef ref) async {
    MinistryRole? selectedRole = member.role;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Função'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: MinistryRole.values.map((role) {
              return RadioListTile<MinistryRole>(
                title: Text(role.label),
                value: role,
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedRole != null && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.updateMinistryMember(
          member.id,
          {'role': selectedRole!.value},
        );

        ref.invalidate(ministryMembersProvider(ministryId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar função: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Tem certeza que deseja remover ${member.memberName} deste ministério?',
        ),
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
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.removeMinistryMember(member.id);

        ref.invalidate(ministryMembersProvider(ministryId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membro removido com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover membro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Diálogo para adicionar membro ao ministério
class _AddMemberDialog extends ConsumerStatefulWidget {
  final String ministryId;

  const _AddMemberDialog({required this.ministryId});

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  String? _selectedMemberId;
  MinistryRole _selectedRole = MinistryRole.member;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMembersAsync = ref.watch(allMembersProvider);

    return AlertDialog(
      title: const Text('Adicionar Membro'),
      content: SizedBox(
        width: double.maxFinite,
        child: allMembersAsync.when(
          data: (allMembers) {
            if (allMembers.isEmpty) {
              return const Text('Nenhum membro disponível');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seletor de membro
                DropdownButtonFormField<String>(
                  value: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Selecione o Membro',
                    border: OutlineInputBorder(),
                  ),
                  items: allMembers.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text('${member.firstName} ${member.lastName}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMemberId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Seletor de função
                DropdownButtonFormField<MinistryRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Função',
                    border: OutlineInputBorder(),
                  ),
                  items: MinistryRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Notas
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Erro: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _addMember,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um membro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(ministriesRepositoryProvider);
      await repository.addMinistryMember({
        'ministry_id': widget.ministryId,
        'member_id': _selectedMemberId,
        'role': _selectedRole.value,
        'joined_at': DateTime.now().toIso8601String().split('T')[0],
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      });

      ref.invalidate(ministryMembersProvider(widget.ministryId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar membro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

