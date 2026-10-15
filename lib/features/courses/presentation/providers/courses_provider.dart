import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/courses_repository.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_lesson.dart';
import '../../domain/models/course_progress.dart';
import '../../domain/models/course_purchase.dart';
import '../../domain/models/course_quiz.dart';
import '../../domain/models/course_turma.dart';

/// Provider do repository de cursos
final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository(Supabase.instance.client);
});

/// Provider de todos os cursos
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getAllCourses();
});

/// Provider de cursos ativos
final activeCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getActiveCourses();
});

/// Provider de cursos em breve
final upcomingCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getUpcomingCourses();
});

/// Provider de curso por ID
final courseByIdProvider = FutureProvider.family<Course?, String>((ref, id) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseById(id);
});

/// Provider de cursos por categoria
final coursesByCategoryProvider = FutureProvider.family<List<Course>, String>((ref, category) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCoursesByCategory(category);
});

/// Provider de contagem total de cursos
final totalCoursesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getTotalCoursesCount();
});

/// Provider de contagem de cursos ativos
final activeCoursesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getActiveCoursesCount();
});

/// Provider de inscrições de um curso
final courseEnrollmentsProvider = FutureProvider.family<List<CourseEnrollment>, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseEnrollments(courseId);
});

/// Provider de ações de cursos (criar, atualizar, deletar)
final coursesActionsProvider = Provider<CoursesActions>((ref) {
  return CoursesActions(ref);
});

/// Classe de ações de cursos
class CoursesActions {
  final Ref _ref;

  CoursesActions(this._ref);

  Future<Course> createCourse(Map<String, dynamic> data) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final course = await repo.createCourse(data);

    // Invalidar providers para atualizar a lista
    _ref.invalidate(allCoursesProvider);
    _ref.invalidate(activeCoursesProvider);
    _ref.invalidate(upcomingCoursesProvider);
    _ref.invalidate(totalCoursesCountProvider);
    _ref.invalidate(activeCoursesCountProvider);

    return course;
  }

  Future<Course> updateCourse(String id, Map<String, dynamic> data) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final course = await repo.updateCourse(id, data);

    // Invalidar providers para atualizar
    _ref.invalidate(allCoursesProvider);
    _ref.invalidate(activeCoursesProvider);
    _ref.invalidate(upcomingCoursesProvider);
    _ref.invalidate(courseByIdProvider(id));

    return course;
  }

  Future<void> deleteCourse(String id) async {
    final repo = _ref.read(coursesRepositoryProvider);
    await repo.deleteCourse(id);

    // Invalidar providers para atualizar
    _ref.invalidate(allCoursesProvider);
    _ref.invalidate(activeCoursesProvider);
    _ref.invalidate(upcomingCoursesProvider);
    _ref.invalidate(totalCoursesCountProvider);
    _ref.invalidate(activeCoursesCountProvider);
  }

  Future<CourseEnrollment> enrollMember(String courseId, String memberId) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final enrollment = await repo.enrollMember(courseId, memberId);

    // Invalidar providers para atualizar
    _ref.invalidate(courseByIdProvider(courseId));
    _ref.invalidate(courseEnrollmentsProvider(courseId));

    return enrollment;
  }

  Future<void> unenrollMember(String courseId, String memberId) async {
    final repo = _ref.read(coursesRepositoryProvider);
    await repo.unenrollMember(courseId, memberId);

    // Invalidar providers para atualizar
    _ref.invalidate(courseByIdProvider(courseId));
    _ref.invalidate(courseEnrollmentsProvider(courseId));
  }
}

// ==================== COURSE TURMAS PROVIDERS ====================

/// Provider das turmas (study_groups) de um curso, mais recentes primeiro
final courseStudyGroupsProvider = FutureProvider.family<List<CourseTurma>, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseStudyGroups(courseId);
});

/// Turmas visíveis ao usuário, de todos os cursos (aba Turmas de Formação).
final formacaoTurmasProvider = FutureProvider<List<CourseTurma>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getVisibleTurmas();
});

/// Uma turma (study_group) pelo id; `null` se a RLS a esconde.
final turmaByIdProvider = FutureProvider.family<CourseTurma?, String>((ref, studyGroupId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getTurma(studyGroupId);
});

/// `baptism_turma_id` → id do `study_group` espelho, por ministério.
///
/// Só o sheet de Turmas do Batismo usa: é o que transforma um card de
/// turma na rota da tela da turma.
final ministryTurmaGroupIdsProvider =
    FutureProvider.family<Map<String, String>, String>((ref, ministryId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getMinistryTurmaGroupIds(ministryId);
});

// ==================== COURSE LESSONS PROVIDERS ====================

/// Provider de aulas de um curso
final courseLessonsProvider = FutureProvider.family<List<CourseLesson>, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseLessons(courseId);
});

/// Provider de aula por ID
final courseLessonByIdProvider = FutureProvider.family<CourseLesson?, String>((ref, id) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseLessonById(id);
});

/// Provider de contagem de aulas de um curso
final courseLessonsCountProvider = FutureProvider.family<int, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseLessonsCount(courseId);
});

// ==================== PROGRESSO DO ALUNO (E1) ====================

/// Progresso de quem está logado em todos os cursos gravados que enxerga,
/// por `course_id` (uma chamada só, para o % nos cards da lista).
final myCoursesProgressProvider = FutureProvider<Map<String, CourseProgress>>((
  ref,
) async {
  final rows = await ref.watch(coursesRepositoryProvider).getCourseProgress();
  return {for (final p in rows) p.courseId: p};
});

/// Progresso de quem está logado num curso; `null` = nenhuma aula visível.
final courseProgressProvider = FutureProvider.family<CourseProgress?, String>((
  ref,
  courseId,
) async {
  final rows = await ref
      .watch(coursesRepositoryProvider)
      .getCourseProgress(courseId);
  return rows.isEmpty ? null : rows.first;
});

/// Minhas linhas de progresso das aulas do curso, por `lesson_id`.
final lessonProgressMapProvider =
    FutureProvider.family<Map<String, LessonProgress>, String>((
      ref,
      courseId,
    ) async {
      final lessons = await ref.watch(courseLessonsProvider(courseId).future);
      final rows = await ref
          .watch(coursesRepositoryProvider)
          .getMyLessonProgress([for (final l in lessons) l.id]);
      return {for (final p in rows) p.lessonId: p};
    });

/// Ações do aluno na aula gravada; invalidam os três providers acima.
final lessonProgressActionsProvider = Provider<LessonProgressActions>((ref) {
  return LessonProgressActions(ref);
});

class LessonProgressActions {
  final Ref _ref;

  LessonProgressActions(this._ref);

  void _refresh(String courseId) {
    _ref.invalidate(courseProgressProvider(courseId));
    _ref.invalidate(lessonProgressMapProvider(courseId));
    _ref.invalidate(myCoursesProgressProvider);
  }

  Future<void> completeLesson(String courseId, String lessonId) async {
    await _ref.read(coursesRepositoryProvider).completeLesson(lessonId);
    _refresh(courseId);
  }
}

// ==================== PROVAS E CERTIFICADO (E4 + E5) ====================

/// Provas do curso (módulo e final) que a RLS deixa ver.
final courseQuizzesProvider = FutureProvider.family<List<CourseQuiz>, String>((
  ref,
  courseId,
) {
  return ref.watch(coursesRepositoryProvider).getCourseQuizzes(courseId);
});

/// Questões da prova como o aluno vê (sem gabarito).
final quizQuestionsProvider = FutureProvider.family<List<QuizQuestion>, String>((
  ref,
  quizId,
) {
  return ref.watch(coursesRepositoryProvider).getQuizQuestions(quizId);
});

/// Minha melhor tentativa por prova do curso (aprovada primeiro, depois a
/// maior nota).
final myQuizAttemptsProvider =
    FutureProvider.family<Map<String, QuizAttempt>, String>((
      ref,
      courseId,
    ) async {
      final quizzes = await ref.watch(courseQuizzesProvider(courseId).future);
      final rows = await ref
          .watch(coursesRepositoryProvider)
          .getMyQuizAttempts([for (final q in quizzes) q.id]);
      final best = <String, QuizAttempt>{};
      for (final a in rows) {
        final cur = best[a.quizId];
        if (cur == null ||
            (a.passed && !cur.passed) ||
            (a.passed == cur.passed && a.score > cur.score)) {
          best[a.quizId] = a;
        }
      }
      return best;
    });

/// Questões com gabarito, para o editor (`courses.manage_lessons`).
final quizAdminQuestionsProvider =
    FutureProvider.family<List<QuizQuestion>, String>((ref, quizId) {
      return ref.watch(coursesRepositoryProvider).getQuizAdminQuestions(quizId);
    });

/// Meu certificado do curso, se emitido.
final myCertificateProvider =
    FutureProvider.family<CourseCertificate?, String>((ref, courseId) {
      return ref.watch(coursesRepositoryProvider).getMyCertificate(courseId);
    });

/// Validação pública de um certificado pelo código (anon).
final certificateLookupProvider =
    FutureProvider.family<CertificateInfo?, String>((ref, code) {
      return ref.watch(coursesRepositoryProvider).lookupCertificate(code);
    });

final quizActionsProvider = Provider<QuizActions>((ref) => QuizActions(ref));

class QuizActions {
  final Ref _ref;

  QuizActions(this._ref);

  /// Responde a prova; invalida as tentativas do curso.
  Future<QuizResult> submit(
    String courseId,
    String quizId,
    Map<String, int> answers,
  ) async {
    final result = await _ref
        .read(coursesRepositoryProvider)
        .submitQuiz(quizId, answers);
    _ref.invalidate(myQuizAttemptsProvider(courseId));
    return result;
  }

  Future<String> save({
    String? quizId,
    required String courseId,
    String? subjectId,
    required String title,
    required int passScore,
    required List<QuizQuestion> questions,
  }) async {
    final id = await _ref
        .read(coursesRepositoryProvider)
        .saveQuiz(
          quizId: quizId,
          courseId: courseId,
          subjectId: subjectId,
          title: title,
          passScore: passScore,
          questions: questions,
        );
    _ref.invalidate(courseQuizzesProvider(courseId));
    _ref.invalidate(quizQuestionsProvider(id));
    _ref.invalidate(quizAdminQuestionsProvider(id));
    return id;
  }

  Future<void> delete(String courseId, String quizId) async {
    await _ref.read(coursesRepositoryProvider).deleteQuiz(quizId);
    _ref.invalidate(courseQuizzesProvider(courseId));
    _ref.invalidate(myQuizAttemptsProvider(courseId));
  }

  /// Emite o certificado e devolve o código.
  Future<String> issueCertificate(String courseId) async {
    final code = await _ref
        .read(coursesRepositoryProvider)
        .issueCertificate(courseId);
    _ref.invalidate(myCertificateProvider(courseId));
    return code;
  }
}

/// Provider de ações de aulas
final courseLessonsActionsProvider = Provider<CourseLessonsActions>((ref) {
  return CourseLessonsActions(ref);
});

/// Classe de ações para aulas de curso
class CourseLessonsActions {
  final Ref _ref;

  CourseLessonsActions(this._ref);

  Future<CourseLesson> createLesson(String courseId, Map<String, dynamic> data) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final lesson = await repo.createCourseLesson(data);

    // Invalidar providers
    _ref.invalidate(courseLessonsProvider(courseId));
    _ref.invalidate(courseLessonsCountProvider(courseId));

    return lesson;
  }

  Future<CourseLesson> updateLesson(String courseId, String id, Map<String, dynamic> data) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final lesson = await repo.updateCourseLesson(id, data);

    // Invalidar providers
    _ref.invalidate(courseLessonsProvider(courseId));
    _ref.invalidate(courseLessonByIdProvider(id));

    return lesson;
  }

  Future<void> deleteLesson(String courseId, String id) async {
    final repo = _ref.read(coursesRepositoryProvider);
    await repo.deleteCourseLesson(id);

    // Invalidar providers
    _ref.invalidate(courseLessonsProvider(courseId));
    _ref.invalidate(courseLessonsCountProvider(courseId));
  }

  Future<void> reorderLessons(String courseId, List<String> lessonIds) async {
    final repo = _ref.read(coursesRepositoryProvider);
    await repo.reorderCourseLessons(courseId, lessonIds);

    // Invalidar providers
    _ref.invalidate(courseLessonsProvider(courseId));
  }

  /// E2b: copia as aulas publicadas da turma para o curso. Devolve quantas
  /// aulas novas entraram (0 = já estavam copiadas ou nada publicado).
  Future<int> copyFromTurma(String courseId, String studyGroupId) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final n = await repo.copyLessonsFromTurma(studyGroupId);

    _ref.invalidate(courseLessonsProvider(courseId));
    _ref.invalidate(courseLessonsCountProvider(courseId));
    return n;
  }
}

// ==================== VENDA POR PIX (E6) ====================

/// Minha compra mais recente do curso (nula = nunca comprei).
final myCoursePurchaseProvider =
    FutureProvider.family<CoursePurchase?, String>((ref, courseId) {
      return ref.watch(coursesRepositoryProvider).getMyPurchase(courseId);
    });

/// Fila do revisor: compras do curso, pendentes primeiro.
final coursePurchasesProvider =
    FutureProvider.family<List<CoursePurchase>, String>((ref, courseId) {
      return ref.watch(coursesRepositoryProvider).getCoursePurchases(courseId);
    });

final coursePurchaseActionsProvider = Provider<CoursePurchaseActions>(
  (ref) => CoursePurchaseActions(ref),
);

class CoursePurchaseActions {
  final Ref _ref;

  CoursePurchaseActions(this._ref);

  /// Sobe o comprovante e registra a compra.
  Future<void> buy({
    required String courseId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final repo = _ref.read(coursesRepositoryProvider);
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final path = await repo.uploadReceipt(
      courseId: courseId,
      bytes: bytes,
      extension: ext,
    );
    await repo.createPurchase(
      courseId: courseId,
      receiptPath: path,
      receiptName: fileName,
    );
    _ref.invalidate(myCoursePurchaseProvider(courseId));
  }

  /// Aprova ou recusa; aprovar pode criar a turma padrão do curso.
  Future<void> review(
    String courseId,
    String purchaseId, {
    required bool ok,
    String? notes,
  }) async {
    await _ref
        .read(coursesRepositoryProvider)
        .reviewPurchase(purchaseId, ok: ok, notes: notes);
    _ref.invalidate(coursePurchasesProvider(courseId));
    _ref.invalidate(courseStudyGroupsProvider(courseId));
  }
}
