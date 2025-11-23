import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/group_meetings_repository.dart';
import '../providers/meetings_provider.dart';
import '../providers/groups_provider.dart' as groups_providers;
import '../../domain/models/group_meeting.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Tela de detalhes da reunião
class MeetingDetailScreen extends ConsumerWidget {
  final String groupId;
  final String meetingId;

  const MeetingDetailScreen({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingByIdProvider(meetingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Reunião'),
        actions: [
          // Botão de editar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/groups/$groupId/meetings/$meetingId/edit');
            },
          ),
          // Botão de deletar
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: meetingAsync.when(
        data: (meeting) {
          if (meeting == null) {
            return const Center(child: Text('Reunião não encontrada'));
          }
          return _MeetingDetailContent(
            groupId: groupId,
            meeting: meeting,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(meetingByIdProvider(meetingId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Reunião'),
        content: const Text(
          'Tem certeza que deseja deletar esta reunião?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMeeting(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeeting(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(groupMeetingsRepositoryProvider);
      await repository.deleteMeeting(meetingId);

      ref.invalidate(meetingsListProvider(groupId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reunião deletada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar reunião: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Conteúdo da tela de detalhes
class _MeetingDetailContent extends ConsumerStatefulWidget {
  final String groupId;
  final GroupMeeting meeting;

  const _MeetingDetailContent({
    required this.groupId,
    required this.meeting,
  });

  @override
  ConsumerState<_MeetingDetailContent> createState() => _MeetingDetailContentState();
}

class _MeetingDetailContentState extends ConsumerState<_MeetingDetailContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Apenas 2 tabs: Presença e Visitantes
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Header com informações da reunião
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Column(
            children: [
              Icon(
                Icons.event_note,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                dateFormat.format(widget.meeting.meetingDate),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (widget.meeting.topic != null && widget.meeting.topic!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.meeting.topic!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.meeting.totalAttendance} presentes',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notas
        if (widget.meeting.notes != null && widget.meeting.notes!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notes,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notas',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.meeting.notes!),
                  ],
                ),
              ),
            ),
          ),
        ],

        // TabBar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Presença'),
            Tab(icon: Icon(Icons.person_add), text: 'Visitantes'),
          ],
        ),

        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Aba de Presença
              _AttendanceList(
                groupId: widget.groupId,
                meetingId: widget.meeting.id,
              ),
              // Aba de Visitantes (inclui salvações)
              _VisitorsList(
                meetingId: widget.meeting.id,
                groupId: widget.groupId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lista de presença
class _AttendanceList extends ConsumerWidget {
  final String groupId;
  final String meetingId;

  const _AttendanceList({
    required this.groupId,
    required this.meetingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendancesAsync = ref.watch(meetingAttendancesProvider(meetingId));
    final groupMembersAsync = ref.watch(groups_providers.groupMembersProvider(groupId));

    return attendancesAsync.when(
      data: (attendances) {
        return groupMembersAsync.when(
          data: (groupMembers) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Título
                Row(
                  children: [
                    Text(
                      'Lista de Presença',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddAttendanceDialog(
                        context,
                        ref,
                        groupMembers.map((gm) => gm.memberId).toList(),
                        attendances.map((a) => a.memberId).toList(),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lista
                if (attendances.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma presença registrada',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...attendances.map((attendance) {
                    return _AttendanceCard(
                      groupId: groupId,
                      meetingId: meetingId,
                      attendance: attendance,
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  void _showAddAttendanceDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> groupMemberIds,
    List<String> attendedMemberIds,
  ) {
    showDialog(
      context: context,
      builder: (context) => _AddAttendanceDialog(
        groupId: groupId,
        meetingId: meetingId,
        groupMemberIds: groupMemberIds,
        attendedMemberIds: attendedMemberIds,
      ),
    );
  }
}

/// Card de presença
class _AttendanceCard extends ConsumerWidget {
  final String groupId;
  final String meetingId;
  final GroupAttendance attendance;

  const _AttendanceCard({
    required this.groupId,
    required this.meetingId,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: attendance.wasPresent
              ? Colors.green
              : Colors.red,
          child: Icon(
            attendance.wasPresent ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(attendance.memberName ?? 'Membro'),
        subtitle: attendance.notes != null && attendance.notes!.isNotEmpty
            ? Text(attendance.notes!)
            : null,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    attendance.wasPresent ? Icons.close : Icons.check,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(attendance.wasPresent ? 'Marcar Falta' : 'Marcar Presença'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'toggle') {
              await _toggleAttendance(context, ref);
            } else if (value == 'delete') {
              await _deleteAttendance(context, ref);
            }
          },
        ),
      ),
    );
  }

  Future<void> _toggleAttendance(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(groupMeetingsRepositoryProvider);
      await repository.updateAttendance(
        attendance.id,
        {'was_present': !attendance.wasPresent},
      );
      await repository.updateMeetingAttendanceCount(meetingId);

      ref.invalidate(meetingAttendancesProvider(meetingId));
      ref.invalidate(meetingByIdProvider(meetingId));
      ref.invalidate(meetingsListProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAttendance(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(groupMeetingsRepositoryProvider);
      await repository.deleteAttendance(attendance.id);
      await repository.updateMeetingAttendanceCount(meetingId);

      ref.invalidate(meetingAttendancesProvider(meetingId));
      ref.invalidate(meetingByIdProvider(meetingId));
      ref.invalidate(meetingsListProvider(groupId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presença removida!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Dialog para adicionar presença
class _AddAttendanceDialog extends ConsumerStatefulWidget {
  final String groupId;
  final String meetingId;
  final List<String> groupMemberIds;
  final List<String> attendedMemberIds;

  const _AddAttendanceDialog({
    required this.groupId,
    required this.meetingId,
    required this.groupMemberIds,
    required this.attendedMemberIds,
  });

  @override
  ConsumerState<_AddAttendanceDialog> createState() => _AddAttendanceDialogState();
}

class _AddAttendanceDialogState extends ConsumerState<_AddAttendanceDialog> {
  final _notesController = TextEditingController();
  String? _selectedMemberId;
  bool _wasPresent = true;
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
      title: const Text('Adicionar Presença'),
      content: allMembersAsync.when(
        data: (allMembers) {
          // Filtrar apenas membros do grupo que ainda não têm presença registrada
          final availableMembers = allMembers.where((member) {
            return widget.groupMemberIds.contains(member.id) &&
                   !widget.attendedMemberIds.contains(member.id);
          }).toList();

          if (availableMembers.isEmpty) {
            return const Text('Todos os membros do grupo já têm presença registrada.');
          }

          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown de membros
                DropdownButtonFormField<String>(
                  initialValue: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Selecione um membro',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: availableMembers.map((member) {
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

                // Switch de presença/falta
                SwitchListTile(
                  title: Text(_wasPresent ? 'Presente' : 'Ausente'),
                  value: _wasPresent,
                  onChanged: (value) {
                    setState(() {
                      _wasPresent = value;
                    });
                  },
                  secondary: Icon(
                    _wasPresent ? Icons.check_circle : Icons.cancel,
                    color: _wasPresent ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),

                // Notas
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    hintText: 'Ex: Chegou atrasado',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => Text('Erro: $error'),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _addAttendance,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addAttendance() async {
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
      final repository = ref.read(groupMeetingsRepositoryProvider);
      final data = {
        'meeting_id': widget.meetingId,
        'member_id': _selectedMemberId!,
        'was_present': _wasPresent,
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      };

      await repository.recordAttendance(data);
      await repository.updateMeetingAttendanceCount(widget.meetingId);

      ref.invalidate(meetingAttendancesProvider(widget.meetingId));
      ref.invalidate(meetingByIdProvider(widget.meetingId));
      ref.invalidate(meetingsListProvider(widget.groupId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presença registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar presença: $e'),
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
/// Lista de Visitantes
class _VisitorsList extends ConsumerWidget {
  final String meetingId;
  final String groupId;

  const _VisitorsList({
    required this.meetingId,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitorsAsync = ref.watch(groups_providers.visitorsProvider(meetingId));

    return visitorsAsync.when(
      data: (visitors) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título e botão
            Row(
              children: [
                Text(
                  'Visitantes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    // Navegar para tela de cadastro de visitante
                    // Passando meetingId e groupId como query parameters
                    final result = await context.push(
                      '/groups/$groupId/meetings/$meetingId/visitors/new',
                    );

                    // Se retornou sucesso, atualizar lista
                    if (result == true && context.mounted) {
                      ref.invalidate(groups_providers.visitorsProvider(meetingId));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista
            if (visitors.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum visitante registrado',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...visitors.map((visitor) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(visitor.name[0].toUpperCase()),
                    ),
                    title: Text(visitor.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (visitor.phone != null) Text('📞 ${visitor.phone}'),
                        if (visitor.wantsToReturn)
                          const Text(
                            '✅ Quer retornar',
                            style: TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}