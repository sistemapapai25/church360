import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/group_meetings_repository.dart';
import '../../domain/models/group_meeting.dart';

/// Provider para buscar reuniões de um grupo
final meetingsListProvider = FutureProvider.family<List<GroupMeeting>, String>((ref, groupId) async {
  final repository = ref.watch(groupMeetingsRepositoryProvider);
  return repository.getGroupMeetings(groupId);
});

/// Provider para buscar uma reunião por ID
final meetingByIdProvider = FutureProvider.family<GroupMeeting?, String>((ref, meetingId) async {
  final repository = ref.watch(groupMeetingsRepositoryProvider);
  return repository.getMeetingById(meetingId);
});

/// Provider para buscar presenças de uma reunião
final meetingAttendancesProvider = FutureProvider.family<List<GroupAttendance>, String>((ref, meetingId) async {
  final repository = ref.watch(groupMeetingsRepositoryProvider);
  return repository.getMeetingAttendances(meetingId);
});

/// Provider para estatísticas de frequência de um membro
final memberAttendanceStatsProvider = FutureProvider.family<Map<String, dynamic>, ({String groupId, String memberId})>((ref, params) async {
  final repository = ref.watch(groupMeetingsRepositoryProvider);
  return repository.getMemberAttendanceStats(params.groupId, params.memberId);
});

