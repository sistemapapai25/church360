import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/study_group.dart';
import '../domain/models/teaching_lesson.dart';

class StudyGroupRepository {
  final SupabaseClient _supabase;

  StudyGroupRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc(
          'ensure_my_account',
          params: {
            '_tenant_id': SupabaseConstants.currentTenantId,
            '_email': email,
            '_nickname': nickname,
          },
        );
      } catch (_) {}
    }
    try {
      final byAuthId = await _supabase
          .from('user_account')
          .select('id')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('auth_user_id', user.id)
          .limit(1)
          .maybeSingle();
      final resolvedId = (byAuthId?['id'] as String?)?.trim();
      if (resolvedId != null && resolvedId.isNotEmpty) {
        return resolvedId;
      }
    } catch (_) {}

    try {
      final byId = await _supabase
          .from('user_account')
          .select('id')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('id', user.id)
          .limit(1)
          .maybeSingle();
      final resolvedId = (byId?['id'] as String?)?.trim();
      if (resolvedId != null && resolvedId.isNotEmpty) {
        return resolvedId;
      }
    } catch (_) {}

    return user.id;
  }

  Future<Set<String>> _candidateUserIds(String userId) async {
    final ids = <String>{};
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isNotEmpty) {
      ids.add(normalizedUserId);
    }

    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.trim().isNotEmpty) {
      ids.add(authId.trim());
    }

    final seeds = ids.toList(growable: false);
    for (final seed in seeds) {
      try {
        final rows = await _supabase
            .from('user_account')
            .select('id, auth_user_id')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .or('id.eq.$seed,auth_user_id.eq.$seed')
            .limit(5);
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] as String?)?.trim();
          final authUserId = (row['auth_user_id'] as String?)?.trim();
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
          if (authUserId != null && authUserId.isNotEmpty) {
            ids.add(authUserId);
          }
        }
      } catch (_) {}
    }

    return ids;
  }

  // =====================================================
  // STUDY GROUPS - CRUD
  // =====================================================

  /// Obter todos os grupos (públicos ou que o usuário participa)
  Future<List<StudyGroup>> getAllStudyGroups() async {
    final response = await _supabase
        .from('study_groups')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => StudyGroup.fromJson(json)).toList();
  }

  /// Obter grupos ativos
  Future<List<StudyGroup>> getActiveStudyGroups() async {
    final response = await _supabase
        .from('study_groups')
        .select()
        .eq('status', 'active')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => StudyGroup.fromJson(json)).toList();
  }

  /// Obter grupos públicos
  Future<List<StudyGroup>> getPublicStudyGroups() async {
    final response = await _supabase
        .from('study_groups')
        .select()
        .eq('is_public', true)
        .eq('status', 'active')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => StudyGroup.fromJson(json)).toList();
  }

  /// Obter grupos do usuário
  Future<List<StudyGroup>> getUserStudyGroups(String userId) async {
    try {
      final response = await _supabase
          .from('study_groups')
          .select('''
            *,
            study_participants!inner(user_id)
          ''')
          .eq('study_participants.user_id', userId)
          .eq('study_participants.is_active', true)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StudyGroup.fromJson(json))
          .toList();
    } catch (e) {
      final msg = e.toString();
      final isPolicyRecursion =
          msg.contains('infinite recursion detected in policy') ||
          msg.contains('42P17');
      if (isPolicyRecursion) return const [];
      rethrow;
    }
  }

  /// Obter grupo por ID
  Future<StudyGroup?> getStudyGroupById(String id) async {
    final response = await _supabase
        .from('study_groups')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return StudyGroup.fromJson(response);
  }

  /// Criar grupo
  Future<StudyGroup> createStudyGroup({
    required String courseId,
    required String name,
    String? description,
    String? studyTopic,
    required DateTime startDate,
    DateTime? endDate,
    String? meetingDay,
    String? meetingTime,
    String? meetingLocation,
    int? maxParticipants,
    bool isPublic = true,
    String? coverImageUrl,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('study_groups')
        .insert({
          'course_id': courseId,
          'name': name,
          'description': description,
          'study_topic': studyTopic,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'meeting_day': meetingDay,
          'meeting_time': meetingTime,
          'meeting_location': meetingLocation,
          'max_participants': maxParticipants,
          'is_public': isPublic,
          'cover_image_url': coverImageUrl,
          'created_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyGroup.fromJson(response);
  }

  /// Atualizar grupo
  Future<StudyGroup> updateStudyGroup(
    String id, {
    String? name,
    String? description,
    String? studyTopic,
    StudyGroupStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? meetingDay,
    String? meetingTime,
    String? meetingLocation,
    int? maxParticipants,
    bool? isPublic,
    String? coverImageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (studyTopic != null) data['study_topic'] = studyTopic;
    if (status != null) data['status'] = status.value;
    if (startDate != null) data['start_date'] = startDate.toIso8601String();
    if (endDate != null) data['end_date'] = endDate.toIso8601String();
    if (meetingDay != null) data['meeting_day'] = meetingDay;
    if (meetingTime != null) data['meeting_time'] = meetingTime;
    if (meetingLocation != null) data['meeting_location'] = meetingLocation;
    if (maxParticipants != null) data['max_participants'] = maxParticipants;
    if (isPublic != null) data['is_public'] = isPublic;
    if (coverImageUrl != null) data['cover_image_url'] = coverImageUrl;

    final response = await _supabase
        .from('study_groups')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyGroup.fromJson(response);
  }

  /// Deletar grupo
  Future<void> deleteStudyGroup(String id) async {
    await _supabase
        .from('study_groups')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STUDY LESSONS - CRUD
  // =====================================================

  /// Obter lições do grupo
  Future<List<StudyLesson>> getGroupLessons(String groupId) async {
    final response = await _supabase
        .from('study_lessons')
        .select()
        .eq('study_group_id', groupId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('lesson_number', ascending: true);

    return (response as List)
        .map((json) => StudyLesson.fromJson(json))
        .toList();
  }

  /// Obter lições publicadas do grupo
  Future<List<StudyLesson>> getPublishedLessons(String groupId) async {
    final response = await _supabase
        .from('study_lessons')
        .select()
        .eq('study_group_id', groupId)
        .eq('status', 'published')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('lesson_number', ascending: true);

    return (response as List)
        .map((json) => StudyLesson.fromJson(json))
        .toList();
  }

  /// Obter lição por ID
  Future<StudyLesson?> getLessonById(String id) async {
    final response = await _supabase
        .from('study_lessons')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return StudyLesson.fromJson(response);
  }

  /// Criar lição
  Future<StudyLesson> createLesson({
    required String studyGroupId,
    required int lessonNumber,
    required String title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    LessonStatus status = LessonStatus.draft,
    DateTime? scheduledDate,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
    String? subjectId,
    String? teacherId,
    String? startTime,
    int? durationMinutes,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('study_lessons')
        .insert({
          'study_group_id': studyGroupId,
          'lesson_number': lessonNumber,
          'title': title,
          'description': description,
          'bible_references': bibleReferences,
          'content': content,
          'discussion_questions': discussionQuestions,
          'status': status.value,
          'scheduled_date': scheduledDate?.toIso8601String(),
          'video_url': videoUrl,
          'audio_url': audioUrl,
          'pdf_url': pdfUrl,
          'subject_id': subjectId,
          'teacher_id': teacherId,
          'start_time': startTime,
          'duration_minutes': durationMinutes,
          'created_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyLesson.fromJson(response);
  }

  /// Grava o conteúdo editável da aula **inteiro**, inclusive os campos
  /// vazios: `null` aqui apaga a coluna.
  ///
  /// Existe porque [updateLesson] ignora campo `null` ("não mexer"), e com
  /// ele não havia como remover o vídeo ou o PDF de uma aula (emenda (c) do
  /// ROADMAP-FORMACAO). Não mexe em número, status nem turma.
  Future<StudyLesson> replaceLessonContent(
    String id, {
    required String title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    DateTime? scheduledDate,
    String? videoUrl,
    String? pdfUrl,
    String? subjectId,
    String? teacherId,
    String? startTime,
    int? durationMinutes,
  }) async {
    final response = await _supabase
        .from('study_lessons')
        .update({
          'title': title,
          'description': description,
          'bible_references': bibleReferences,
          'content': content,
          'discussion_questions': discussionQuestions,
          'scheduled_date': scheduledDate?.toIso8601String(),
          'video_url': videoUrl,
          'pdf_url': pdfUrl,
          'subject_id': subjectId,
          'teacher_id': teacherId,
          'start_time': startTime,
          'duration_minutes': durationMinutes,
        })
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyLesson.fromJson(response);
  }

  /// Atualizar lição. Campo `null` = não mexer; para limpar campo use
  /// [replaceLessonContent].
  Future<StudyLesson> updateLesson(
    String id, {
    int? lessonNumber,
    String? title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    LessonStatus? status,
    DateTime? scheduledDate,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
  }) async {
    final data = <String, dynamic>{};
    if (lessonNumber != null) data['lesson_number'] = lessonNumber;
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (bibleReferences != null) data['bible_references'] = bibleReferences;
    if (content != null) data['content'] = content;
    if (discussionQuestions != null) {
      data['discussion_questions'] = discussionQuestions;
    }
    if (status != null) data['status'] = status.value;
    if (scheduledDate != null) {
      data['scheduled_date'] = scheduledDate.toIso8601String();
    }
    if (videoUrl != null) data['video_url'] = videoUrl;
    if (audioUrl != null) data['audio_url'] = audioUrl;
    if (pdfUrl != null) data['pdf_url'] = pdfUrl;

    final response = await _supabase
        .from('study_lessons')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyLesson.fromJson(response);
  }

  /// As aulas de que eu sou o professor, de [from] até [to] (sem [to], dali
  /// em diante). RPC `my_teaching_lessons`: o professor não lê a turma.
  Future<List<TeachingLesson>> getMyTeachingLessons(
    DateTime from, [
    DateTime? to,
  ]) async {
    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    final response = await _supabase.rpc(
      'my_teaching_lessons',
      params: {'p_from': day(from), 'p_to': to == null ? null : day(to)},
    );
    return (response as List)
        .map((row) => TeachingLesson.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// A chamada da aula de que eu sou o professor (`teacher_lesson_roll`).
  Future<List<TeacherRollEntry>> getTeacherLessonRoll(String lessonId) async {
    final response = await _supabase.rpc(
      'teacher_lesson_roll',
      params: {'p_lesson_id': lessonId},
    );
    return [
      for (final row in response as List)
        (
          studentId: row['student_id'] as String,
          name: row['full_name'] as String,
          status: row['status'] == null
              ? null
              : AttendanceStatus.fromString(row['status'] as String),
        ),
    ];
  }

  /// Marca a presença pelo professor da aula (`teacher_set_attendance`).
  Future<void> teacherSetAttendance(
    String lessonId,
    String studentId,
    AttendanceStatus status,
  ) async {
    await _supabase.rpc(
      'teacher_set_attendance',
      params: {
        'p_lesson_id': lessonId,
        'p_student_id': studentId,
        'p_status': status.value,
      },
    );
  }

  /// Grava só o professor da aula (Escala de ensino, PR 2b).
  Future<void> setLessonTeacher(String id, String? teacherId) async {
    await _supabase
        .from('study_lessons')
        .update({'teacher_id': teacherId})
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Deletar lição
  Future<void> deleteLesson(String id) async {
    await _supabase
        .from('study_lessons')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STUDY PARTICIPANTS - CRUD
  // =====================================================

  /// Obter participantes do grupo
  Future<List<StudyParticipant>> getGroupParticipants(String groupId) async {
    final response = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .eq('is_active', true)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('role', ascending: true);

    return (response as List)
        .map((json) => StudyParticipant.fromJson(json))
        .toList();
  }

  /// Obter participação do usuário no grupo
  Future<StudyParticipant?> getUserParticipation(
    String groupId,
    String userId,
  ) async {
    final candidateIds = await _candidateUserIds(userId);
    final response = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .inFilter('user_id', candidateIds.toList())
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return StudyParticipant.fromJson(response);
  }

  /// Verificar se usuário é líder do grupo
  Future<bool> isUserLeader(String groupId, String userId) async {
    final candidateIds = await _candidateUserIds(userId);
    final response = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .inFilter('user_id', candidateIds.toList())
        .eq('is_active', true)
        .inFilter('role', ['leader', 'co_leader'])
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .limit(1)
        .maybeSingle();

    return response != null;
  }

  /// Adicionar participante ao grupo
  Future<StudyParticipant> addParticipant({
    required String groupId,
    required String userId,
    ParticipantRole role = ParticipantRole.participant,
  }) async {
    final existing = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existing != null) {
      final response = await _supabase
          .from('study_participants')
          .update({'role': role.value, 'is_active': true, 'left_at': null})
          .eq('id', existing['id'])
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();
      return StudyParticipant.fromJson(response);
    }

    try {
      final response = await _supabase
          .from('study_participants')
          .insert({
            'study_group_id': groupId,
            'user_id': userId,
            'role': role.value,
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return StudyParticipant.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final recovered = await _supabase
            .from('study_participants')
            .select()
            .eq('study_group_id', groupId)
            .eq('user_id', userId)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .maybeSingle();
        if (recovered != null) {
          return StudyParticipant.fromJson(recovered);
        }
      }
      rethrow;
    }
  }

  /// Atualizar papel do participante
  Future<StudyParticipant> updateParticipantRole(
    String participantId,
    ParticipantRole role,
  ) async {
    final response = await _supabase
        .from('study_participants')
        .update({'role': role.value})
        .eq('id', participantId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyParticipant.fromJson(response);
  }

  /// Remover participante (marcar como inativo)
  Future<void> removeParticipant(String participantId) async {
    await _supabase
        .from('study_participants')
        .update({
          'is_active': false,
          'left_at': DateTime.now().toIso8601String(),
        })
        .eq('id', participantId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Sair do grupo (usuário atual)
  Future<void> leaveGroup(String groupId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    await _supabase
        .from('study_participants')
        .update({
          'is_active': false,
          'left_at': DateTime.now().toIso8601String(),
        })
        .eq('study_group_id', groupId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STUDY ATTENDANCE - CRUD
  // =====================================================

  /// Obter presença de uma lição
  /// Observações da aula de uma visibilidade, mais novas primeiro. A RLS
  /// devolve só as que a pessoa lê (pessoal: as dela; liderança: quem
  /// edita a aula).
  Future<List<StudyLessonNote>> getLessonNotes(
    String lessonId,
    LessonNoteVisibility visibility,
  ) async {
    final response = await _supabase
        .from('study_lesson_note')
        .select()
        .eq('study_lesson_id', lessonId)
        .eq('visibility', visibility.name)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => StudyLessonNote.fromJson(json))
        .toList();
  }

  /// O autor é preenchido pelo banco (`my_user_account_id()`).
  Future<void> addLessonNote({
    required String lessonId,
    required LessonNoteVisibility visibility,
    required String body,
  }) async {
    await _supabase.from('study_lesson_note').insert({
      'tenant_id': SupabaseConstants.currentTenantId,
      'study_lesson_id': lessonId,
      'visibility': visibility.name,
      'body': body,
    });
  }

  Future<void> deleteLessonNote(String id) async {
    await _supabase.from('study_lesson_note').delete().eq('id', id);
  }

  Future<List<StudyAttendance>> getLessonAttendance(String lessonId) async {
    final response = await _supabase
        .from('study_attendance')
        .select()
        .eq('study_lesson_id', lessonId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    return (response as List)
        .map((json) => StudyAttendance.fromJson(json))
        .toList();
  }

  /// Presença do próprio usuário nas aulas informadas.
  ///
  /// Chave `auth.uid()`, a mesma da policy `study_attendance_select`
  /// (`user_id = auth.uid()`): o aluno só enxerga as próprias linhas.
  Future<List<StudyAttendance>> getMyAttendanceForLessons(
    List<String> lessonIds,
  ) async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null || lessonIds.isEmpty) return const [];
    final response = await _supabase
        .from('study_attendance')
        .select()
        .inFilter('study_lesson_id', lessonIds)
        .eq('user_id', authId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    return (response as List)
        .map((json) => StudyAttendance.fromJson(json))
        .toList();
  }

  /// Obter presença do usuário em uma lição
  Future<StudyAttendance?> getUserLessonAttendance(
    String lessonId,
    String userId,
  ) async {
    final response = await _supabase
        .from('study_attendance')
        .select()
        .eq('study_lesson_id', lessonId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return StudyAttendance.fromJson(response);
  }

  /// Marcar presença
  Future<StudyAttendance> markAttendance({
    required String lessonId,
    required String userId,
    required AttendanceStatus status,
    String? justification,
    String? notes,
  }) async {
    final currentUserId = await _effectiveUserId();
    if (currentUserId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('study_attendance')
        .insert({
          'study_lesson_id': lessonId,
          'user_id': userId,
          'status': status.value,
          'justification': justification,
          'notes': notes,
          'marked_by': currentUserId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyAttendance.fromJson(response);
  }

  /// Atualizar presença
  Future<StudyAttendance> updateAttendance(
    String attendanceId, {
    AttendanceStatus? status,
    String? justification,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (status != null) data['status'] = status.value;
    if (justification != null) data['justification'] = justification;
    if (notes != null) data['notes'] = notes;

    final response = await _supabase
        .from('study_attendance')
        .update(data)
        .eq('id', attendanceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyAttendance.fromJson(response);
  }

  /// Deletar presença
  Future<void> deleteAttendance(String attendanceId) async {
    await _supabase
        .from('study_attendance')
        .delete()
        .eq('id', attendanceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STUDY COMMENTS - CRUD
  // =====================================================

  /// Obter comentários de uma lição
  Future<List<StudyComment>> getLessonComments(String lessonId) async {
    final response = await _supabase
        .from('study_comments')
        .select()
        .eq('study_lesson_id', lessonId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => StudyComment.fromJson(json))
        .toList();
  }

  /// Criar comentário
  Future<StudyComment> createComment({
    required String lessonId,
    required String content,
    String? parentCommentId,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('study_comments')
        .insert({
          'study_lesson_id': lessonId,
          'author_id': userId,
          'content': content,
          'parent_comment_id': parentCommentId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyComment.fromJson(response);
  }

  /// Atualizar comentário
  Future<StudyComment> updateComment(String commentId, String content) async {
    final response = await _supabase
        .from('study_comments')
        .update({'content': content})
        .eq('id', commentId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyComment.fromJson(response);
  }

  /// Deletar comentário
  Future<void> deleteComment(String commentId) async {
    await _supabase
        .from('study_comments')
        .delete()
        .eq('id', commentId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STUDY RESOURCES - CRUD
  // =====================================================

  /// Obter recursos do grupo
  Future<List<StudyResource>> getGroupResources(String groupId) async {
    final response = await _supabase
        .from('study_resources')
        .select()
        .eq('study_group_id', groupId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => StudyResource.fromJson(json))
        .toList();
  }

  /// Criar recurso
  Future<StudyResource> createResource({
    required String groupId,
    required String title,
    String? description,
    String? resourceType,
    required String url,
    int? fileSize,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('study_resources')
        .insert({
          'study_group_id': groupId,
          'title': title,
          'description': description,
          'resource_type': resourceType,
          'url': url,
          'file_size': fileSize,
          'uploaded_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyResource.fromJson(response);
  }

  /// Atualizar recurso
  Future<StudyResource> updateResource(
    String resourceId, {
    String? title,
    String? description,
    String? resourceType,
    String? url,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (resourceType != null) data['resource_type'] = resourceType;
    if (url != null) data['url'] = url;

    final response = await _supabase
        .from('study_resources')
        .update(data)
        .eq('id', resourceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return StudyResource.fromJson(response);
  }

  /// Deletar recurso
  Future<void> deleteResource(String resourceId) async {
    await _supabase
        .from('study_resources')
        .delete()
        .eq('id', resourceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  /// Obter estatísticas do grupo
  Future<Map<String, dynamic>> getGroupStats(String groupId) async {
    final response = await _supabase.rpc(
      'get_group_progress',
      params: {'target_group_id': groupId},
    );

    return response as Map<String, dynamic>;
  }

  /// Obter taxa de presença do participante
  Future<double> getParticipantAttendanceRate(
    String groupId,
    String userId,
  ) async {
    final response = await _supabase.rpc(
      'get_participant_attendance_rate',
      params: {'target_group_id': groupId, 'target_user_id': userId},
    );

    return (response as num).toDouble();
  }
}
