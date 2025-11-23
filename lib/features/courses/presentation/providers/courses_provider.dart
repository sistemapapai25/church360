import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/courses_repository.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_lesson.dart';

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
}

