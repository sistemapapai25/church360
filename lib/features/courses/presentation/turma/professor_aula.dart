import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/domain/models/teaching_lesson.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import 'adapters/turma_surfaces.dart';
import 'tabs/turma_aulas_tab.dart';
import 'turma_access.dart';
import 'turma_aula_screen.dart';
import 'turma_detail_screen.dart';
import 'widgets/turma_sheet.dart';

// PR 2c — o professor da aula (study_lessons.teacher_id) vê as aulas dele
// na Agenda, abre a aula e faz a chamada. Tudo pelas RPCs presas à aula
// (20261003000300): ele não lê a turma.

/// Rota da aula pela porta do professor.
String professorLessonRoute(String lessonId) => '/aulas/$lessonId/professor';

/// Minhas aulas que ainda vão acontecer (Agenda → Próximos Eventos).
final myUpcomingTeachingLessonsProvider = FutureProvider<List<TeachingLesson>>((
  ref,
) async {
  final now = DateTime.now();
  final lessons = await ref
      .watch(studyGroupRepositoryProvider)
      .getMyTeachingLessons(now);
  return [
    for (final l in lessons)
      if (l.isUpcoming(now)) l,
  ];
});

/// Minhas aulas no mês de [month] (Agenda → Calendário).
final myTeachingLessonsOfMonthProvider =
    FutureProvider.family<List<TeachingLesson>, DateTime>((ref, month) {
      return ref
          .watch(studyGroupRepositoryProvider)
          .getMyTeachingLessons(
            DateTime(month.year, month.month),
            DateTime(month.year, month.month + 1, 0),
          );
    });

final teacherLessonRollProvider =
    FutureProvider.family<List<TeacherRollEntry>, String>((ref, lessonId) {
      return ref
          .watch(studyGroupRepositoryProvider)
          .getTeacherLessonRoll(lessonId);
    });

/// A aula na Agenda: "Aula · Doutrina — 1/4", a turma e quando.
class TeachingLessonCard extends StatelessWidget {
  final TeachingLesson lesson;

  const TeachingLessonCard({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = CommunityDesign.metaStyle(context);
    final when = [
      DateFormat('dd/MM').format(lesson.scheduledDate),
      ?lesson.timeRange,
    ].join(' · ');

    return GlassCard(
      key: ValueKey('aula-agenda-${lesson.id}'),
      padding: const EdgeInsets.all(20),
      onTap: () => context.push(professorLessonRoute(lesson.id)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.course, color: cs.tertiary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aula · ${lesson.title}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(lesson.turmaName, style: meta),
                Text(when, style: meta),
              ],
            ),
          ),
          const SizedBox(width: 8),
          lesson.status == LessonStatus.published
              ? CommunityDesign.badge(context, 'Aula', cs.tertiary)
              : StatusBadge(
                  label: lesson.status.displayName,
                  tone: lessonStatusTone(lesson.status),
                ),
        ],
      ),
    );
  }
}

/// A aula pela porta do professor. Só abre para quem é o `teacher_id`
/// dela agora: trocou o professor, a porta muda de dono.
class ProfessorAulaScreen extends ConsumerWidget {
  final String lessonId;

  const ProfessorAulaScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));
    final meAsync = ref.watch(currentMemberIdProvider);
    const title = 'Aula';

    if (lessonAsync.isLoading || meAsync.isLoading) {
      return const TurmaMessageScaffold(
        title: title,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (lessonAsync.hasError || meAsync.hasError) {
      return TurmaMessageScaffold(
        title: title,
        child: TurmaMessage.error(
          message: 'Não foi possível abrir a aula.',
          onRetry: () {
            ref.invalidate(lessonByIdProvider(lessonId));
            ref.invalidate(currentMemberIdProvider);
          },
        ),
      );
    }

    final lesson = lessonAsync.value;
    final me = meAsync.value;
    if (lesson == null || me == null || lesson.teacherId != me) {
      return const TurmaMessageScaffold(
        title: title,
        child: TurmaMessage(
          icon: AppIcons.lock,
          message: 'Você não é o professor desta aula.',
        ),
      );
    }

    return TurmaAulaView(
      lesson: lesson,
      access: TurmaAccess.teacher,
      surfaces: const _ProfessorSurfaces(),
    );
  }
}

/// Na porta do professor só existe a aula: a única superfície que varia é
/// a chamada, que é a mesma para Batismo e turma genérica (a RPC resolve a
/// origem).
class _ProfessorSurfaces implements TurmaSurfaces {
  const _ProfessorSurfaces();

  @override
  Widget lessonPresence(StudyLesson lesson) =>
      TeacherLessonRoll(lessonId: lesson.id);

  @override
  Widget alunos() => const SizedBox.shrink();

  @override
  Widget minhaFrequencia() => const SizedBox.shrink();

  @override
  TurmaManageTarget? get manage => null;
}

/// A chamada do professor. Cada toque grava na hora; não há desmarcar,
/// só trocar entre os três estados.
class TeacherLessonRoll extends ConsumerStatefulWidget {
  final String lessonId;

  const TeacherLessonRoll({super.key, required this.lessonId});

  @override
  ConsumerState<TeacherLessonRoll> createState() => _TeacherLessonRollState();
}

class _TeacherLessonRollState extends ConsumerState<TeacherLessonRoll> {
  /// Alunos com marcação em voo, para travar só quem foi tocado.
  final _busy = <String>{};

  Future<void> _mark(List<String> studentIds, AttendanceStatus status) async {
    setState(() => _busy.addAll(studentIds));
    final repo = ref.read(studyGroupRepositoryProvider);
    try {
      for (final id in studentIds) {
        await repo.teacherSetAttendance(widget.lessonId, id, status);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      // Realtime não é ligado por migration neste banco: recarrega na mão.
      ref.invalidate(teacherLessonRollProvider(widget.lessonId));
      if (mounted) setState(() => _busy.removeAll(studentIds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);

    return ref
        .watch(teacherLessonRollProvider(widget.lessonId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TurmaMessage.error(
            message: 'Não foi possível carregar a chamada.',
            onRetry: () =>
                ref.invalidate(teacherLessonRollProvider(widget.lessonId)),
          ),
          data: (roll) {
            if (roll.isEmpty) {
              return const TurmaMessage(
                icon: AppIcons.info,
                message: 'Nenhum aluno nesta turma.',
              );
            }
            final pending = [
              for (final s in roll)
                if (s.status == null) s.studentId,
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final s in roll)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final status in AttendanceStatus.values)
                              ChoiceChip(
                                key: ValueKey(
                                  'prof-roll-${s.studentId}-${status.value}',
                                ),
                                label: Text(status.displayName),
                                selected: s.status == status,
                                onSelected:
                                    _busy.contains(s.studentId) ||
                                        s.status == status
                                    ? null
                                    : (_) => _mark([s.studentId], status),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _busy.isNotEmpty
                          ? null
                          : () => _mark(pending, AttendanceStatus.present),
                      child: Text(
                        'Marcar os ${pending.length} restantes como presentes',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Não marcado não é falta.', style: meta),
              ],
            );
          },
        );
  }
}
