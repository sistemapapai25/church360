import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/raizes_repository.dart';
import '../../domain/models/raizes_visit.dart';
import 'raizes_dashboard_provider.dart';

/// Argumento do provider de lista de visitas: ministério + filtro.
class RaizesVisitsArgs {
  final String ministryId;
  final RaizesVisitsFilter filter;

  const RaizesVisitsArgs({required this.ministryId, required this.filter});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaizesVisitsArgs &&
          other.ministryId == ministryId &&
          other.filter == filter;

  @override
  int get hashCode => ministryId.hashCode ^ filter.hashCode;
}

/// Lista de visitas para o ministério, conforme filtro.
final raizesVisitsProvider =
    FutureProvider.family<List<RaizesVisit>, RaizesVisitsArgs>(
  (ref, args) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getVisits(ministryId: args.ministryId, filter: args.filter);
  },
);

/// Lista de visitantes elegíveis para o dropdown de criação de visita.
final raizesEligibleVisitorsProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final repo = ref.watch(raizesRepositoryProvider);
  return repo.getEligibleVisitors();
});

/// Lista de membros do ministério (responsáveis possíveis).
final raizesEligibleAssigneesProvider =
    FutureProvider.family<List<Map<String, String>>, String>(
  (ref, ministryId) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getEligibleAssignees(ministryId);
  },
);
