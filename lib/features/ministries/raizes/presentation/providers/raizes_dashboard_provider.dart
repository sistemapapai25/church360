import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/raizes_repository.dart';
import '../../domain/models/raizes_dashboard_stats.dart';
import '../../domain/models/raizes_followup.dart';

/// Provider do repository do Raízes.
final raizesRepositoryProvider = Provider<RaizesRepository>((ref) {
  return RaizesRepository(Supabase.instance.client);
});

/// Provider de KPIs do dashboard Raízes. Family por `ministryId`: os números
/// de visitantes vêm de `user_account` (igreja inteira), os de visitas são
/// só do ministério.
final raizesDashboardStatsProvider =
    FutureProvider.family<RaizesDashboardStats, String>(
  (ref, ministryId) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getDashboardStats(ministryId);
  },
);

/// Relatório da aba Relatórios do Raízes (R9), últimos 6 meses.
final raizesReportProvider = FutureProvider.family<RaizesReport, String>(
  (ref, ministryId) => ref.watch(raizesRepositoryProvider).getReport(ministryId),
);
