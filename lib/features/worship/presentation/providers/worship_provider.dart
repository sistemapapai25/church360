import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/worship_repository.dart';
import '../../domain/models/worship_service.dart';

/// Provider do repository de cultos
final worshipRepositoryProvider = Provider<WorshipRepository>((ref) {
  return WorshipRepository(Supabase.instance.client);
});

/// Provider de todos os cultos
final allWorshipServicesProvider = FutureProvider<List<WorshipService>>((ref) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getAllWorshipServices();
});

/// Provider de culto por ID
final worshipServiceByIdProvider = FutureProvider.family<WorshipService?, String>((ref, id) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getWorshipServiceById(id);
});

/// Provider de cultos por período
final worshipServicesByDateRangeProvider = FutureProvider.family<List<WorshipService>, Map<String, DateTime>>((ref, dateRange) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getWorshipServicesByDateRange(
    dateRange['startDate']!,
    dateRange['endDate']!,
  );
});

/// Provider de presenças de um culto
final worshipAttendanceProvider = FutureProvider.family<List<WorshipAttendance>, String>((ref, worshipServiceId) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getWorshipAttendance(worshipServiceId);
});

/// Provider de histórico de presença de um membro
final memberAttendanceHistoryProvider = FutureProvider.family<List<WorshipAttendance>, String>((ref, memberId) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getMemberAttendanceHistory(memberId);
});

/// Provider de estatísticas de frequência de um membro
final memberAttendanceStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getMemberAttendanceStats(memberId);
});

/// Provider de membros ausentes
final absentMembersProvider = FutureProvider.family<List<String>, int>((ref, lastServicesCount) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getAbsentMembers(lastServicesCount: lastServicesCount);
});

/// Provider de contagem total de cultos
final totalWorshipServicesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.countWorshipServices();
});

