import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/contribution.dart';

/// Repositório para gerenciar dados financeiros
class FinancialRepository {
  final SupabaseClient _supabase;

  FinancialRepository(this._supabase);

  static const String _lancamentosSelect = '''
          id,
          tipo,
          descricao,
          valor,
          forma_pagamento,
          vencimento,
          status,
          data_pagamento,
          valor_pago,
          observacoes,
          created_at,
          categoria:categoria_id (
            id,
            name,
            tipo
          ),
          beneficiario:beneficiario_id (
            id,
            name,
            documento
          )
        ''';

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  DateTime _parseDateValue(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  String _formatDateValue(dynamic value) {
    final date = _parseDateValue(value);
    return date.toIso8601String().split('T')[0];
  }

  double _resolveLancamentoValor(Map<String, dynamic> json) {
    return _parseAmount(json['valor_pago'] ?? json['valor']);
  }

  DateTime _resolveLancamentoDate(Map<String, dynamic> json) {
    final raw = json['data_pagamento'] ?? json['vencimento'] ?? json['created_at'];
    return _parseDateValue(raw);
  }

  ContributionType _mapCategoryNameToContributionType(String? name) {
    final key = (name ?? '').toLowerCase();
    if (key.contains('dizim')) return ContributionType.tithe;
    if (key.contains('ofert')) return ContributionType.offering;
    if (key.contains('miss')) return ContributionType.missions;
    if (key.contains('constr')) return ContributionType.building;
    if (key.contains('espec')) return ContributionType.special;
    return ContributionType.other;
  }

  String _mapContributionTypeToCategoryName(ContributionType type) {
    switch (type) {
      case ContributionType.tithe:
        return 'Dizimos';
      case ContributionType.offering:
        return 'Ofertas';
      case ContributionType.missions:
        return 'Missoes';
      case ContributionType.building:
        return 'Construcao';
      case ContributionType.special:
        return 'Especial';
      case ContributionType.other:
        return 'Outros';
    }
  }

  String _mapContributionTypeValueToCategoryName(String? value) {
    if (value == null || value.isEmpty) {
      return _mapContributionTypeToCategoryName(ContributionType.other);
    }
    return _mapContributionTypeToCategoryName(
      ContributionType.fromValue(value),
    );
  }

  String _mapPaymentMethodToFormaPagamento(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.pix:
        return 'PIX';
      case PaymentMethod.cash:
        return 'DINHEIRO';
      case PaymentMethod.debit:
      case PaymentMethod.credit:
        return 'CARTAO';
      case PaymentMethod.transfer:
        return 'TRANSFERENCIA';
      case PaymentMethod.check:
        return 'BOLETO';
      case PaymentMethod.other:
        return 'OUTRO';
    }
  }

  PaymentMethod _mapFormaPagamentoToPaymentMethod(String? value) {
    if (value == null) return PaymentMethod.other;
    switch (value) {
      case 'PIX':
        return PaymentMethod.pix;
      case 'DINHEIRO':
        return PaymentMethod.cash;
      case 'CARTAO':
        return PaymentMethod.credit;
      case 'TRANSFERENCIA':
        return PaymentMethod.transfer;
      case 'BOLETO':
        return PaymentMethod.check;
      case 'OUTRO':
        return PaymentMethod.other;
      default:
        return PaymentMethod.fromValue(value);
    }
  }

  Contribution _mapLancamentoToContribution(Map<String, dynamic> json) {
    final category = json['categoria'] as Map<String, dynamic>?;
    final beneficiary = json['beneficiario'] as Map<String, dynamic>?;
    final memberId = (beneficiary?['documento'] as String?)?.trim();
    return Contribution(
      id: json['id'] as String,
      memberId: memberId?.isNotEmpty == true ? memberId : null,
      memberName: (beneficiary?['name'] as String?)?.trim(),
      type: _mapCategoryNameToContributionType(category?['name'] as String?),
      amount: _resolveLancamentoValor(json),
      paymentMethod: _mapFormaPagamentoToPaymentMethod(
        json['forma_pagamento'] as String?,
      ),
      date: _resolveLancamentoDate(json),
      description: json['descricao'] as String?,
      notes: json['observacoes'] as String?,
      createdAt: _parseDateValue(json['created_at']),
    );
  }

  Expense _mapLancamentoToExpense(Map<String, dynamic> json) {
    final category = json['categoria'] as Map<String, dynamic>?;
    final categoryName = (category?['name'] as String?)?.trim();
    return Expense(
      id: json['id'] as String,
      category: categoryName?.isNotEmpty == true ? categoryName! : 'Sem categoria',
      amount: _resolveLancamentoValor(json),
      paymentMethod: _mapFormaPagamentoToPaymentMethod(
        json['forma_pagamento'] as String?,
      ),
      date: _resolveLancamentoDate(json),
      description: (json['descricao'] as String?)?.trim().isNotEmpty == true
          ? json['descricao'] as String
          : (categoryName?.isNotEmpty == true ? categoryName! : 'Despesa'),
      notes: json['observacoes'] as String?,
      createdAt: _parseDateValue(json['created_at']),
    );
  }

  Future<String> _ensureCategoryId(String name, {required String tipo}) async {
    final trimmed = name.trim();
    final effectiveName = trimmed.isEmpty ? 'Sem categoria' : trimmed;

    final existing = await _supabase
        .from('categories')
        .select('id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('name', effectiveName)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final created = await _supabase.from('categories').insert({
      'name': effectiveName,
      'tipo': tipo,
      'tenant_id': SupabaseConstants.currentTenantId,
    }).select('id').single();

    return created['id'] as String;
  }

  Future<String?> _findBeneficiaryIdForMember(String memberId) async {
    final existing = await _supabase
        .from('beneficiaries')
        .select('id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('documento', memberId)
        .maybeSingle();
    return existing?['id'] as String?;
  }

  Future<String?> _ensureBeneficiaryForMember(String? memberId) async {
    if (memberId == null || memberId.trim().isEmpty) return null;
    final existingId = await _findBeneficiaryIdForMember(memberId);
    if (existingId != null) return existingId;

    String? name;
    try {
      final account = await _supabase
          .from('user_account')
          .select('first_name, last_name, nickname')
          .eq('id', memberId)
          .maybeSingle();
      if (account != null) {
        final first = (account['first_name'] ?? '').toString().trim();
        final last = (account['last_name'] ?? '').toString().trim();
        final nick = (account['nickname'] ?? '').toString().trim();
        name = [first, last].where((part) => part.isNotEmpty).join(' ');
        if (name.isEmpty) name = nick;
      }
    } catch (_) {}

    name ??= 'Membro nao informado';
    var effectiveName = name.trim().isEmpty ? 'Membro nao informado' : name.trim();

    final existingByName = await _supabase
        .from('beneficiaries')
        .select('id, documento')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('name', effectiveName)
        .maybeSingle();

    if (existingByName != null) {
      final existingDoc = (existingByName['documento'] ?? '').toString().trim();
      if (existingDoc.isEmpty || existingDoc == memberId) {
        if (existingDoc.isEmpty) {
          await _supabase
              .from('beneficiaries')
              .update({'documento': memberId})
              .eq('id', existingByName['id'] as String);
        }
        return existingByName['id'] as String;
      }
      final compact = memberId.replaceAll('-', '');
      final suffix = compact.length > 6 ? compact.substring(0, 6) : compact;
      effectiveName = '$effectiveName ($suffix)';
    }

    final created = await _supabase.from('beneficiaries').insert({
      'name': effectiveName,
      'documento': memberId,
      'tenant_id': SupabaseConstants.currentTenantId,
    }).select('id').single();

    return created['id'] as String;
  }

  Future<String> _ensureDefaultBeneficiaryId() async {
    const name = 'Beneficiario nao informado';
    final existing = await _supabase
        .from('beneficiaries')
        .select('id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('name', name)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }

    final created = await _supabase.from('beneficiaries').insert({
      'name': name,
      'documento': 'DEFAULT',
      'tenant_id': SupabaseConstants.currentTenantId,
    }).select('id').single();

    return created['id'] as String;
  }

  // =====================================================
  // CONTRIBUIÇÕES
  // =====================================================

  /// Buscar todas as contribuições
  Future<List<Contribution>> getAllContributions() async {
    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'RECEITA')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToContribution(json))
        .toList();
  }

  /// Buscar contribuições por membro
  Future<List<Contribution>> getContributionsByMember(String memberId) async {
    final beneficiaryId = await _findBeneficiaryIdForMember(memberId);
    if (beneficiaryId == null) return [];

    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'RECEITA')
        .eq('beneficiario_id', beneficiaryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToContribution(json))
        .toList();
  }

  /// Buscar contribuições por tipo
  Future<List<Contribution>> getContributionsByType(String type) async {
    final categoryId = await _ensureCategoryId(
      _mapContributionTypeValueToCategoryName(type),
      tipo: 'RECEITA',
    );

    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'RECEITA')
        .eq('categoria_id', categoryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToContribution(json))
        .toList();
  }

  /// Buscar contribuições por período
  Future<List<Contribution>> getContributionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'RECEITA')
        .gte('vencimento', startDate.toIso8601String().split('T')[0])
        .lte('vencimento', endDate.toIso8601String().split('T')[0])
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToContribution(json))
        .toList();
  }

  /// Buscar contribuição por ID
  Future<Contribution?> getContributionById(String id) async {
    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'RECEITA')
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return _mapLancamentoToContribution(response);
  }

  /// Criar contribuição
  Future<Contribution> createContribution(Map<String, dynamic> data) async {
    final amount = _parseAmount(data['amount']);
    final date = _formatDateValue(data['date']);
    final categoryId = await _ensureCategoryId(
      _mapContributionTypeValueToCategoryName(data['type'] as String?),
      tipo: 'RECEITA',
    );
    final beneficiaryId = await _ensureBeneficiaryForMember(
      data['user_id'] as String?,
    );

    final payload = <String, dynamic>{
      'tipo': 'RECEITA',
      'categoria_id': categoryId,
      'beneficiario_id': beneficiaryId,
      'descricao': data['description'],
      'valor': amount,
      'forma_pagamento': _mapPaymentMethodToFormaPagamento(
        PaymentMethod.fromValue(data['payment_method'] as String? ?? 'other'),
      ),
      'vencimento': date,
      'status': 'PAGO',
      'data_pagamento': date,
      'valor_pago': amount,
      'observacoes': data['notes'],
      'tenant_id': data['tenant_id'] ?? SupabaseConstants.currentTenantId,
    };

    final response = await _supabase
        .from('lancamentos')
        .insert(payload)
        .select(_lancamentosSelect)
        .single();

    return _mapLancamentoToContribution(response);
  }

  /// Atualizar contribuição
  Future<Contribution> updateContribution(
    String id,
    Map<String, dynamic> data,
  ) async {
    final amount = _parseAmount(data['amount']);
    final date = _formatDateValue(data['date']);
    final categoryId = await _ensureCategoryId(
      _mapContributionTypeValueToCategoryName(data['type'] as String?),
      tipo: 'RECEITA',
    );
    final beneficiaryId = await _ensureBeneficiaryForMember(
      data['user_id'] as String?,
    );

    final payload = <String, dynamic>{
      'tipo': 'RECEITA',
      'categoria_id': categoryId,
      'beneficiario_id': beneficiaryId,
      'descricao': data['description'],
      'valor': amount,
      'forma_pagamento': _mapPaymentMethodToFormaPagamento(
        PaymentMethod.fromValue(data['payment_method'] as String? ?? 'other'),
      ),
      'vencimento': date,
      'status': 'PAGO',
      'data_pagamento': date,
      'valor_pago': amount,
      'observacoes': data['notes'],
    };

    final response = await _supabase
        .from('lancamentos')
        .update(payload)
        .eq('id', id)
        .eq('tipo', 'RECEITA')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(_lancamentosSelect)
        .single();

    return _mapLancamentoToContribution(response);
  }

  /// Deletar contribuição
  Future<void> deleteContribution(String id) async {
    await _supabase
        .from('lancamentos')
        .delete()
        .eq('id', id)
        .eq('tipo', 'RECEITA')
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Calcular total de contribuições
  Future<double> getTotalContributions() async {
    final response = await _supabase
        .from('lancamentos')
        .select('valor, valor_pago')
        .eq('tipo', 'RECEITA')
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    double total = 0;
    for (final item in response as List) {
      total += _parseAmount(item['valor_pago'] ?? item['valor']);
    }
    return total;
  }

  /// Calcular total de contribuições por tipo
  Future<double> getTotalContributionsByType(String type) async {
    final categoryId = await _ensureCategoryId(
      _mapContributionTypeValueToCategoryName(type),
      tipo: 'RECEITA',
    );

    final response = await _supabase
        .from('lancamentos')
        .select('valor, valor_pago')
        .eq('tipo', 'RECEITA')
        .eq('categoria_id', categoryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    double total = 0;
    for (final item in response as List) {
      total += _parseAmount(item['valor_pago'] ?? item['valor']);
    }
    return total;
  }

  /// Calcular total de contribuições por período
  Future<double> getTotalContributionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('lancamentos')
        .select('valor, valor_pago')
        .eq('tipo', 'RECEITA')
        .gte('vencimento', startDate.toIso8601String().split('T')[0])
        .lte('vencimento', endDate.toIso8601String().split('T')[0])
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    double total = 0;
    for (final item in response as List) {
      total += _parseAmount(item['valor_pago'] ?? item['valor']);
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return FinancialGoal.fromJson(response);
  }

  /// Criar meta
  Future<FinancialGoal> createGoal(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['tenant_id'] = payload['tenant_id'] ?? SupabaseConstants.currentTenantId;
    final response = await _supabase
        .from('financial_goal')
        .insert(payload)
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return FinancialGoal.fromJson(response);
  }

  /// Deletar meta
  Future<void> deleteGoal(String id) async {
    await _supabase
        .from('financial_goal')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // DESPESAS
  // =====================================================

  /// Buscar todas as despesas
  Future<List<Expense>> getAllExpenses() async {
    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'DESPESA')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToExpense(json))
        .toList();
  }

  /// Buscar despesas por categoria
  Future<List<Expense>> getExpensesByCategory(String category) async {
    final categoryId = await _ensureCategoryId(category, tipo: 'DESPESA');

    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'DESPESA')
        .eq('categoria_id', categoryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToExpense(json))
        .toList();
  }

  /// Buscar despesas por período
  Future<List<Expense>> getExpensesByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('lancamentos')
        .select(_lancamentosSelect)
        .eq('tipo', 'DESPESA')
        .gte('vencimento', startDate.toIso8601String().split('T')[0])
        .lte('vencimento', endDate.toIso8601String().split('T')[0])
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('vencimento', ascending: false);

    return (response as List)
        .map((json) => _mapLancamentoToExpense(json))
        .toList();
  }

  /// Criar despesa
  Future<Expense> createExpense(Map<String, dynamic> data) async {
    final amount = _parseAmount(data['amount']);
    final date = _formatDateValue(data['date']);
    final categoryId = await _ensureCategoryId(
      (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Despesas gerais',
      tipo: 'DESPESA',
    );
    final beneficiaryId = await _ensureDefaultBeneficiaryId();

    final payload = <String, dynamic>{
      'tipo': 'DESPESA',
      'categoria_id': categoryId,
      'beneficiario_id': beneficiaryId,
      'descricao': data['description'],
      'valor': amount,
      'forma_pagamento': _mapPaymentMethodToFormaPagamento(
        PaymentMethod.fromValue(data['payment_method'] as String? ?? 'other'),
      ),
      'vencimento': date,
      'status': 'PAGO',
      'data_pagamento': date,
      'valor_pago': amount,
      'observacoes': data['notes'],
      'tenant_id': data['tenant_id'] ?? SupabaseConstants.currentTenantId,
    };

    final response = await _supabase
        .from('lancamentos')
        .insert(payload)
        .select(_lancamentosSelect)
        .single();

    return _mapLancamentoToExpense(response);
  }

  /// Atualizar despesa
  Future<Expense> updateExpense(
    String id,
    Map<String, dynamic> data,
  ) async {
    final amount = _parseAmount(data['amount']);
    final date = _formatDateValue(data['date']);
    final categoryId = await _ensureCategoryId(
      (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Despesas gerais',
      tipo: 'DESPESA',
    );
    final beneficiaryId = await _ensureDefaultBeneficiaryId();

    final payload = <String, dynamic>{
      'tipo': 'DESPESA',
      'categoria_id': categoryId,
      'beneficiario_id': beneficiaryId,
      'descricao': data['description'],
      'valor': amount,
      'forma_pagamento': _mapPaymentMethodToFormaPagamento(
        PaymentMethod.fromValue(data['payment_method'] as String? ?? 'other'),
      ),
      'vencimento': date,
      'status': 'PAGO',
      'data_pagamento': date,
      'valor_pago': amount,
      'observacoes': data['notes'],
    };

    final response = await _supabase
        .from('lancamentos')
        .update(payload)
        .eq('id', id)
        .eq('tipo', 'DESPESA')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select(_lancamentosSelect)
        .single();

    return _mapLancamentoToExpense(response);
  }

  /// Deletar despesa
  Future<void> deleteExpense(String id) async {
    await _supabase
        .from('lancamentos')
        .delete()
        .eq('id', id)
        .eq('tipo', 'DESPESA')
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Calcular total de despesas
  Future<double> getTotalExpenses() async {
    final response = await _supabase
        .from('lancamentos')
        .select('valor, valor_pago')
        .eq('tipo', 'DESPESA')
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    double total = 0;
    for (final item in response as List) {
      total += _parseAmount(item['valor_pago'] ?? item['valor']);
    }
    return total;
  }

  /// Calcular total de despesas por período
  Future<double> getTotalExpensesByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('lancamentos')
        .select('valor, valor_pago')
        .eq('tipo', 'DESPESA')
        .gte('vencimento', startDate.toIso8601String().split('T')[0])
        .lte('vencimento', endDate.toIso8601String().split('T')[0])
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    double total = 0;
    for (final item in response as List) {
      total += _parseAmount(item['valor_pago'] ?? item['valor']);
    }
    return total;
  }
}
