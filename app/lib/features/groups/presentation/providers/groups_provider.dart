import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/groups_repository.dart';
import '../../domain/models/group.dart';

/// Provider do repository de grupos
final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return GroupsRepository(supabase);
});

/// Provider de todos os grupos
final allGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getAllGroups();
});

/// Provider de grupos ativos
final activeGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getActiveGroups();
});

/// Provider de grupo por ID
final groupByIdProvider = FutureProvider.family<Group?, String>((ref, id) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getGroupById(id);
});

/// Provider de contagem total de grupos
final totalGroupsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.countGroups();
});

/// Provider de contagem de grupos ativos
final activeGroupsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.countActiveGroups();
});

/// Provider de membros de um grupo
final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getGroupMembers(groupId);
});

/// Provider de reuniões de um grupo
final groupMeetingsProvider = FutureProvider.family<List<GroupMeeting>, String>((ref, groupId) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getGroupMeetings(groupId);
});

