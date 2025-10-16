import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/study_group_provider.dart';
import '../../domain/models/study_group.dart';

class StudyGroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const StudyGroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(studyGroupByIdProvider(groupId));
    final lessonsAsync = ref.watch(publishedLessonsProvider(groupId));
    final participantsAsync = ref.watch(groupParticipantsProvider(groupId));
    final currentUser = Supabase.instance.client.auth.currentUser;

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
                // Verificar se é líder para mostrar botão de editar
                FutureBuilder<bool>(
                  future: ref.read(studyGroupRepositoryProvider).isUserLeader(
                    groupId,
                    currentUser?.id ?? '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data == true) {
                      return IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Editar Grupo',
                        onPressed: () {
                          context.push('/study-groups/$groupId/edit');
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
                  data: (lessons) => _buildLessonsTab(context, ref, group, lessons, currentUser?.id ?? ''),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Erro: $error')),
                ),
                
                // Tab 3: Participantes
                participantsAsync.when(
                  data: (participants) => _buildParticipantsTab(context, participants),
                  loading: () => const Center(child: CircularProgressIndicator()),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],
          
          // Informações
          _buildInfoCard(
            context,
            'Informações do Grupo',
            [
              if (group.meetingDay != null && group.meetingTime != null)
                _buildInfoRow(Icons.schedule, 'Horário', '${group.meetingDay}, ${group.meetingTime}'),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
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
    String userId,
  ) {
    return Column(
      children: [
        // Botão de adicionar lição (apenas para líderes)
        FutureBuilder<bool>(
          future: ref.read(studyGroupRepositoryProvider).isUserLeader(groupId, userId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () {
                    context.push('/study-groups/$groupId/lessons/new');
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
                          context.push('/study-groups/$groupId/lessons/${lesson.id}');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab(BuildContext context, List<StudyParticipant> participants) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(participant.role.icon),
            ),
            title: Text('Participante ${index + 1}'),
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

