import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/diaconato_attendance_repository.dart';
import '../../domain/models/diaconato_dashboard_stats.dart';
import '../../domain/models/worship_attendance.dart';

/// Provider do repository de presença do Diaconato.
final diaconatoAttendanceRepositoryProvider =
    Provider<DiaconatoAttendanceRepository>((ref) {
  return DiaconatoAttendanceRepository(Supabase.instance.client);
});

/// Pessoas elegíveis para o checklist (membros ativos + visitantes/novos
/// convertidos cadastrados em `user_account`). Cacheável durante a sessão.
final diaconatoEligiblePeopleProvider =
    FutureProvider<List<DiaconatoEligiblePerson>>((ref) async {
  final repo = ref.watch(diaconatoAttendanceRepositoryProvider);
  return repo.getEligiblePeople();
});

/// KPIs do dashboard do Diaconato para um ministério específico.
final diaconatoDashboardStatsProvider =
    FutureProvider.family<DiaconatoDashboardStats, String>(
        (ref, ministryId) async {
  final repo = ref.watch(diaconatoAttendanceRepositoryProvider);
  return repo.getDashboardStats(ministryId);
});
