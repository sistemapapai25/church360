import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/raizes_repository.dart';
import '../../domain/models/raizes_dashboard_stats.dart';

/// Provider do repository do Raízes.
final raizesRepositoryProvider = Provider<RaizesRepository>((ref) {
  return RaizesRepository(Supabase.instance.client);
});

/// Provider de KPIs do dashboard Raízes. Family por `ministryId` para permitir
/// múltiplos ministérios do tipo `raizes` no mesmo tenant — hoje os números
/// vêm de `user_account` (não dependem do ministry), mas a chave do family
/// já mantém o cache invalidado por escopo e prepara o terreno para o Lote
/// 4C, quando filtragens específicas do ministério entram.
final raizesDashboardStatsProvider =
    FutureProvider.family<RaizesDashboardStats, String>(
  (ref, ministryId) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getDashboardStats();
  },
);
