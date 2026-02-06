import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../providers/study_group_provider.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/community_design.dart';

class StudyGroupsListScreen extends ConsumerWidget {
  const StudyGroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyGroupsAsync = ref.watch(activeStudyGroupsProvider);
    final currentMemberId = ref.watch(currentMemberProvider).value?.id;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        toolbarHeight: 60,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Grupos de Estudo',
          style: CommunityDesign.titleStyle(context),
        ),
        actions: [
          PermissionBuilder(
            permission: 'study_groups.create',
            builder: (context, hasPermission) {
              if (!hasPermission) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Criar Grupo',
                onPressed: () {
                  context.push('/study-groups/new');
                },
              );
            },
            loadingWidget: const SizedBox.shrink(),
          ),
        ],
      ),
      body: studyGroupsAsync.when(
        data: (studyGroups) {
          final cs = Theme.of(context).colorScheme;

          if (studyGroups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: CommunityDesign.overlayDecoration(cs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 56,
                        color: cs.primary.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum grupo de estudo encontrado',
                        style: CommunityDesign.titleStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie um novo grupo para começar!',
                        style: CommunityDesign.contentStyle(
                          context,
                        ).copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: CommunityDesign.overlayDecoration(cs),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CommunityDesign.radius),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.push('/study-groups/${group.id}');
                        },
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
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: group.status.color.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.menu_book,
                                      size: 20,
                                      color: group.status.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Nome e tópico
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: CommunityDesign.titleStyle(
                                            context,
                                          ).copyWith(fontSize: 16),
                                        ),
                                        if (group.studyTopic != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            group.studyTopic!,
                                            style:
                                                CommunityDesign.metaStyle(
                                                  context,
                                                ).copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status
                                  CommunityDesign.badge(
                                    context,
                                    group.status.displayName,
                                    group.status.color,
                                  ),
                                ],
                              ),

                              // Descrição
                              if (group.description != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  group.description!,
                                  style: CommunityDesign.contentStyle(context),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Informações
                              Row(
                                children: [
                                  // Horário
                                  if (group.meetingDay != null &&
                                      group.meetingTime != null) ...[
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.meetingDay}, ${group.meetingTime}',
                                      style: CommunityDesign.metaStyle(context),
                                    ),
                                    const SizedBox(width: 16),
                                  ],

                                  // Local
                                  if (group.meetingLocation != null) ...[
                                    Icon(
                                      Icons.place,
                                      size: 14,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        group.meetingLocation!,
                                        style: CommunityDesign.metaStyle(
                                          context,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              // Público/Privado
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    group.isPublic ? Icons.public : Icons.lock,
                                    size: 14,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    group.isPublic ? 'Público' : 'Privado',
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                                  const Spacer(),
                                  // Botão de participar
                                  FutureBuilder(
                                    future: ref
                                        .read(studyGroupRepositoryProvider)
                                        .getUserParticipation(
                                          group.id,
                                          currentMemberId ?? '',
                                        ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data != null) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Membro',
                                                style:
                                                    CommunityDesign.metaStyle(
                                                      context,
                                                    ).copyWith(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return TextButton.icon(
                                        onPressed: () async {
                                          final actions = ref.read(
                                            studyGroupActionsProvider,
                                          );
                                          await actions.joinGroup(
                                            group.id,
                                            currentMemberId ?? '',
                                          );
                                          ref.invalidate(
                                            activeStudyGroupsProvider,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.person_add,
                                          size: 16,
                                        ),
                                        label: const Text('Participar'),
                                        style: CommunityDesign.pillButtonStyle(
                                          context,
                                          cs.primary,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
