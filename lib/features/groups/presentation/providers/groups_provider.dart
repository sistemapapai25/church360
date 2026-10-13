import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../permissions/providers/permissions_providers.dart'
    show currentUserHasPermissionProvider;
import '../../data/groups_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_visitor.dart';

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

/// Pode gerenciar ESTE grupo: tem a [permission] (groups.edit,
/// groups.manage_members, groups.manage_meetings) OU é o líder do grupo com
/// groups.manage_own. O segundo caminho pergunta ao banco a mesma função que
/// as policies usam (`group_manage_own_allows`, migration 20261008001900).
final canManageGroupProvider =
    FutureProvider.family<bool, ({String groupId, String permission})>((
      ref,
      args,
    ) async {
      if (await ref.watch(
        currentUserHasPermissionProvider(args.permission).future,
      )) {
        return true;
      }
      if (!await ref.watch(
        currentUserHasPermissionProvider('groups.manage_own').future,
      )) {
        return false;
      }
      final allowed = await ref
          .watch(supabaseClientProvider)
          .rpc('group_manage_own_allows', params: {'p_group': args.groupId});
      return allowed == true;
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

// =====================================================
// VISITANTES
// =====================================================

/// Provider de visitantes de uma reunião
final visitorsProvider = FutureProvider.family<List<GroupVisitor>, String>((ref, meetingId) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getVisitorsByMeeting(meetingId);
});

