import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/members_repository.dart';
import '../../domain/models/member.dart';

/// Provider do MembersRepository
final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MembersRepository(supabase);
});

/// Provider para buscar todos os membros
final allMembersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.getAllMembers();
});

/// Provider para buscar membros ativos
final activeMembersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.getActiveMembers();
});

/// Provider para buscar visitantes
final visitorsProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.getVisitors();
});

/// Provider para contar total de membros
final totalMembersCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.countAllMembers();
});

/// Provider para contar membros ativos
final activeMembersCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.countMembersByStatus('member_active');
});

/// Provider para contar visitantes
final visitorsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.countMembersByStatus('visitor');
});

/// Provider para buscar membro por ID
final memberByIdProvider = FutureProvider.family<Member?, String>((ref, id) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.getMemberById(id);
});

/// Provider para pesquisa de membros
final searchMembersProvider = FutureProvider.family<List<Member>, String>((ref, query) async {
  final repo = ref.watch(membersRepositoryProvider);
  if (query.isEmpty) {
    return repo.getAllMembers();
  }
  return repo.searchMembers(query);
});

