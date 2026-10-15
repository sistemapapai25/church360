import 'package:flutter/material.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/course_lesson.dart';
import '../../domain/models/course_progress.dart';
import '../../domain/models/course_quiz.dart';
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

/// E3: o que está trancado quando o curso é sequencial.
class CourseLocks {
  final Set<String> lessons;
  final Set<String> quizzes;

  const CourseLocks({this.lessons = const {}, this.quizzes = const {}});

  static const none = CourseLocks();
}

/// Painel de estudo do curso gravado (E1 + E2 + E3 + E4 + E5 do roadmap
/// Home/culto/Dashboard): anel de progresso, "Continuar de onde parou", os
/// módulos com as aulas marcadas como concluídas, a prova de cada módulo (e
/// a final), o cadeado do curso sequencial e o certificado. Só desenha: os
/// dados vêm dos providers de `courses_provider.dart`.
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

  /// Provas do curso (E4). Vazio = curso sem prova.
  final List<CourseQuiz> quizzes;

  /// Minha melhor tentativa por prova.
  final Map<String, QuizAttempt> attempts;

  /// E3: a próxima aula só abre com a anterior concluída e a prova do
  /// módulo anterior aprovada.
  final bool sequential;

  /// Meu certificado, se já emitido (E5).
  final CourseCertificate? certificate;

  final void Function(String route) onNavigate;

  /// Toque em "Emitir certificado". Nulo = botão desabilitado.
  final VoidCallback? onIssueCertificate;

  const CourseStudyPanel({
    super.key,
    required this.courseId,
    required this.lessons,
    required this.subjects,
    required this.progress,
    required this.lessonProgress,
    this.quizzes = const [],
    this.attempts = const {},
    this.sequential = false,
    this.certificate,
    required this.onNavigate,
    this.onIssueCertificate,
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

  /// E3: percorre os módulos na ordem da tela com um "portão" que fecha na
  /// primeira aula não concluída ou prova não aprovada. Curso não
  /// sequencial = nada trancado.
  static CourseLocks locksOf({
    required bool sequential,
    required List<CourseModule> modules,
    required List<CourseQuiz> quizzes,
    required Map<String, LessonProgress> lessonProgress,
    required Map<String, QuizAttempt> attempts,
  }) {
    if (!sequential) return CourseLocks.none;
    final lockedLessons = <String>{};
    final lockedQuizzes = <String>{};
    var open = true;
    for (final m in modules) {
      for (final l in m.lessons) {
        if (!open) lockedLessons.add(l.id);
        open = open && (lessonProgress[l.id]?.completed ?? false);
      }
      final quiz = m.subjectId == null
          ? null
          : quizzes.where((q) => q.subjectId == m.subjectId).firstOrNull;
      if (quiz != null) {
        if (!open) lockedQuizzes.add(quiz.id);
        open = open && (attempts[quiz.id]?.passed ?? false);
      }
    }
    for (final q in quizzes.where((q) => q.isFinal)) {
      if (!open) lockedQuizzes.add(q.id);
    }
    return CourseLocks(lessons: lockedLessons, quizzes: lockedQuizzes);
  }

  bool _done(CourseLesson l) => lessonProgress[l.id]?.completed ?? false;

  bool _passed(CourseQuiz q) => attempts[q.id]?.passed ?? false;

  /// Aula do "Continuar": a que a RPC aponta; sem ela, a primeira não
  /// concluída na ordem da tela. Nula = tudo concluído.
  CourseLesson? _resume(List<CourseModule> modules) {
    final ordered = [for (final m in modules) ...m.lessons];
    final id = progress?.resumeLessonId;
    if (id != null) {
      for (final l in ordered) {
        if (l.id == id) return l;
      }
    }
    for (final l in ordered) {
      if (!_done(l)) return l;
    }
    return null;
  }

  String _lessonRoute(CourseLesson l) =>
      '/courses/$courseId/lessons/${l.id}/view';

  String _quizRoute(CourseQuiz q) => '/courses/$courseId/quiz/${q.id}';

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
    final locks = locksOf(
      sequential: sequential,
      modules: modules,
      quizzes: quizzes,
      lessonProgress: lessonProgress,
      attempts: attempts,
    );
    final total = lessons.length;
    final done = lessons.where(_done).length;
    final fraction = done / total;
    final resume = _resume(modules);
    // Aula trancada atrás de uma prova: o botão leva à prova aberta.
    final CourseQuiz? resumeQuiz = resume != null &&
            locks.lessons.contains(resume.id)
        ? quizzes
              .where((q) => !_passed(q) && !locks.quizzes.contains(q.id))
              .firstOrNull
        : null;
    final seconds = lessons.fold<int>(0, (s, l) => s + (l.videoDuration ?? 0));
    final stats = [
      '${modules.length} ${modules.length == 1 ? 'módulo' : 'módulos'}',
      '$total ${total == 1 ? 'aula' : 'aulas'}',
      if (quizzes.isNotEmpty)
        '${quizzes.length} ${quizzes.length == 1 ? 'prova' : 'provas'}',
      if (seconds >= 60) _hours(seconds),
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    final finalQuizzes = quizzes.where((q) => q.isFinal).toList();
    final allPassed = quizzes.every(_passed);

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
                          if (sequential) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Aulas em sequência: a próxima abre quando a anterior é concluída.',
                              style: CommunityDesign.metaStyle(context),
                            ),
                          ],
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
                        : resumeQuiz != null
                        ? () => onNavigate(_quizRoute(resumeQuiz))
                        : locks.lessons.contains(resume.id)
                        ? null
                        : () => onNavigate(_lessonRoute(resume)),
                    icon: Icon(
                      resume == null
                          ? Icons.check_circle_outline
                          : resumeQuiz != null
                          ? Icons.quiz_outlined
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      resume == null
                          ? 'Tudo concluído'
                          : resumeQuiz != null
                          ? 'Fazer a prova: ${resumeQuiz.title}'
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
                  locked: locks.lessons.contains(l.id),
                  onTap: () => onNavigate(_lessonRoute(l)),
                ),
              ),
            for (final q in quizzes.where(
              (q) => q.subjectId != null && q.subjectId == m.subjectId,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuizRow(
                  key: ValueKey('quiz-${q.id}'),
                  quiz: q,
                  attempt: attempts[q.id],
                  locked: locks.quizzes.contains(q.id),
                  onTap: () => onNavigate(_quizRoute(q)),
                ),
              ),
          ],
          if (finalQuizzes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Text(
                'Prova final',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final q in finalQuizzes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuizRow(
                  key: ValueKey('quiz-${q.id}'),
                  quiz: q,
                  attempt: attempts[q.id],
                  locked: locks.quizzes.contains(q.id),
                  onTap: () => onNavigate(_quizRoute(q)),
                ),
              ),
          ],
          const SizedBox(height: 10),
          _CertificateCard(
            key: const ValueKey('course-certificate'),
            certificate: certificate,
            eligible: done == total && allPassed,
            pendingQuizzes: quizzes.where((q) => !_passed(q)).length,
            onIssue: onIssueCertificate,
            onOpen: certificate == null
                ? null
                : () => onNavigate('/certificado/${certificate!.code}'),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final int number;
  final CourseLesson lesson;
  final bool done;
  final bool locked;
  final VoidCallback onTap;

  const _LessonRow({
    super.key,
    required this.number,
    required this.lesson,
    required this.done,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        decoration: CommunityDesign.overlayDecoration(scheme),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  done
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                        )
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
                        if (locked) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Conclua a etapa anterior para abrir',
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ] else if (lesson.videoDuration != null) ...[
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
                    locked
                        ? Icons.lock_outline
                        : done
                        ? Icons.replay_rounded
                        : Icons.play_circle_outline,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  final CourseQuiz quiz;
  final QuizAttempt? attempt;
  final bool locked;
  final VoidCallback onTap;

  const _QuizRow({
    super.key,
    required this.quiz,
    required this.attempt,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = attempt?.passed ?? false;
    final status = locked
        ? 'Conclua as aulas do módulo para fazer a prova'
        : attempt == null
        ? 'Nota mínima ${quiz.passScore}%'
        : passed
        ? 'Aprovado · ${attempt!.score}%'
        : 'Reprovado · ${attempt!.score}% · toque para refazer';
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        decoration: CommunityDesign.overlayDecoration(scheme),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    passed ? Icons.verified_rounded : Icons.quiz_outlined,
                    color: passed ? Colors.green : scheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(status, style: CommunityDesign.metaStyle(context)),
                      ],
                    ),
                  ),
                  Icon(
                    locked ? Icons.lock_outline : Icons.chevron_right,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final CourseCertificate? certificate;
  final bool eligible;
  final int pendingQuizzes;
  final VoidCallback? onIssue;
  final VoidCallback? onOpen;

  const _CertificateCard({
    super.key,
    required this.certificate,
    required this.eligible,
    required this.pendingQuizzes,
    required this.onIssue,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final issued = certificate != null;
    final text = issued
        ? 'Certificado emitido · código ${certificate!.code}'
        : eligible
        ? 'Você concluiu tudo. Emita o seu certificado.'
        : pendingQuizzes > 0
        ? 'Conclua todas as aulas e seja aprovado nas provas para receber o certificado.'
        : 'Conclua todas as aulas para receber o certificado.';
    return GlassCard(
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 36,
            color: issued || eligible ? Colors.amber.shade700 : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificado',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(text, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (issued)
            FilledButton.tonal(onPressed: onOpen, child: const Text('Ver'))
          else if (eligible)
            FilledButton(onPressed: onIssue, child: const Text('Emitir')),
        ],
      ),
    );
  }
}
