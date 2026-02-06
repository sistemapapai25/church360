import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../providers/groups_provider.dart';
import '../providers/meetings_provider.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_meeting.dart' as meeting_models;
import '../../../members/presentation/providers/members_provider.dart';
import '../../../support_materials/presentation/providers/support_materials_provider.dart';
import '../../../support_materials/domain/models/support_material.dart';
import '../../../support_materials/domain/models/support_material_link.dart';

/// Tela de detalhes do grupo
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(groupId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text('Detalhes do Grupo', style: CommunityDesign.titleStyle(context)),
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        actions: [
          // Botão de editar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/groups/$groupId/edit');
            },
          ),
          // Botão de deletar
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(
              child: Text('Grupo não encontrado'),
            );
          }
          return _GroupDetailContent(group: group);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar grupo: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupByIdProvider(groupId)),
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
        title: const Text('Deletar Grupo'),
        content: const Text(
          'Tem certeza que deseja deletar este grupo?\n\n'
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
              await _deleteGroup(context, ref);
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

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(groupsRepositoryProvider);
      await repo.deleteGroup(groupId);

      if (context.mounted) {
        ref.invalidate(allGroupsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupo deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar grupo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Conteúdo da tela de detalhes
class _GroupDetailContent extends ConsumerWidget {
  final Group group;

  const _GroupDetailContent({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Header com informações do grupo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                // Ícone
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(
                    Icons.group,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Nome
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Status
                if (!group.isActive)
                  Chip(
                    label: const Text(
                      'Inativo',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.grey,
                  ),

                const SizedBox(height: 16),

                // Contagem de membros
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
                        '${group.memberCount ?? 0} membros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            tabs: const [
              Tab(text: 'Informações', icon: Icon(Icons.info_outline)),
              Tab(text: 'Membros', icon: Icon(Icons.people_outline)),
              Tab(text: 'Reuniões', icon: Icon(Icons.event_note)),
              Tab(text: 'Materiais', icon: Icon(Icons.library_books)),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                _InfoTab(group: group),
                _MembersTab(groupId: group.id),
                _MeetingsTab(groupId: group.id),
                _MaterialsTab(groupId: group.id, groupName: group.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab de informações
class _InfoTab extends StatelessWidget {
  final Group group;

  const _InfoTab({required this.group});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descrição
          if (group.description != null && group.description!.isNotEmpty) ...[
            _SectionTitle(title: 'Descrição'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(group.description!),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Líder
          if (group.leaderName != null) ...[
            _SectionTitle(title: 'Liderança'),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.person,
              label: 'Líder',
              value: group.leaderName!,
            ),
            const SizedBox(height: 24),
          ],
          
          // Informações de Reunião
          _SectionTitle(title: 'Reuniões'),
          const SizedBox(height: 12),
          if (group.meetingDayName != null)
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Dia da Semana',
              value: group.meetingDayName!,
            ),
          if (group.meetingTime != null)
            _InfoTile(
              icon: Icons.access_time,
              label: 'Horário',
              value: group.meetingTime!,
            ),
          if (group.meetingAddress != null)
            _InfoTile(
              icon: Icons.location_on,
              label: 'Local',
              value: group.meetingAddress!,
            ),
        ],
      ),
    );
  }
}

/// Tab de membros
class _MembersTab extends ConsumerWidget {
  final String groupId;

  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum membro neste grupo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddMemberDialog(context, ref, groupId),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Adicionar Primeiro Membro'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      member.memberName?.substring(0, 1).toUpperCase() ?? '?',
                    ),
                  ),
                  title: Text(member.memberName ?? 'Nome não disponível'),
                  subtitle: member.role != null && member.role != 'member'
                      ? Text(
                          member.role == 'leader' ? 'Líder' : member.role!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Desde ${DateFormat('dd/MM/yyyy').format(member.joinedDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _showRemoveMemberDialog(
                          context,
                          ref,
                          groupId,
                          member.memberId,
                          member.memberName ?? 'este membro',
                        ),
                        tooltip: 'Remover do grupo',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erro ao carregar membros: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context, ref, groupId),
        icon: const Icon(Icons.person_add),
        label: const Text('Adicionar Membro'),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref, String groupId) {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(groupId: groupId),
    );
  }

  void _showRemoveMemberDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String memberId,
    String memberName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Membro'),
        content: Text(
          'Tem certeza que deseja remover $memberName deste grupo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeMember(context, ref, groupId, memberId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String memberId,
  ) async {
    try {
      final repo = ref.read(groupsRepositoryProvider);
      await repo.removeMemberFromGroup(groupId, memberId);

      if (context.mounted) {
        ref.invalidate(groupMembersProvider(groupId));
        ref.invalidate(groupByIdProvider(groupId));

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

/// Título de seção
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

/// Tile de informação
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog para adicionar membro ao grupo
class _AddMemberDialog extends ConsumerStatefulWidget {
  final String groupId;

  const _AddMemberDialog({required this.groupId});

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  String? _selectedMemberId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final allMembersAsync = ref.watch(allMembersProvider);
    final groupMembersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return AlertDialog(
      title: const Text('Adicionar Membro ao Grupo'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            allMembersAsync.when(
              data: (allMembers) {
                return groupMembersAsync.when(
                  data: (groupMembers) {
                    // Filtrar membros que já estão no grupo
                    final groupMemberIds = groupMembers.map((gm) => gm.memberId).toSet();
                    final availableMembers = allMembers
                        .where((m) => !groupMemberIds.contains(m.id))
                        .toList();

                    if (availableMembers.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Todos os membros já estão neste grupo!',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // Garantir que o valor selecionado está na lista
                    if (_selectedMemberId != null &&
                        !availableMembers.any((m) => m.id == _selectedMemberId)) {
                      _selectedMemberId = null;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedMemberId,
                      decoration: const InputDecoration(
                        labelText: 'Selecione um membro',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: availableMembers.map((member) {
                        return DropdownMenuItem(
                          value: member.id,
                          child: Text(member.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedMemberId = value);
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Erro ao carregar membros do grupo'),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Erro ao carregar membros'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading || _selectedMemberId == null
              ? null
              : () => _addMember(),
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

  Future<void> _addMember() async {
    if (_selectedMemberId == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(groupsRepositoryProvider);
      await repo.addMemberToGroup(
        groupId: widget.groupId,
        memberId: _selectedMemberId!,
      );

      if (mounted) {
        ref.invalidate(groupMembersProvider(widget.groupId));
        ref.invalidate(groupByIdProvider(widget.groupId));

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
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

/// Tab de Reuniões
class _MeetingsTab extends ConsumerWidget {
  final String groupId;

  const _MeetingsTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsListProvider(groupId));

    return meetingsAsync.when(
      data: (meetings) {
        if (meetings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma reunião registrada',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/groups/$groupId/meetings/new');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Primeira Reunião'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: meetings.length,
              itemBuilder: (context, index) {
                final meeting = meetings[index];
                return _MeetingCard(meeting: meeting);
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  context.push('/groups/$groupId/meetings/new');
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar reuniões: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(meetingsListProvider(groupId)),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de Reunião
class _MeetingCard extends StatelessWidget {
  final meeting_models.GroupMeeting meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/groups/${meeting.groupId}/meetings/${meeting.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data e presença
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(meeting.meetingDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${meeting.totalAttendance}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Tópico
              if (meeting.topic != null && meeting.topic!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  meeting.topic!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],

              // Notas (preview)
              if (meeting.notes != null && meeting.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meeting.notes!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab de Materiais de Apoio
class _MaterialsTab extends ConsumerWidget {
  final String groupId;
  final String groupName;

  const _MaterialsTab({
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Buscar materiais vinculados a este grupo
    final materialsAsync = ref.watch(
      materialsByEntityProvider((
        linkType: MaterialLinkType.communionGroup,
        entityId: groupId,
      )),
    );

    return materialsAsync.when(
      data: (materials) {
        if (materials.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum material vinculado',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Materiais de apoio vinculados a "$groupName"\naparecerão aqui',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            return _MaterialCard(material: material);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar materiais: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(materialsByEntityProvider);
              },
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de Material
class _MaterialCard extends StatelessWidget {
  final SupportMaterial material;

  const _MaterialCard({required this.material});

  IconData _getIconForType(SupportMaterialType type) {
    switch (type) {
      case SupportMaterialType.pdf:
        return Icons.picture_as_pdf;
      case SupportMaterialType.powerpoint:
        return Icons.slideshow;
      case SupportMaterialType.video:
        return Icons.video_library;
      case SupportMaterialType.text:
        return Icons.article;
      case SupportMaterialType.audio:
        return Icons.audiotrack;
      case SupportMaterialType.link:
        return Icons.link;
      case SupportMaterialType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(SupportMaterialType type) {
    switch (type) {
      case SupportMaterialType.pdf:
        return Colors.red;
      case SupportMaterialType.powerpoint:
        return Colors.orange;
      case SupportMaterialType.video:
        return Colors.blue;
      case SupportMaterialType.text:
        return Colors.green;
      case SupportMaterialType.audio:
        return Colors.purple;
      case SupportMaterialType.link:
        return Colors.teal;
      case SupportMaterialType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/support-materials/${material.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone do tipo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getColorForType(material.materialType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForType(material.materialType),
                  color: _getColorForType(material.materialType),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Título e descrição
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getColorForType(material.materialType),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            material.materialType.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (material.author != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Por ${material.author}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (material.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        material.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
