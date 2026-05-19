import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/visitor_recommendation.dart';
import 'raizes_dashboard_provider.dart';

/// Argumento do provider de recomendações: ministério + filtro de status.
class RaizesRecommendationsArgs {
  final String ministryId;
  final VisitorRecommendationStatus? status;

  const RaizesRecommendationsArgs({
    required this.ministryId,
    this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaizesRecommendationsArgs &&
          other.ministryId == ministryId &&
          other.status == status;

  @override
  int get hashCode => ministryId.hashCode ^ (status?.hashCode ?? 0);
}

/// Lista de sugestões de padrinho do ministério, com info joined de visitor +
/// sponsor para render direto na tela.
final raizesRecommendationsProvider = FutureProvider.family<
    List<VisitorRecommendation>, RaizesRecommendationsArgs>(
  (ref, args) async {
    final repo = ref.watch(raizesRepositoryProvider);
    return repo.getRecommendations(
      ministryId: args.ministryId,
      status: args.status,
    );
  },
);
