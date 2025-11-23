import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/reading_plans_repository.dart';
import '../../domain/models/reading_plan.dart';

/// Provider do repository de planos de leitura
final readingPlansRepositoryProvider = Provider<ReadingPlansRepository>((ref) {
  return ReadingPlansRepository(Supabase.instance.client);
});

/// Provider de todos os planos de leitura
final allReadingPlansProvider = FutureProvider<List<ReadingPlan>>((ref) async {
  final repo = ref.watch(readingPlansRepositoryProvider);
  return repo.getAllPlans();
});

/// Provider de planos ativos
final activeReadingPlansProvider = FutureProvider<List<ReadingPlan>>((ref) async {
  final repo = ref.watch(readingPlansRepositoryProvider);
  return repo.getActivePlans();
});

/// Provider de plano por ID
final readingPlanByIdProvider = FutureProvider.family<ReadingPlan?, String>((ref, id) async {
  final repo = ref.watch(readingPlansRepositoryProvider);
  return repo.getPlanById(id);
});

/// Provider de progresso do usuário em um plano
final userPlanProgressProvider = FutureProvider.family<ReadingPlanProgress?, ({String planId, String memberId})>((ref, params) async {
  final repo = ref.watch(readingPlansRepositoryProvider);
  return repo.getUserProgress(params.planId, params.memberId);
});

/// Provider de todos os planos em progresso do usuário
final userActiveProgressProvider = FutureProvider.family<List<ReadingPlanProgress>, String>((ref, memberId) async {
  final repo = ref.watch(readingPlansRepositoryProvider);
  return repo.getUserActiveProgress(memberId);
});

