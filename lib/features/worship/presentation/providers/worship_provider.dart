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

/// Provider de visitantes presentes por culto (id do culto -> quantidade)
final worshipVisitorCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getVisitorCountByService();
});

/// Provider de culto por ID
final worshipServiceByIdProvider = FutureProvider.family<WorshipService?, String>((ref, id) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getWorshipServiceById(id);
});

/// Provider de presenças de um culto
final worshipAttendanceProvider = FutureProvider.family<List<WorshipAttendance>, String>((ref, worshipServiceId) async {
  final repo = ref.watch(worshipRepositoryProvider);
  return repo.getWorshipAttendance(worshipServiceId);
});
