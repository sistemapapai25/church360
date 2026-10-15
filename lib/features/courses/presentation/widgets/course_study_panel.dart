import 'package:flutter/material.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/course_lesson.dart';
import '../../domain/models/course_progress.dart';
import '../../domain/models/course_subject.dart';

/// Um módulo na tela do aluno: a matéria (D12) com as aulas dela.
class CourseModule {
  final String? subjectId;
  final String title;
  final List<CourseLesson> lessons;

  const CourseModule({
    this.subjectId,
    required this.title,
    required this.lessons,
  });
}

/// Painel de estudo do curso gravado (E1 + E2 do roadmap Home/culto/
/// Dashboard): anel de progresso, "Continuar de onde parou" e os módulos
/// com as aulas marcadas como concluídas. Só desenha: os dados vêm de
/// `courseLessonsProvider`, `courseSubjectsProvider`, `courseProgressProvider`
/// e `lessonProgressMapProvider`.
class CourseStudyPanel extends StatelessWidget {
  final String courseId;

  /// Aulas na ordem do curso (`order_index`).
  final List<CourseLesson> lessons;

  /// Matérias na ordem de criação. Vazio = módulo único.
  final List<CourseSubject> subjects;

  /// Resumo da RPC `course_progress`; nulo enquanto carrega.
  final CourseProgress? progress;

  /// Minhas linhas de `course_lesson_progress`, por aula.
  final Map<String, LessonProgress> lessonProgress;

  final void Function(String route) onNavigate;

  const CourseStudyPanel({
    super.key,
    required this.courseId,
    required this.lessons,
    required this.subjects,
    required this.progress,
    required this.lessonProgress,
    required this.onNavigate,
  });

  /// Agrupa as aulas por matéria. Sem matéria no curso = um módulo só;
  /// aula sem matéria num curso com matérias vai para "Outras aulas".
  static List<CourseModule> modulesOf(
    List<CourseLesson> lessons,
    List<CourseSubject> subjects,
  ) {
    if (subjects.isEmpty) {
      return [CourseModule(title: 'Aulas', lessons: lessons)];
    }
    final ids = {for (final s in subjects) s.id};
    final modules = [
      for (final s in subjects)
        CourseModule(
          subjectId: s.id,
          title: s.title,
          lessons: [
            for (final l in lessons)
              if (l.subjectId == s.id) l,
          ],
        ),
      CourseModule(
        title: 'Outras aulas',
        lessons: [
          for (final l in lessons)
            if (!ids.contains(l.subjectId)) l,
        ],
      ),
    ];
    return [
      for (final m in modules)
        if (m.lessons.isNotEmpty) m,
    ];
  }

  bool _done(CourseLesson l) => lessonProgress[l.id]?.completed ?? false;

  /// Aula do "Continuar": a que a RPC aponta; sem ela, a primeira não
  /// concluída na ordem. Nula = tudo concluído.
  CourseLesson? get _resume {
    final id = progress?.resumeLessonId;
    if (id != null) {
      for (final l in lessons) {
        if (l.id == id) return l;
      }
    }
    for (final l in lessons) {
      if (!_done(l)) return l;
    }
    return null;
  }

  String _route(CourseLesson l) => '/courses/$courseId/lessons/${l.id}/view';

  static String _hours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}min';
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) return const SizedBox.shrink();
    final modules = modulesOf(lessons, subjects);
    final total = lessons.length;
    final done = lessons.where(_done).length;
    final fraction = done / total;
    final resume = _resume;
    final seconds = lessons.fold<int>(0, (s, l) => s + (l.videoDuration ?? 0));
    final stats = [
      '${modules.length} ${modules.length == 1 ? 'módulo' : 'módulos'}',
      '$total ${total == 1 ? 'aula' : 'aulas'}',
      if (seconds >= 60) _hours(seconds),
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: fraction,
                            strokeWidth: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: done == total
                                ? Colors.green
                                : scheme.primary,
                          ),
                          Center(
                            child: Text(
                              '${(fraction * 100).round()}%',
                              style: CommunityDesign.titleStyle(context)
                                  .copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            done == total ? 'Curso concluído' : 'Seu progresso',
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$done de $total ${total == 1 ? 'aula concluída' : 'aulas concluídas'}',
                            style: CommunityDesign.contentStyle(
                              context,
                            ).copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(stats, style: CommunityDesign.metaStyle(context)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    key: const ValueKey('course-resume'),
                    onPressed: resume == null
                        ? null
                        : () => onNavigate(_route(resume)),
                    icon: Icon(
                      resume == null
                          ? Icons.check_circle_outline
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      resume == null
                          ? 'Tudo concluído'
                          : done > 0 || (progress?.started ?? false)
                          ? 'Continuar de onde parou'
                          : 'Começar',
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final (i, m) in modules.indexed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subjects.isEmpty
                          ? m.title
                          : m.subjectId == null
                          ? m.title
                          : 'Módulo ${i + 1} · ${m.title}',
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${m.lessons.where(_done).length}/${m.lessons.length}',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            if (subjects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.lessons.where(_done).length / m.lessons.length,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (final l in m.lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonRow(
                  key: ValueKey('lesson-${l.id}'),
                  number: lessons.indexOf(l) + 1,
                  lesson: l,
                  done: _done(l),
                  onTap: () => onNavigate(_route(l)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final int number;
  final CourseLesson lesson;
  final bool done;
  final VoidCallback onTap;

  const _LessonRow({
    super.key,
    required this.number,
    required this.lesson,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(scheme),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                done
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                    : Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 2),
                        ),
                        child: Text(
                          '$number',
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lesson.videoDuration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          lesson.durationText,
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  done ? Icons.replay_rounded : Icons.play_circle_outline,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
