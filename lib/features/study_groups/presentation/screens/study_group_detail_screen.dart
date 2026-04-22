import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../providers/study_group_provider.dart';
import '../../domain/models/study_group.dart';
import '../../../../core/errors/app_error_handler.dart';

class StudyGroupDetailScreen extends ConsumerWidget {
  final String groupId;
  final bool fromDashboard;

  const StudyGroupDetailScreen({
    super.key,
    required this.groupId,
    this.fromDashboard = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(studyGroupByIdProvider(groupId));
    final lessonsAsync = ref.watch(publishedLessonsProvider(groupId));
    final participantsAsync = ref.watch(groupParticipantsProvider(groupId));
    final currentMember = ref.watch(currentMemberProvider).valueOrNull;
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    final currentMemberId = currentMember?.id ?? authUserId;
    final canEditByPermissionAsync = ref.watch(
      currentUserHasPermissionProvider('study_groups.edit'),
    );
    final canManageOwnByPermissionAsync = ref.watch(
      currentUserHasPermissionProvider('study_groups.manage_own'),
    );
    final canManageLessonsByPermissionAsync = ref.watch(
      currentUserHasPermissionProvider('study_groups.manage_lessons'),
    );
    final canManageGroupByContext =
        fromDashboard ||
        canEditByPermissionAsync.valueOrNull == true ||
        canManageOwnByPermissionAsync.valueOrNull == true;
    final canManageLessonsByContext =
        fromDashboard ||
        canManageLessonsByPermissionAsync.valueOrNull == true ||
        canManageGroupByContext;

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Grupo não encontrado')),
            body: const Center(child: Text('Grupo não encontrado')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [
                if (canManageGroupByContext)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar Grupo',
                    onPressed: () {
                      final route = fromDashboard
                          ? '/study-groups/$groupId/edit?from=dashboard'
                          : '/study-groups/$groupId/edit';
                      context.push(route);
                    },
                  )
                else if (currentMemberId != null && currentMemberId.isNotEmpty)
                  FutureBuilder<bool>(
                    future: ref
                        .read(studyGroupRepositoryProvider)
                        .isUserLeader(groupId, currentMemberId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == true) {
                        return IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar Grupo',
                          onPressed: () {
                            final route = fromDashboard
                                ? '/study-groups/$groupId/edit?from=dashboard'
                                : '/study-groups/$groupId/edit';
                            context.push(route);
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.info), text: 'Sobre'),
                  Tab(icon: Icon(Icons.book), text: 'Lições'),
                  Tab(icon: Icon(Icons.people), text: 'Participantes'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Tab 1: Sobre
                _buildAboutTab(context, group),

                // Tab 2: Lições
                lessonsAsync.when(
                  data: (lessons) => _buildLessonsTab(
                    context,
                    ref,
                    group,
                    lessons,
                    currentMemberId ?? '',
                    canManageByPermission: canManageLessonsByContext,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Erro: $error')),
                ),

                // Tab 3: Participantes
                participantsAsync.when(
                  data: (participants) => _buildParticipantsTab(
                    context: context,
                    ref: ref,
                    participants: participants,
                    currentMemberId: currentMemberId,
                    currentMemberDisplayName: currentMember?.displayName,
                    authUserId: authUserId,
                    canManageByPermission: canManageGroupByContext,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Erro: $error')),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context, StudyGroup group) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: group.status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: group.status.color),
                const SizedBox(width: 8),
                Text(
                  group.status.displayName,
                  style: TextStyle(
                    color: group.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tópico de Estudo
          if (group.studyTopic != null) ...[
            Text(
              'Tópico de Estudo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              group.studyTopic!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
          ],

          // Descrição
          if (group.description != null) ...[
            Text(
              'Descrição',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              group.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],

          // Informações
          _buildInfoCard(context, 'Informações do Grupo', [
            if (group.meetingDay != null && group.meetingTime != null)
              _buildInfoRow(
                Icons.schedule,
                'Horário',
                '${group.meetingDay}, ${group.meetingTime}',
              ),
            if (group.meetingLocation != null)
              _buildInfoRow(Icons.place, 'Local', group.meetingLocation!),
            _buildInfoRow(
              Icons.calendar_today,
              'Início',
              '${group.startDate.day}/${group.startDate.month}/${group.startDate.year}',
            ),
            if (group.endDate != null)
              _buildInfoRow(
                Icons.event,
                'Término',
                '${group.endDate!.day}/${group.endDate!.month}/${group.endDate!.year}',
              ),
            _buildInfoRow(
              group.isPublic ? Icons.public : Icons.lock,
              'Visibilidade',
              group.isPublic ? 'Público' : 'Privado',
            ),
            if (group.maxParticipants != null)
              _buildInfoRow(
                Icons.people,
                'Limite de Participantes',
                '${group.maxParticipants}',
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsTab(
    BuildContext context,
    WidgetRef ref,
    StudyGroup group,
    List<StudyLesson> lessons,
    String userId, {
    required bool canManageByPermission,
  }) {
    final canManageFuture = canManageByPermission
        ? Future<bool>.value(true)
        : (userId.isEmpty
              ? Future<bool>.value(false)
              : ref
                    .read(studyGroupRepositoryProvider)
                    .isUserLeader(groupId, userId));

    return Column(
      children: [
        // Botão de adicionar lição (apenas para líderes)
        FutureBuilder<bool>(
          future: canManageFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () {
                    final route = fromDashboard
                        ? '/study-groups/$groupId/lessons/new?from=dashboard'
                        : '/study-groups/$groupId/lessons/new';
                    context.push(route);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Lição'),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Lista de lições
        Expanded(
          child: lessons.isEmpty
              ? const Center(child: Text('Nenhuma lição publicada ainda'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${lesson.lessonNumber}'),
                        ),
                        title: Text(lesson.title),
                        subtitle: lesson.bibleReferences != null
                            ? Text(lesson.bibleReferences!)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final route = fromDashboard
                              ? '/study-groups/$groupId/lessons/${lesson.id}?from=dashboard'
                              : '/study-groups/$groupId/lessons/${lesson.id}';
                          context.push(route);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab({
    required BuildContext context,
    required WidgetRef ref,
    required List<StudyParticipant> participants,
    required String? currentMemberId,
    required String? currentMemberDisplayName,
    required String? authUserId,
    required bool canManageByPermission,
  }) {
    final allMembersAsync = ref.watch(allMembersProvider);
    final canManageFuture = canManageByPermission
        ? Future<bool>.value(true)
        : (currentMemberId == null || currentMemberId.isEmpty)
        ? Future<bool>.value(false)
        : ref
              .read(studyGroupRepositoryProvider)
              .isUserLeader(groupId, currentMemberId);

    return Column(
      children: [
        FutureBuilder<bool>(
          future: canManageFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          _AddStudyParticipantDialog(groupId: groupId),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    participants.isEmpty
                        ? 'Adicionar Primeiro Participante'
                        : 'Adicionar Participante',
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Expanded(
          child: allMembersAsync.when(
            data: (members) {
              final nameById = <String, String>{
                for (final member in members) member.id: member.displayName,
              };
              if (currentMemberId != null &&
                  currentMemberId.isNotEmpty &&
                  currentMemberDisplayName != null &&
                  currentMemberDisplayName.isNotEmpty) {
                nameById[currentMemberId] = currentMemberDisplayName;
                if (authUserId != null && authUserId.isNotEmpty) {
                  nameById[authUserId] = currentMemberDisplayName;
                }
              }
              return _buildParticipantsList(participants, nameById);
            },
            loading: () {
              if (participants.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildParticipantsList(participants, const {});
            },
            error: (_, __) => _buildParticipantsList(participants, const {}),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsList(
    List<StudyParticipant> participants,
    Map<String, String> nameById,
  ) {
    if (participants.isEmpty) {
      return const Center(child: Text('Nenhum participante neste grupo'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final fallbackId = participant.userId.length > 8
            ? participant.userId.substring(0, 8)
            : participant.userId;
        final participantName =
            nameById[participant.userId] ?? 'Usuário $fallbackId';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Icon(participant.role.icon)),
            title: Text(participantName),
            subtitle: Text(participant.role.displayName),
            trailing: participant.isLeader || participant.isCoLeader
                ? Icon(participant.role.icon, color: Colors.amber)
                : null,
          ),
        );
      },
    );
  }
}

class _AddStudyParticipantDialog extends ConsumerStatefulWidget {
  final String groupId;

  const _AddStudyParticipantDialog({required this.groupId});

  @override
  ConsumerState<_AddStudyParticipantDialog> createState() =>
      _AddStudyParticipantDialogState();
}

class _AddStudyParticipantDialogState
    extends ConsumerState<_AddStudyParticipantDialog> {
  String? _selectedMemberId;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final allMembersAsync = ref.watch(allMembersProvider);
    final participantsAsync = ref.watch(
      groupParticipantsProvider(widget.groupId),
    );

    return AlertDialog(
      title: const Text('Adicionar participante'),
      content: SizedBox(
        width: double.maxFinite,
        child: allMembersAsync.when(
          data: (allMembers) {
            return participantsAsync.when(
              data: (participants) {
                final participantIds = participants
                    .map((participant) => participant.userId)
                    .toSet();
                final availableMembers = allMembers
                    .where((member) => !participantIds.contains(member.id))
                    .toList();

                if (_selectedMemberId != null &&
                    !availableMembers.any(
                      (member) => member.id == _selectedMemberId,
                    )) {
                  _selectedMemberId = null;
                }

                if (availableMembers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Todos os membros já participam deste grupo.'),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Selecione um membro',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: availableMembers
                      .map(
                        (member) => DropdownMenuItem<String>(
                          value: member.id,
                          child: Text(member.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _selectedMemberId = value);
                        },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(
                AppErrorHandler.userMessage(
                  error,
                  feature: 'study_groups.load_participants',
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            AppErrorHandler.userMessage(
              error,
              feature: 'study_groups.load_members',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving || _selectedMemberId == null
              ? null
              : _addParticipant,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addParticipant() async {
    final selectedMemberId = _selectedMemberId;
    if (selectedMemberId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(studyGroupActionsProvider)
          .addParticipant(
            groupId: widget.groupId,
            userId: selectedMemberId,
            role: ParticipantRole.participant,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Participante adicionado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'study_groups.add_participant',
        fallbackMessage:
            'Nao foi possivel adicionar o participante. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
