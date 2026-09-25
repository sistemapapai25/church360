import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/study_group_provider.dart';
import '../../domain/models/study_group.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';

AppStatusTone _studyGroupStatusTone(StudyGroupStatus status) {
  return switch (status) {
    StudyGroupStatus.active => AppStatusTone.active,
    StudyGroupStatus.completed => AppStatusTone.done,
    StudyGroupStatus.paused ||
    StudyGroupStatus.cancelled => AppStatusTone.dropped,
  };
}

class StudyGroupsListScreen extends ConsumerWidget {
  final bool fromDashboard;

  const StudyGroupsListScreen({super.key, this.fromDashboard = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyGroupsAsync = ref.watch(activeStudyGroupsProvider);
    final currentMember = ref.watch(currentMemberProvider).valueOrNull;
    final currentMemberId = currentMember?.id;

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
              if (!hasPermission) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(AppIcons.add),
                tooltip: 'Criar Grupo',
                onPressed: () {
                  final route = fromDashboard
                      ? '/study-groups/new?from=dashboard'
                      : '/study-groups/new';
                  context.push(route);
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
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.study,
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    onTap: () {
                      final route = fromDashboard
                          ? '/study-groups/${group.id}?from=dashboard'
                          : '/study-groups/${group.id}';
                      context.push(route);
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
                                  AppIcons.study,
                                  size: 20,
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
                              PermissionBuilder(
                                permission: 'study_groups.edit',
                                loadingWidget: const SizedBox.shrink(),
                                builder: (context, hasPermission) {
                                  if (!hasPermission) {
                                    return const SizedBox.shrink();
                                  }
                                  return IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Editar grupo',
                                    onPressed: () {
                                      final route = fromDashboard
                                          ? '/study-groups/${group.id}/edit?from=dashboard'
                                          : '/study-groups/${group.id}/edit';
                                      context.push(route);
                                    },
                                    icon: const Icon(AppIcons.edit, size: 18),
                                  );
                                },
                              ),
                              StatusBadge(
                                label: group.status.displayName,
                                tone: _studyGroupStatusTone(group.status),
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
                                  AppIcons.schedule,
                                  size: 14,
                                  color: cs.onSurface.withValues(alpha: 0.5),
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
                                  AppIcons.location,
                                  size: 14,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    group.meetingLocation!,
                                    style: CommunityDesign.metaStyle(context),
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
                                group.isPublic
                                    ? AppIcons.public
                                    : AppIcons.lock,
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
                                    return StatusBadge.active(
                                      label: 'Membro',
                                      icon: AppIcons.checkCircle,
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
                                      ref.invalidate(activeStudyGroupsProvider);
                                    },
                                    icon: const Icon(
                                      AppIcons.personAdd,
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
              const Icon(AppIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                AppErrorHandler.userMessage(
                  error,
                  feature: 'study_groups.list',
                ),
              ),
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
