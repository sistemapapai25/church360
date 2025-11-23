import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/contribution_repository.dart';
import '../../domain/models/contribution_info.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return ContributionRepository(Supabase.instance.client);
});

// =====================================================
// CONTRIBUTION INFO PROVIDERS
// =====================================================

/// Provider para informação de contribuição ativa
final activeContributionInfoProvider = FutureProvider<ContributionInfo?>((ref) async {
  final repository = ref.watch(contributionRepositoryProvider);
  return repository.getActiveContributionInfo();
});

/// Provider para todas as informações de contribuição
final allContributionInfoProvider = FutureProvider<List<ContributionInfo>>((ref) async {
  final repository = ref.watch(contributionRepositoryProvider);
  return repository.getAllContributionInfo();
});

/// Provider para informação de contribuição por ID
final contributionInfoByIdProvider = FutureProvider.family<ContributionInfo?, String>((ref, id) async {
  final repository = ref.watch(contributionRepositoryProvider);
  return repository.getContributionInfoById(id);
});

