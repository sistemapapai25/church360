import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/groups_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/group.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de formulário de grupo (criar/editar)
class GroupFormScreen extends ConsumerStatefulWidget {
  final String? groupId; // null = criar, não-null = editar

  const GroupFormScreen({super.key, this.groupId});

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
  String? _hostId; // Anfitrião
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
      final group = await ref
          .read(groupsRepositoryProvider)
          .getGroupById(widget.groupId!);

      if (group != null && mounted) {
        setState(() {
          _existingGroup = group;
          _nameController.text = group.name;
          _descriptionController.text = group.description ?? '';
          _meetingAddressController.text = group.meetingAddress ?? '';

          _leaderId = group.leaderId;
          _hostId = group.hostId;
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
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'groups.admin.load_group',
          fallbackMessage:
              'Nao foi possivel carregar o grupo. Tente novamente.',
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

    final requiredPermission = widget.groupId == null
        ? 'groups.create'
        : 'groups.edit';
    final hasPermission = await ref.read(
      currentUserHasPermissionProvider(requiredPermission).future,
    );
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para esta ação'),
          ),
        );
      }
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
          groupData['leader_user_id'] = _leaderId;
        }
        if (_hostId != null) {
          groupData['host_user_id'] = _hostId;
        }
        if (_meetingDayOfWeek != null) {
          groupData['meeting_day_of_week'] = _meetingDayOfWeek;
        }
        if (_meetingTime != null) {
          groupData['meeting_time'] =
              '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}:00';
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
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          leaderId: _leaderId,
          hostId: _hostId,
          meetingDayOfWeek: _meetingDayOfWeek,
          meetingTime: _meetingTime != null
              ? '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}:00'
              : null,
          meetingAddress: _meetingAddressController.text.trim().isEmpty
              ? null
              : _meetingAddressController.text.trim(),
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
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'groups.admin.save_group',
          fallbackMessage:
              'Nao foi possivel salvar o grupo. Revise e tente novamente.',
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
    final statusBadge = _isActive
        ? const StatusBadge.active(label: 'Ativo', icon: AppIcons.checkCircle)
        : const StatusBadge.dropped(label: 'Inativo', icon: AppIcons.groupOff);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.groupId == null ? 'Novo Grupo' : 'Editar Grupo',
          style: CommunityDesign.titleStyle(context),
        ),
      ),
      body: _isLoading && widget.groupId != null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(
                    title: 'Informações Básicas',
                    icon: AppIcons.group,
                    trailing: statusBadge,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Grupo *',
                          prefixIcon: Icon(AppIcons.group),
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
                          prefixIcon: Icon(AppIcons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Grupo Ativo'),
                        subtitle: Text(
                          _isActive
                              ? 'Este grupo está ativo'
                              : 'Este grupo está inativo',
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Liderança',
                    icon: AppIcons.supervisor,
                    children: [
                      membersAsync.when(
                        data: (members) => DropdownButtonFormField<String>(
                          initialValue: _leaderId,
                          decoration: const InputDecoration(
                            labelText: 'Líder',
                            prefixIcon: Icon(AppIcons.person),
                            helperText:
                                'Pessoa responsável por liderar o grupo',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Nenhum'),
                            ),
                            ...members.map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(member.displayName),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _leaderId = value),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) =>
                            const Text('Erro ao carregar membros'),
                      ),
                      const SizedBox(height: 16),
                      membersAsync.when(
                        data: (members) => DropdownButtonFormField<String>(
                          initialValue: _hostId,
                          decoration: const InputDecoration(
                            labelText: 'Anfitrião',
                            prefixIcon: Icon(AppIcons.home),
                            helperText: 'Pessoa que abriu a casa para o grupo',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Nenhum'),
                            ),
                            ...members.map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(member.displayName),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() => _hostId = value),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) =>
                            const Text('Erro ao carregar membros'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Reuniões',
                    icon: AppIcons.eventNote,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _meetingDayOfWeek,
                        decoration: const InputDecoration(
                          labelText: 'Dia da Semana',
                          prefixIcon: Icon(AppIcons.calendarFilled),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Não definido'),
                          ),
                          DropdownMenuItem(value: 0, child: Text('Domingo')),
                          DropdownMenuItem(
                            value: 1,
                            child: Text('Segunda-feira'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Terça-feira'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('Quarta-feira'),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text('Quinta-feira'),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text('Sexta-feira'),
                          ),
                          DropdownMenuItem(value: 6, child: Text('Sábado')),
                        ],
                        onChanged: (value) =>
                            setState(() => _meetingDayOfWeek = value),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(AppIcons.accessTime),
                        title: const Text('Horário'),
                        subtitle: Text(
                          _meetingTime != null
                              ? _meetingTime!.format(context)
                              : 'Não definido',
                        ),
                        trailing: const Icon(AppIcons.edit),
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
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _meetingAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Local da Reunião',
                          prefixIcon: Icon(AppIcons.location),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DisabledByPermission(
                    permission: widget.groupId == null
                        ? 'groups.create'
                        : 'groups.edit',
                    disabledTooltip: 'Você não tem permissão para esta ação',
                    child: FilledButton.icon(
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
                          : const Icon(AppIcons.save),
                      label: Text(
                        widget.groupId == null
                            ? 'Criar Grupo'
                            : 'Salvar Alterações',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
