import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/course.dart';
import '../domain/models/course_lesson.dart';

/// Repository para gerenciar cursos
class CoursesRepository {
  final SupabaseClient _supabase;

  CoursesRepository(this._supabase);

  /// Buscar todos os cursos
  Future<List<Course>> getAllCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select('''
            *,
            course_enrollment(count)
          ''')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        // Extrair contagem de inscrições
        if (data['course_enrollment'] != null) {
          final enrollments = data['course_enrollment'];
          if (enrollments is List && enrollments.isNotEmpty) {
            data['enrolled_count'] = enrollments[0]['count'];
          } else {
            data['enrolled_count'] = 0;
          }
        }
        
        return Course.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos ativos
  Future<List<Course>> getActiveCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select('''
            *,
            course_enrollment(count)
          ''')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['course_enrollment'] != null) {
          final enrollments = data['course_enrollment'];
          if (enrollments is List && enrollments.isNotEmpty) {
            data['enrolled_count'] = enrollments[0]['count'];
          } else {
            data['enrolled_count'] = 0;
          }
        }
        
        return Course.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos em breve
  Future<List<Course>> getUpcomingCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select('''
            *,
            course_enrollment(count)
          ''')
          .eq('status', 'upcoming')
          .order('start_date', ascending: true);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['course_enrollment'] != null) {
          final enrollments = data['course_enrollment'];
          if (enrollments is List && enrollments.isNotEmpty) {
            data['enrolled_count'] = enrollments[0]['count'];
          } else {
            data['enrolled_count'] = 0;
          }
        }
        
        return Course.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos por categoria
  Future<List<Course>> getCoursesByCategory(String category) async {
    try {
      final response = await _supabase
          .from('course')
          .select('''
            *,
            course_enrollment(count)
          ''')
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['course_enrollment'] != null) {
          final enrollments = data['course_enrollment'];
          if (enrollments is List && enrollments.isNotEmpty) {
            data['enrolled_count'] = enrollments[0]['count'];
          } else {
            data['enrolled_count'] = 0;
          }
        }
        
        return Course.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar curso por ID
  Future<Course?> getCourseById(String id) async {
    try {
      final response = await _supabase
          .from('course')
          .select('''
            *,
            course_enrollment(count)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);
      
      if (data['course_enrollment'] != null) {
        final enrollments = data['course_enrollment'];
        if (enrollments is List && enrollments.isNotEmpty) {
          data['enrolled_count'] = enrollments[0]['count'];
        } else {
          data['enrolled_count'] = 0;
        }
      }

      return Course.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar curso
  Future<Course> createCourse(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('course')
          .insert(data)
          .select()
          .single();

      return Course.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar curso
  Future<Course> updateCourse(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('course')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return Course.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar curso
  Future<void> deleteCourse(String id) async {
    try {
      await _supabase
          .from('course')
          .delete()
          .eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar inscrições de um curso
  Future<List<CourseEnrollment>> getCourseEnrollments(String courseId) async {
    try {
      final response = await _supabase
          .from('course_enrollment')
          .select('''
            *,
            user_account:member_id (
              first_name,
              last_name
            )
          ''')
          .eq('course_id', courseId)
          .order('enrolled_at', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);

        // Extrair nome do membro
        if (data['user_account'] != null && data['user_account'] is Map) {
          final member = data['user_account'];
          data['member_name'] = '${member['first_name']} ${member['last_name']}';
        }

        return CourseEnrollment.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Inscrever membro em curso
  Future<CourseEnrollment> enrollMember(String courseId, String memberId) async {
    try {
      final response = await _supabase
          .from('course_enrollment')
          .insert({
            'course_id': courseId,
            'member_id': memberId,
            'enrolled_at': DateTime.now().toIso8601String(),
            'status': 'active',
          })
          .select()
          .single();

      return CourseEnrollment.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancelar inscrição
  Future<void> unenrollMember(String courseId, String memberId) async {
    try {
      await _supabase
          .from('course_enrollment')
          .delete()
          .eq('course_id', courseId)
          .eq('member_id', memberId);
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de cursos
  Future<int> getTotalCoursesCount() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar cursos ativos
  Future<int> getActiveCoursesCount() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('status', 'active')
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== COURSE LESSONS ====================

  /// Buscar todas as aulas de um curso
  Future<List<CourseLesson>> getCourseLessons(String courseId) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => CourseLesson.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar aula por ID
  Future<CourseLesson?> getCourseLessonById(String id) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return CourseLesson.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar aula
  Future<CourseLesson> createCourseLesson(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .insert(data)
          .select()
          .single();

      return CourseLesson.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar aula
  Future<CourseLesson> updateCourseLesson(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return CourseLesson.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar aula
  Future<void> deleteCourseLesson(String id) async {
    try {
      await _supabase
          .from('course_lesson')
          .delete()
          .eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Reordenar aulas
  Future<void> reorderCourseLessons(String courseId, List<String> lessonIds) async {
    try {
      for (int i = 0; i < lessonIds.length; i++) {
        await _supabase
            .from('course_lesson')
            .update({'order_index': i})
            .eq('id', lessonIds[i])
            .eq('course_id', courseId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Contar aulas de um curso
  Future<int> getCourseLessonsCount(String courseId) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .select()
          .eq('course_id', courseId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }
}

