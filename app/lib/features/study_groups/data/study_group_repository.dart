import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/study_group.dart';

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
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
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

    return (response as List)
        .map((json) => StudyGroup.fromJson(json))
        .toList();
  }

  /// Obter grupos ativos
  Future<List<StudyGroup>> getActiveStudyGroups() async {
    final response = await _supabase
        .from('study_groups')
        .select()
        .eq('status', 'active')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => StudyGroup.fromJson(json))
        .toList();
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

    return (response as List)
        .map((json) => StudyGroup.fromJson(json))
        .toList();
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
      final isPolicyRecursion = msg.contains('infinite recursion detected in policy') || msg.contains('42P17');
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
          'created_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return StudyLesson.fromJson(response);
  }

  /// Atualizar lição
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
    if (discussionQuestions != null) data['discussion_questions'] = discussionQuestions;
    if (status != null) data['status'] = status.value;
    if (scheduledDate != null) data['scheduled_date'] = scheduledDate.toIso8601String();
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
  Future<StudyParticipant?> getUserParticipation(String groupId, String userId) async {
    final response = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return StudyParticipant.fromJson(response);
  }

  /// Verificar se usuário é líder do grupo
  Future<bool> isUserLeader(String groupId, String userId) async {
    final response = await _supabase
        .from('study_participants')
        .select()
        .eq('study_group_id', groupId)
        .eq('user_id', userId)
        .eq('is_active', true)
        .inFilter('role', ['leader', 'co_leader'])
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    return response != null;
  }

  /// Adicionar participante ao grupo
  Future<StudyParticipant> addParticipant({
    required String groupId,
    required String userId,
    ParticipantRole role = ParticipantRole.participant,
  }) async {
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

  /// Obter presença do usuário em uma lição
  Future<StudyAttendance?> getUserLessonAttendance(String lessonId, String userId) async {
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
    final response = await _supabase
        .rpc('get_group_progress', params: {'target_group_id': groupId});

    return response as Map<String, dynamic>;
  }

  /// Obter taxa de presença do participante
  Future<double> getParticipantAttendanceRate(String groupId, String userId) async {
    final response = await _supabase
        .rpc('get_participant_attendance_rate', params: {
          'target_group_id': groupId,
          'target_user_id': userId,
        });

    return (response as num).toDouble();
  }
}
