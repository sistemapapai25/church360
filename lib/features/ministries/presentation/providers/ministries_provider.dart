import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministries_repository.dart';
import '../../domain/models/ministry.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Provider do repository de ministérios
final ministriesRepositoryProvider = Provider<MinistriesRepository>((ref) {
  return MinistriesRepository(Supabase.instance.client);
});

/// Provider de todos os ministérios
final allMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getAllMinistries();
});

/// Provider de ministérios ativos
final activeMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getActiveMinistries();
});

/// Provider de ministério por ID
final ministryByIdProvider = FutureProvider.family<Ministry?, String>((ref, id) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistryById(id);
});

/// Provider de contagem total de ministérios
final totalMinistriesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.countMinistries();
});

/// Provider de contagem de ministérios ativos
final activeMinistriesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.countActiveMinistries();
});

/// Provider de membros de um ministério
final ministryMembersProvider = FutureProvider.family<List<MinistryMember>, String>((ref, ministryId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistryMembers(ministryId);
});

/// Provider de ministérios de um membro
final memberMinistriesProvider = FutureProvider.family<List<Ministry>, String>((ref, memberId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMemberMinistries(memberId);
});

/// Provider de ministérios do membro atual (resolve id correto via cadastro)
final currentMemberMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return [];
  return repo.getMemberMinistries(member.id);
});

/// Provider de escalas de um evento
final eventSchedulesProvider = FutureProvider.family<List<MinistrySchedule>, String>((ref, eventId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getEventSchedules(eventId);
});

/// Provider de escalas de um ministério
final ministrySchedulesProvider = FutureProvider.family<List<MinistrySchedule>, String>((ref, ministryId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistrySchedules(ministryId);
});
