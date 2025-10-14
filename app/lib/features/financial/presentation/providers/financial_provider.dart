import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/financial_repository.dart';
import '../../domain/models/contribution.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final financialRepositoryProvider = Provider<FinancialRepository>((ref) {
  return FinancialRepository(Supabase.instance.client);
});

// =====================================================
// CONTRIBUIÇÕES
// =====================================================

/// Provider para todas as contribuições
final allContributionsProvider = FutureProvider<List<Contribution>>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getAllContributions();
});

/// Provider para contribuições por membro
final contributionsByMemberProvider =
    FutureProvider.family<List<Contribution>, String>((ref, memberId) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getContributionsByMember(memberId);
});

/// Provider para contribuições por tipo
final contributionsByTypeProvider =
    FutureProvider.family<List<Contribution>, String>((ref, type) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getContributionsByType(type);
});

/// Provider para contribuição por ID
final contributionByIdProvider =
    FutureProvider.family<Contribution?, String>((ref, id) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getContributionById(id);
});

/// Provider para total de contribuições
final totalContributionsProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getTotalContributions();
});

/// Provider para total de contribuições por tipo
final totalContributionsByTypeProvider =
    FutureProvider.family<double, String>((ref, type) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getTotalContributionsByType(type);
});

// =====================================================
// METAS FINANCEIRAS
// =====================================================

/// Provider para todas as metas
final allGoalsProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getAllGoals();
});

/// Provider para metas ativas
final activeGoalsProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getActiveGoals();
});

/// Provider para meta por ID
final goalByIdProvider =
    FutureProvider.family<FinancialGoal?, String>((ref, id) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getGoalById(id);
});

// =====================================================
// DESPESAS
// =====================================================

/// Provider para todas as despesas
final allExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getAllExpenses();
});

/// Provider para despesas por categoria
final expensesByCategoryProvider =
    FutureProvider.family<List<Expense>, String>((ref, category) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getExpensesByCategory(category);
});

/// Provider para total de despesas
final totalExpensesProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  return repository.getTotalExpenses();
});

// =====================================================
// ESTATÍSTICAS
// =====================================================

/// Provider para saldo (receitas - despesas)
final balanceProvider = FutureProvider<double>((ref) async {
  final totalContributions = await ref.watch(totalContributionsProvider.future);
  final totalExpenses = await ref.watch(totalExpensesProvider.future);
  return totalContributions - totalExpenses;
});

