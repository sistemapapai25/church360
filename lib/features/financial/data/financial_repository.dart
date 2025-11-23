import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/contribution.dart';

/// Repositório para gerenciar dados financeiros
class FinancialRepository {
  final SupabaseClient _supabase;

  FinancialRepository(this._supabase);

  // =====================================================
  // CONTRIBUIÇÕES
  // =====================================================

  /// Buscar todas as contribuições
  Future<List<Contribution>> getAllContributions() async {
    final response = await _supabase
        .from('contribution')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Contribution.fromJson(json))
        .toList();
  }

  /// Buscar contribuições por membro
  Future<List<Contribution>> getContributionsByMember(String memberId) async {
    final response = await _supabase
        .from('contribution')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .eq('user_id', memberId)
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Contribution.fromJson(json))
        .toList();
  }

  /// Buscar contribuições por tipo
  Future<List<Contribution>> getContributionsByType(String type) async {
    final response = await _supabase
        .from('contribution')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .eq('type', type)
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Contribution.fromJson(json))
        .toList();
  }

  /// Buscar contribuições por período
  Future<List<Contribution>> getContributionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('contribution')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0])
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Contribution.fromJson(json))
        .toList();
  }

  /// Buscar contribuição por ID
  Future<Contribution?> getContributionById(String id) async {
    final response = await _supabase
        .from('contribution')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Contribution.fromJson(response);
  }

  /// Criar contribuição
  Future<Contribution> createContribution(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('contribution')
        .insert(data)
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .single();

    return Contribution.fromJson(response);
  }

  /// Atualizar contribuição
  Future<Contribution> updateContribution(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('contribution')
        .update(data)
        .eq('id', id)
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .single();

    return Contribution.fromJson(response);
  }

  /// Deletar contribuição
  Future<void> deleteContribution(String id) async {
    await _supabase.from('contribution').delete().eq('id', id);
  }

  /// Calcular total de contribuições
  Future<double> getTotalContributions() async {
    final response = await _supabase
        .from('contribution')
        .select('amount');

    double total = 0;
    for (final item in response as List) {
      total += (item['amount'] as num).toDouble();
    }
    return total;
  }

  /// Calcular total de contribuições por tipo
  Future<double> getTotalContributionsByType(String type) async {
    final response = await _supabase
        .from('contribution')
        .select('amount')
        .eq('type', type);

    double total = 0;
    for (final item in response as List) {
      total += (item['amount'] as num).toDouble();
    }
    return total;
  }

  /// Calcular total de contribuições por período
  Future<double> getTotalContributionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('contribution')
        .select('amount')
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    double total = 0;
    for (final item in response as List) {
      total += (item['amount'] as num).toDouble();
    }
    return total;
  }

  // =====================================================
  // METAS FINANCEIRAS
  // =====================================================

  /// Buscar todas as metas
  Future<List<FinancialGoal>> getAllGoals() async {
    final response = await _supabase
        .from('financial_goal')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => FinancialGoal.fromJson(json))
        .toList();
  }

  /// Buscar metas ativas
  Future<List<FinancialGoal>> getActiveGoals() async {
    final response = await _supabase
        .from('financial_goal')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => FinancialGoal.fromJson(json))
        .toList();
  }

  /// Buscar meta por ID
  Future<FinancialGoal?> getGoalById(String id) async {
    final response = await _supabase
        .from('financial_goal')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return FinancialGoal.fromJson(response);
  }

  /// Criar meta
  Future<FinancialGoal> createGoal(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('financial_goal')
        .insert(data)
        .select()
        .single();

    return FinancialGoal.fromJson(response);
  }

  /// Atualizar meta
  Future<FinancialGoal> updateGoal(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('financial_goal')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return FinancialGoal.fromJson(response);
  }

  /// Deletar meta
  Future<void> deleteGoal(String id) async {
    await _supabase.from('financial_goal').delete().eq('id', id);
  }

  // =====================================================
  // DESPESAS
  // =====================================================

  /// Buscar todas as despesas
  Future<List<Expense>> getAllExpenses() async {
    final response = await _supabase
        .from('expense')
        .select()
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Expense.fromJson(json))
        .toList();
  }

  /// Buscar despesas por categoria
  Future<List<Expense>> getExpensesByCategory(String category) async {
    final response = await _supabase
        .from('expense')
        .select()
        .eq('category', category)
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Expense.fromJson(json))
        .toList();
  }

  /// Buscar despesas por período
  Future<List<Expense>> getExpensesByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('expense')
        .select()
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0])
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Expense.fromJson(json))
        .toList();
  }

  /// Criar despesa
  Future<Expense> createExpense(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('expense')
        .insert(data)
        .select()
        .single();

    return Expense.fromJson(response);
  }

  /// Atualizar despesa
  Future<Expense> updateExpense(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('expense')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return Expense.fromJson(response);
  }

  /// Deletar despesa
  Future<void> deleteExpense(String id) async {
    await _supabase.from('expense').delete().eq('id', id);
  }

  /// Calcular total de despesas
  Future<double> getTotalExpenses() async {
    final response = await _supabase
        .from('expense')
        .select('amount');

    double total = 0;
    for (final item in response as List) {
      total += (item['amount'] as num).toDouble();
    }
    return total;
  }

  /// Calcular total de despesas por período
  Future<double> getTotalExpensesByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('expense')
        .select('amount')
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    double total = 0;
    for (final item in response as List) {
      total += (item['amount'] as num).toDouble();
    }
    return total;
  }
}

