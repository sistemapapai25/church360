import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/raizes_repository.dart';
import '../../domain/models/raizes_dashboard_stats.dart';

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
