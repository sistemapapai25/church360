import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/study_group_provider.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';

class StudyGroupsListScreen extends ConsumerWidget {
  const StudyGroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyGroupsAsync = ref.watch(activeStudyGroupsProvider);
    final userAccessLevelAsync = ref.watch(currentUserAccessLevelProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos de Estudo'),
        actions: [
          // Apenas Coordenadores+ podem criar grupos
          userAccessLevelAsync.when(
            data: (accessLevel) {
              if (accessLevel != null && accessLevel.accessLevelNumber >= 4) {
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Criar Grupo',
                  onPressed: () {
                    context.push('/study-groups/new');
                  },
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: studyGroupsAsync.when(
        data: (studyGroups) {
          if (studyGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum grupo de estudo encontrado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie um novo grupo para começar!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeStudyGroupsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: studyGroups.length,
              itemBuilder: (context, index) {
                final group = studyGroups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      context.push('/study-groups/${group.id}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabeçalho
                          Row(
                            children: [
                              // Ícone
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: group.status.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.menu_book,
                                  color: group.status.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Nome e tópico
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (group.studyTopic != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        group.studyTopic!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Status
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: group.status.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  group.status.displayName,
                                  style: TextStyle(
                                    color: group.status.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Descrição
                          if (group.description != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              group.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // Informações
                          Row(
                            children: [
                              // Horário
                              if (group.meetingDay != null && group.meetingTime != null) ...[
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${group.meetingDay}, ${group.meetingTime}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 16),
                              ],
                              
                              // Local
                              if (group.meetingLocation != null) ...[
                                Icon(
                                  Icons.place,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    group.meetingLocation!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          // Público/Privado
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                group.isPublic ? Icons.public : Icons.lock,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.isPublic ? 'Grupo Público' : 'Grupo Privado',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              // Botão de participar
                              FutureBuilder(
                                future: ref.read(studyGroupRepositoryProvider).getUserParticipation(
                                  group.id,
                                  currentUser?.id ?? '',
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Chip(
                                      label: const Text('Participando'),
                                      avatar: const Icon(Icons.check_circle, size: 16),
                                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                                      labelStyle: const TextStyle(color: Colors.green),
                                    );
                                  }
                                  return FilledButton.tonalIcon(
                                    onPressed: () async {
                                      final actions = ref.read(studyGroupActionsProvider);
                                      await actions.joinGroup(group.id, currentUser?.id ?? '');
                                      ref.invalidate(activeStudyGroupsProvider);
                                    },
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Participar'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar grupos: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(activeStudyGroupsProvider),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

