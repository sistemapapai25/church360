import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/study_group_repository.dart';
import '../../domain/models/study_group.dart';
import '../../../members/presentation/providers/members_provider.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final studyGroupRepositoryProvider = Provider<StudyGroupRepository>((ref) {
  return StudyGroupRepository(Supabase.instance.client);
});

// =====================================================
// STUDY GROUPS PROVIDERS
// =====================================================

/// Todos os grupos
final allStudyGroupsProvider = FutureProvider<List<StudyGroup>>((ref) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getAllStudyGroups();
});

/// Grupos ativos
final activeStudyGroupsProvider = FutureProvider<List<StudyGroup>>((ref) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getActiveStudyGroups();
});

/// Grupos públicos
final publicStudyGroupsProvider = FutureProvider<List<StudyGroup>>((ref) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getPublicStudyGroups();
});

/// Grupos do usuário
final userStudyGroupsProvider = FutureProvider.family<List<StudyGroup>, String>((ref, userId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getUserStudyGroups(userId);
});

final currentUserStudyGroupsProvider = FutureProvider<List<StudyGroup>>((ref) async {
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return const [];
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getUserStudyGroups(member.id);
});

/// Grupo por ID
final studyGroupByIdProvider = FutureProvider.family<StudyGroup?, String>((ref, id) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getStudyGroupById(id);
});

// =====================================================
// STUDY LESSONS PROVIDERS
// =====================================================

/// Lições do grupo
final groupLessonsProvider = FutureProvider.family<List<StudyLesson>, String>((ref, groupId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getGroupLessons(groupId);
});

/// Lições publicadas do grupo
final publishedLessonsProvider = FutureProvider.family<List<StudyLesson>, String>((ref, groupId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getPublishedLessons(groupId);
});

/// Lição por ID
final lessonByIdProvider = FutureProvider.family<StudyLesson?, String>((ref, id) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getLessonById(id);
});

// =====================================================
// STUDY PARTICIPANTS PROVIDERS
// =====================================================

/// Participantes do grupo
final groupParticipantsProvider = FutureProvider.family<List<StudyParticipant>, String>((ref, groupId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getGroupParticipants(groupId);
});

/// Participação do usuário no grupo
final userParticipationProvider = FutureProvider.family<StudyParticipant?, ({String groupId, String userId})>((ref, params) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getUserParticipation(params.groupId, params.userId);
});

/// Verificar se usuário é líder
final isUserLeaderProvider = FutureProvider.family<bool, ({String groupId, String userId})>((ref, params) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.isUserLeader(params.groupId, params.userId);
});

// =====================================================
// STUDY ATTENDANCE PROVIDERS
// =====================================================

/// Presença de uma lição
final lessonAttendanceProvider = FutureProvider.family<List<StudyAttendance>, String>((ref, lessonId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getLessonAttendance(lessonId);
});

/// Presença do usuário em uma lição
final userLessonAttendanceProvider = FutureProvider.family<StudyAttendance?, ({String lessonId, String userId})>((ref, params) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getUserLessonAttendance(params.lessonId, params.userId);
});

// =====================================================
// STUDY COMMENTS PROVIDERS
// =====================================================

/// Comentários de uma lição
final lessonCommentsProvider = FutureProvider.family<List<StudyComment>, String>((ref, lessonId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getLessonComments(lessonId);
});

// =====================================================
// STUDY RESOURCES PROVIDERS
// =====================================================

/// Recursos do grupo
final groupResourcesProvider = FutureProvider.family<List<StudyResource>, String>((ref, groupId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getGroupResources(groupId);
});

// =====================================================
// STATS PROVIDERS
// =====================================================

/// Estatísticas do grupo
final groupStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, groupId) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getGroupStats(groupId);
});

/// Taxa de presença do participante
final participantAttendanceRateProvider = FutureProvider.family<double, ({String groupId, String userId})>((ref, params) async {
  final repository = ref.watch(studyGroupRepositoryProvider);
  return repository.getParticipantAttendanceRate(params.groupId, params.userId);
});

// =====================================================
// ACTIONS PROVIDER
// =====================================================

final studyGroupActionsProvider = Provider<StudyGroupActions>((ref) {
  return StudyGroupActions(ref);
});

class StudyGroupActions {
  final Ref ref;

  StudyGroupActions(this.ref);

  StudyGroupRepository get _repository => ref.read(studyGroupRepositoryProvider);

  // ===== STUDY GROUPS =====

  Future<void> createGroup({
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
    await _repository.createStudyGroup(
      name: name,
      description: description,
      studyTopic: studyTopic,
      startDate: startDate,
      endDate: endDate,
      meetingDay: meetingDay,
      meetingTime: meetingTime,
      meetingLocation: meetingLocation,
      maxParticipants: maxParticipants,
      isPublic: isPublic,
      coverImageUrl: coverImageUrl,
    );
    ref.invalidate(allStudyGroupsProvider);
    ref.invalidate(activeStudyGroupsProvider);
    ref.invalidate(publicStudyGroupsProvider);
  }

  Future<void> updateGroup(
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
    await _repository.updateStudyGroup(
      id,
      name: name,
      description: description,
      studyTopic: studyTopic,
      status: status,
      startDate: startDate,
      endDate: endDate,
      meetingDay: meetingDay,
      meetingTime: meetingTime,
      meetingLocation: meetingLocation,
      maxParticipants: maxParticipants,
      isPublic: isPublic,
      coverImageUrl: coverImageUrl,
    );
    ref.invalidate(allStudyGroupsProvider);
    ref.invalidate(studyGroupByIdProvider(id));
  }

  Future<void> deleteGroup(String id) async {
    await _repository.deleteStudyGroup(id);
    ref.invalidate(allStudyGroupsProvider);
  }

  // ===== STUDY LESSONS =====

  Future<void> createLesson({
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
    await _repository.createLesson(
      studyGroupId: studyGroupId,
      lessonNumber: lessonNumber,
      title: title,
      description: description,
      bibleReferences: bibleReferences,
      content: content,
      discussionQuestions: discussionQuestions,
      status: status,
      scheduledDate: scheduledDate,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      pdfUrl: pdfUrl,
    );
    ref.invalidate(groupLessonsProvider(studyGroupId));
    ref.invalidate(publishedLessonsProvider(studyGroupId));
  }

  Future<void> updateLesson(
    String id,
    String studyGroupId, {
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
    await _repository.updateLesson(
      id,
      lessonNumber: lessonNumber,
      title: title,
      description: description,
      bibleReferences: bibleReferences,
      content: content,
      discussionQuestions: discussionQuestions,
      status: status,
      scheduledDate: scheduledDate,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      pdfUrl: pdfUrl,
    );
    ref.invalidate(groupLessonsProvider(studyGroupId));
    ref.invalidate(lessonByIdProvider(id));
  }

  Future<void> deleteLesson(String id, String studyGroupId) async {
    await _repository.deleteLesson(id);
    ref.invalidate(groupLessonsProvider(studyGroupId));
  }

  // ===== PARTICIPANTS =====

  Future<void> joinGroup(String groupId, String userId) async {
    await _repository.addParticipant(
      groupId: groupId,
      userId: userId,
      role: ParticipantRole.participant,
    );
    ref.invalidate(groupParticipantsProvider(groupId));
    ref.invalidate(userParticipationProvider((groupId: groupId, userId: userId)));
  }

  Future<void> addParticipant({
    required String groupId,
    required String userId,
    required ParticipantRole role,
  }) async {
    await _repository.addParticipant(
      groupId: groupId,
      userId: userId,
      role: role,
    );
    ref.invalidate(groupParticipantsProvider(groupId));
  }

  Future<void> updateParticipantRole(
    String participantId,
    String groupId,
    ParticipantRole role,
  ) async {
    await _repository.updateParticipantRole(participantId, role);
    ref.invalidate(groupParticipantsProvider(groupId));
  }

  Future<void> removeParticipant(String participantId, String groupId) async {
    await _repository.removeParticipant(participantId);
    ref.invalidate(groupParticipantsProvider(groupId));
  }

  Future<void> leaveGroup(String groupId) async {
    await _repository.leaveGroup(groupId);
    ref.invalidate(groupParticipantsProvider(groupId));
    ref.invalidate(userStudyGroupsProvider);
  }

  // ===== ATTENDANCE =====

  Future<void> markAttendance({
    required String lessonId,
    required String userId,
    required AttendanceStatus status,
    String? justification,
    String? notes,
  }) async {
    await _repository.markAttendance(
      lessonId: lessonId,
      userId: userId,
      status: status,
      justification: justification,
      notes: notes,
    );
    ref.invalidate(lessonAttendanceProvider(lessonId));
    ref.invalidate(userLessonAttendanceProvider((lessonId: lessonId, userId: userId)));
  }

  Future<void> updateAttendance(
    String attendanceId,
    String lessonId, {
    AttendanceStatus? status,
    String? justification,
    String? notes,
  }) async {
    await _repository.updateAttendance(
      attendanceId,
      status: status,
      justification: justification,
      notes: notes,
    );
    ref.invalidate(lessonAttendanceProvider(lessonId));
  }

  Future<void> deleteAttendance(String attendanceId, String lessonId) async {
    await _repository.deleteAttendance(attendanceId);
    ref.invalidate(lessonAttendanceProvider(lessonId));
  }

  // ===== COMMENTS =====

  Future<void> createComment({
    required String lessonId,
    required String content,
    String? parentCommentId,
  }) async {
    await _repository.createComment(
      lessonId: lessonId,
      content: content,
      parentCommentId: parentCommentId,
    );
    ref.invalidate(lessonCommentsProvider(lessonId));
  }

  Future<void> updateComment(String commentId, String lessonId, String content) async {
    await _repository.updateComment(commentId, content);
    ref.invalidate(lessonCommentsProvider(lessonId));
  }

  Future<void> deleteComment(String commentId, String lessonId) async {
    await _repository.deleteComment(commentId);
    ref.invalidate(lessonCommentsProvider(lessonId));
  }

  // ===== RESOURCES =====

  Future<void> createResource({
    required String groupId,
    required String title,
    String? description,
    String? resourceType,
    required String url,
    int? fileSize,
  }) async {
    await _repository.createResource(
      groupId: groupId,
      title: title,
      description: description,
      resourceType: resourceType,
      url: url,
      fileSize: fileSize,
    );
    ref.invalidate(groupResourcesProvider(groupId));
  }

  Future<void> updateResource(
    String resourceId,
    String groupId, {
    String? title,
    String? description,
    String? resourceType,
    String? url,
  }) async {
    await _repository.updateResource(
      resourceId,
      title: title,
      description: description,
      resourceType: resourceType,
      url: url,
    );
    ref.invalidate(groupResourcesProvider(groupId));
  }

  Future<void> deleteResource(String resourceId, String groupId) async {
    await _repository.deleteResource(resourceId);
    ref.invalidate(groupResourcesProvider(groupId));
  }
}
