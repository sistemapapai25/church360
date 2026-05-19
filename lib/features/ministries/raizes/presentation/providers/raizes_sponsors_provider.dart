import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/raizes_sponsor_profile.dart';
import 'raizes_dashboard_provider.dart';

/// Lista de padrinhos cadastrados num ministério.
final raizesSponsorsProvider =
    FutureProvider.family<List<RaizesSponsorProfile>, String>(
  (ref, ministryId) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getSponsorProfiles(ministryId);
  },
);

/// Membros do ministério ainda não cadastrados como padrinho — para o
/// dropdown de "criar novo padrinho".
final raizesEligibleSponsorCandidatesProvider =
    FutureProvider.family<List<Map<String, String>>, String>(
  (ref, ministryId) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getEligibleSponsorCandidates(ministryId);
  },
);
