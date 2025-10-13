import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/groups_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/group.dart';

/// Tela de formulário de grupo (criar/editar)
class GroupFormScreen extends ConsumerStatefulWidget {
  final String? groupId; // null = criar, não-null = editar

  const GroupFormScreen({
    super.key,
    this.groupId,
  });

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingAddressController = TextEditingController();

  // Valores selecionados
  String? _leaderId;
  int? _meetingDayOfWeek;
  TimeOfDay? _meetingTime;
  bool _isActive = true;

  bool _isLoading = false;
  Group? _existingGroup;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    
    try {
      final group = await ref.read(groupsRepositoryProvider).getGroupById(widget.groupId!);
      
      if (group != null && mounted) {
        setState(() {
          _existingGroup = group;
          _nameController.text = group.name;
          _descriptionController.text = group.description ?? '';
          _meetingAddressController.text = group.meetingAddress ?? '';
          
          _leaderId = group.leaderId;
          _meetingDayOfWeek = group.meetingDayOfWeek;
          _isActive = group.isActive;
          
          // Parse meeting time
          if (group.meetingTime != null) {
            final parts = group.meetingTime!.split(':');
            if (parts.length >= 2) {
              _meetingTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar grupo: $e'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _meetingAddressController.dispose();
    super.dispose();
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(groupsRepositoryProvider);
      
      if (widget.groupId == null) {
        // Criar novo
        final groupData = <String, dynamic>{
          'name': _nameController.text.trim(),
          'is_active': _isActive,
        };
        
        if (_descriptionController.text.trim().isNotEmpty) {
          groupData['description'] = _descriptionController.text.trim();
        }
        if (_leaderId != null) {
          groupData['leader_id'] = _leaderId;
        }
        if (_meetingDayOfWeek != null) {
          groupData['meeting_day_of_week'] = _meetingDayOfWeek;
        }
        if (_meetingTime != null) {
          groupData['meeting_time'] = '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}:00';
        }
        if (_meetingAddressController.text.trim().isNotEmpty) {
          groupData['meeting_address'] = _meetingAddressController.text.trim();
        }
        
        await repo.createGroupFromJson(groupData);
      } else {
        // Atualizar existente
        final group = Group(
          id: widget.groupId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          leaderId: _leaderId,
          meetingDayOfWeek: _meetingDayOfWeek,
          meetingTime: _meetingTime != null
              ? '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}:00'
              : null,
          meetingAddress: _meetingAddressController.text.trim().isEmpty ? null : _meetingAddressController.text.trim(),
          isActive: _isActive,
          createdAt: _existingGroup!.createdAt,
          updatedAt: DateTime.now(),
        );
        
        await repo.updateGroup(group);
      }

      if (mounted) {
        ref.invalidate(allGroupsProvider);
        ref.invalidate(activeGroupsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.groupId == null
                  ? 'Grupo criado com sucesso!'
                  : 'Grupo atualizado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar grupo: $e'),
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

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId == null ? 'Novo Grupo' : 'Editar Grupo'),
      ),
      body: _isLoading && widget.groupId != null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Informações Básicas
                  Text(
                    'Informações Básicas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Grupo *',
                      prefixIcon: Icon(Icons.group),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira o nome do grupo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Status
                  SwitchListTile(
                    title: const Text('Grupo Ativo'),
                    subtitle: Text(_isActive ? 'Este grupo está ativo' : 'Este grupo está inativo'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Liderança
                  Text(
                    'Liderança',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Líder
                  membersAsync.when(
                    data: (members) {
                      return DropdownButtonFormField<String>(
                        value: _leaderId,
                        decoration: const InputDecoration(
                          labelText: 'Líder',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Nenhum'),
                          ),
                          ...members.map((member) {
                            return DropdownMenuItem(
                              value: member.id,
                              child: Text(member.fullName),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() => _leaderId = value);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Erro ao carregar membros'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Informações de Reunião
                  Text(
                    'Reuniões',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Dia da semana
                  DropdownButtonFormField<int>(
                    value: _meetingDayOfWeek,
                    decoration: const InputDecoration(
                      labelText: 'Dia da Semana',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Não definido')),
                      DropdownMenuItem(value: 0, child: Text('Domingo')),
                      DropdownMenuItem(value: 1, child: Text('Segunda-feira')),
                      DropdownMenuItem(value: 2, child: Text('Terça-feira')),
                      DropdownMenuItem(value: 3, child: Text('Quarta-feira')),
                      DropdownMenuItem(value: 4, child: Text('Quinta-feira')),
                      DropdownMenuItem(value: 5, child: Text('Sexta-feira')),
                      DropdownMenuItem(value: 6, child: Text('Sábado')),
                    ],
                    onChanged: (value) {
                      setState(() => _meetingDayOfWeek = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Horário
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text('Horário'),
                    subtitle: Text(
                      _meetingTime != null
                          ? _meetingTime!.format(context)
                          : 'Não definido',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _meetingTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => _meetingTime = time);
                      }
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _meetingAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Local da Reunião',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botão de salvar
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveGroup,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.groupId == null ? 'Criar Grupo' : 'Salvar Alterações'),
                  ),
                ],
              ),
            ),
    );
  }
}

