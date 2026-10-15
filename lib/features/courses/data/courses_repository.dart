import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/course.dart';
import '../domain/models/course_lesson.dart';
import '../domain/models/course_progress.dart';
import '../domain/models/course_quiz.dart';
import '../domain/models/course_subject.dart';
import '../domain/models/course_turma.dart';

/// Repository para gerenciar cursos
class CoursesRepository {
  final SupabaseClient _supabase;

  CoursesRepository(this._supabase);

  /// Cursos com `enrolled_count` = alunos ativos das turmas do curso
  /// (`course_student_counts`; a `course_enrollment` antiga está trancada
  /// desde 25/09 e devolvia sempre 0).
  Future<List<Course>> _withStudentCounts(List<dynamic> rows) async {
    final counts = <String, int>{
      for (final r in await _supabase.rpc('course_student_counts') as List)
        r['course_id'] as String: r['students'] as int,
    };
    return [
      for (final json in rows)
        Course.fromJson({
          ...Map<String, dynamic>.from(json as Map),
          'enrolled_count': counts[json['id']] ?? 0,
        }),
    ];
  }

  /// Buscar todos os cursos
  Future<List<Course>> getAllCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false);

      return _withStudentCounts(response as List);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos ativos
  Future<List<Course>> getActiveCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return _withStudentCounts(response as List);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos em breve
  Future<List<Course>> getUpcomingCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('status', 'upcoming')
          .order('start_date', ascending: true);

      return _withStudentCounts(response as List);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar cursos por categoria
  Future<List<Course>> getCoursesByCategory(String category) async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('category', category)
          .order('created_at', ascending: false);

      return _withStudentCounts(response as List);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar curso por ID
  Future<Course?> getCourseById(String id) async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;

      return (await _withStudentCounts([response])).single;
    } catch (e) {
      rethrow;
    }
  }

  /// Criar curso
  Future<Course> createCourse(Map<String, dynamic> data) async {
    try {
      data['tenant_id'] = SupabaseConstants.currentTenantId;
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
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
            user_account:user_id (
              first_name,
              last_name
            )
          ''')
          .eq('course_id', courseId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
            'user_id': memberId,
            'enrolled_at': DateTime.now().toIso8601String(),
            'status': 'active',
            'tenant_id': SupabaseConstants.currentTenantId,
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
          .eq('user_id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('status', 'active')
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== COURSE TURMAS ====================

  /// Buscar as turmas (study_groups) que pertencem a um curso.
  ///
  /// Só as colunas do card; participantes não entram. Quem não enxerga
  /// o grupo pela RLS de study_groups recebe lista vazia, não erro.
  Future<List<CourseTurma>> getCourseStudyGroups(String courseId) async {
    try {
      final response = await _supabase
          .from('study_groups')
          .select(
            _turmaColumns,
          )
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('course_id', courseId)
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => CourseTurma.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Todas as turmas que a RLS deixa o usuário ver (aba Turmas de
  /// Formação). Só as colunas do card: nada de participante, telefone ou
  /// e-mail (Frente 5 do plano de turmas).
  Future<List<CourseTurma>> getVisibleTurmas() async {
    final response = await _supabase
        .from('study_groups')
        .select(_turmaColumns)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('start_date', ascending: false);

    return (response as List)
        .map((json) => CourseTurma.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Uma turma, para a tela da turma.
  ///
  /// `null` quando a RLS de study_groups esconde o grupo — para a tela, não
  /// existir e não poder ver são a mesma resposta.
  Future<CourseTurma?> getTurma(String studyGroupId) async {
    final response = await _supabase
        .from('study_groups')
        .select(_turmaColumns)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', studyGroupId)
        .maybeSingle();

    if (response == null) return null;
    return CourseTurma.fromJson(Map<String, dynamic>.from(response));
  }

  /// As turmas (`study_groups`) espelho de um ministério, indexadas pelo
  /// `baptism_turma_id`.
  ///
  /// É como o sheet de Turmas do Batismo encontra a tela da turma: a
  /// `baptism_turma` não guarda o id do grupo — o grupo é que aponta para
  /// ela. Turma sem espelho, ou com o espelho escondido pela RLS, fica
  /// fora do mapa, e o card dela não abre.
  Future<Map<String, String>> getMinistryTurmaGroupIds(
    String ministryId,
  ) async {
    final response = await _supabase
        .from('study_groups')
        .select('id, baptism_turma_id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId)
        .not('baptism_turma_id', 'is', null);

    return {
      for (final row in response as List)
        if ((row as Map)['baptism_turma_id'] != null)
          row['baptism_turma_id'] as String: row['id'] as String,
    };
  }

  static const _turmaColumns =
      'id, name, status, start_date, end_date, ministry_id, baptism_turma_id, course_id, is_public';

  // ==================== COURSE LESSONS ====================

  /// Buscar todas as aulas de um curso
  Future<List<CourseLesson>> getCourseLessons(String courseId) async {
    try {
      final response = await _supabase
          .from('course_lesson')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
          .insert({
            ...data,
            'tenant_id': SupabaseConstants.currentTenantId,
          })
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
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
            .eq('course_id', courseId)
            .eq('tenant_id', SupabaseConstants.currentTenantId);
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
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('course_id', courseId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== PROGRESSO DO ALUNO (E1) ====================

  /// Progresso de quem está logado, por curso gravado que a RLS deixa ver
  /// (RPC `course_progress`). [courseId] nulo = todos os cursos.
  Future<List<CourseProgress>> getCourseProgress([String? courseId]) async {
    final result = await _supabase.rpc(
      'course_progress',
      params: {'p_course_id': courseId},
    );
    return (result as List)
        .map((json) => CourseProgress.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Minhas linhas de progresso das aulas de um curso (RLS own).
  Future<List<LessonProgress>> getMyLessonProgress(
    List<String> lessonIds,
  ) async {
    if (lessonIds.isEmpty) return const [];
    final response = await _supabase
        .from('course_lesson_progress')
        .select('lesson_id, completed_at, video_position_s')
        .inFilter('lesson_id', lessonIds);
    return (response as List)
        .map((json) => LessonProgress.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Marca a aula como concluída para quem está logado (RPC, idempotente).
  ///
  /// A RPC irmã `lesson_position` (segundos do vídeo) existe no banco, mas
  /// o app ainda não a chama: no navegador o YouTube é um iframe sem API de
  /// posição (`InlineVideo`). "Continuar de onde parou" é por aula.
  Future<void> completeLesson(String lessonId) =>
      _supabase.rpc('lesson_complete', params: {'p_lesson_id': lessonId});

  // ==================== PROVAS (E4) ====================

  /// Provas do curso que a RLS deixa ver (módulo e final).
  Future<List<CourseQuiz>> getCourseQuizzes(String courseId) async {
    final response = await _supabase
        .from('course_quiz')
        .select('id, course_id, subject_id, title, pass_score')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('course_id', courseId)
        .order('created_at');
    return (response as List)
        .map((json) => CourseQuiz.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Questões como o aluno vê: sem `correct_index` (o grant é por coluna;
  /// pedir a coluna dá 42501).
  Future<List<QuizQuestion>> getQuizQuestions(String quizId) async {
    final response = await _supabase
        .from('course_quiz_question')
        .select('id, order_index, text, options, explanation')
        .eq('quiz_id', quizId)
        .order('order_index');
    return (response as List)
        .map((json) => QuizQuestion.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Minhas tentativas nas provas do curso (RLS own), mais recentes primeiro.
  Future<List<QuizAttempt>> getMyQuizAttempts(List<String> quizIds) async {
    if (quizIds.isEmpty) return const [];
    final response = await _supabase
        .from('course_quiz_attempt')
        .select('id, quiz_id, score, passed, created_at')
        .inFilter('quiz_id', quizIds)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => QuizAttempt.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Envia as respostas (`{question_id: índice}`); a nota vem do servidor.
  Future<QuizResult> submitQuiz(String quizId, Map<String, int> answers) async {
    final result = await _supabase.rpc(
      'quiz_submit',
      params: {'p_quiz_id': quizId, 'p_answers': answers},
    );
    return QuizResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Questões com gabarito, só para `courses.manage_lessons`.
  Future<List<QuizQuestion>> getQuizAdminQuestions(String quizId) async {
    final result = await _supabase.rpc(
      'quiz_admin_questions',
      params: {'p_quiz_id': quizId},
    );
    return (result as List)
        .map((json) => QuizQuestion.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Cria ([quizId] nulo) ou regrava a prova inteira. Devolve o id.
  Future<String> saveQuiz({
    String? quizId,
    required String courseId,
    String? subjectId,
    required String title,
    required int passScore,
    required List<QuizQuestion> questions,
  }) async {
    final result = await _supabase.rpc(
      'quiz_save',
      params: {
        'p_course_id': courseId,
        'p_subject_id': subjectId,
        'p_title': title,
        'p_pass_score': passScore,
        'p_questions': [for (final q in questions) q.toSaveJson()],
        'p_quiz_id': quizId,
      },
    );
    return result as String;
  }

  Future<void> deleteQuiz(String quizId) =>
      _supabase.rpc('quiz_delete', params: {'p_quiz_id': quizId});

  // ==================== CERTIFICADO (E5) ====================

  /// Meu certificado do curso, se já emitido (RLS own).
  Future<CourseCertificate?> getMyCertificate(String courseId) async {
    final response = await _supabase
        .from('course_certificate')
        .select('code, course_id, issued_at')
        .eq('course_id', courseId)
        .maybeSingle();
    if (response == null) return null;
    return CourseCertificate.fromJson(Map<String, dynamic>.from(response));
  }

  /// Emite (ou devolve) o certificado. `CURSO_INCOMPLETO` quando falta aula
  /// ou prova.
  Future<String> issueCertificate(String courseId) async {
    final result = await _supabase.rpc(
      'certificate_issue',
      params: {'p_course_id': courseId},
    );
    return result as String;
  }

  /// Validação pública pelo código (anon). Nulo = código desconhecido.
  Future<CertificateInfo?> lookupCertificate(String code) async {
    final result = await _supabase.rpc(
      'certificate_lookup',
      params: {'p_code': code},
    );
    final rows = result as List;
    if (rows.isEmpty) return null;
    return CertificateInfo.fromJson(Map<String, dynamic>.from(rows.first));
  }

  // ==================== MATÉRIAS (course_subject) ====================

  /// Matérias do curso, na ordem em que foram criadas.
  Future<List<CourseSubject>> getCourseSubjects(String courseId) async {
    final response = await _supabase
        .from('course_subject')
        .select('id, course_id, title, lesson_count, default_teacher_id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('course_id', courseId)
        .order('created_at');

    return (response as List)
        .map((json) => CourseSubject.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Cria ([id] nulo) ou grava a matéria inteira; professor nulo apaga.
  Future<void> saveCourseSubject({
    String? id,
    required String courseId,
    required String title,
    required int lessonCount,
    String? defaultTeacherId,
  }) async {
    final data = {
      'title': title,
      'lesson_count': lessonCount,
      'default_teacher_id': defaultTeacherId,
    };
    if (id == null) {
      await _supabase.from('course_subject').insert({
        ...data,
        'course_id': courseId,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    } else {
      await _supabase
          .from('course_subject')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select('id')
          .single();
    }
  }

  /// Apaga a matéria. As aulas dela ficam, sem matéria (FK SET NULL).
  Future<void> deleteCourseSubject(String id) async {
    await _supabase
        .from('course_subject')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select('id')
        .single();
  }
}
