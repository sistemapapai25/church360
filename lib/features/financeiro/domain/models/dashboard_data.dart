// =====================================================
// CHURCH 360 - FINANCIAL MODELS: DASHBOARD DATA
// =====================================================

/// Model: Dados do Dashboard Financeiro
class DashboardData {
  // Previsão do mês (previsto vs realizado)
  final double receitasPrevistas;
  final double receitasRecebidas;
  final double despesasPrevistas;
  final double despesasPagas;
  final double saldoPrevisto;
  final double saldoRealizado;

  final double totalReceitas;
  final double totalDespesas;
  final double saldo;
  final int lancamentosEmAberto;
  final int lancamentosVencidos;
  final List<ReceitaPorCategoria> receitasPorCategoria;
  final List<DespesaPorCategoria> despesasPorCategoria;
  final List<SaldoPorConta> saldosPorConta;

  const DashboardData({
    required this.receitasPrevistas,
    required this.receitasRecebidas,
    required this.despesasPrevistas,
    required this.despesasPagas,
    required this.saldoPrevisto,
    required this.saldoRealizado,
    required this.totalReceitas,
    required this.totalDespesas,
    required this.saldo,
    required this.lancamentosEmAberto,
    required this.lancamentosVencidos,
    required this.receitasPorCategoria,
    required this.despesasPorCategoria,
    required this.saldosPorConta,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      receitasPrevistas: (json['receitas_previstas'] as num?)?.toDouble() ?? 0.0,
      receitasRecebidas: (json['receitas_recebidas'] as num?)?.toDouble() ?? 0.0,
      despesasPrevistas: (json['despesas_previstas'] as num?)?.toDouble() ?? 0.0,
      despesasPagas: (json['despesas_pagas'] as num?)?.toDouble() ?? 0.0,
      saldoPrevisto: (json['saldo_previsto'] as num?)?.toDouble() ?? 0.0,
      saldoRealizado: (json['saldo_realizado'] as num?)?.toDouble() ?? 0.0,
      totalReceitas: (json['total_receitas'] as num?)?.toDouble() ?? 0.0,
      totalDespesas: (json['total_despesas'] as num?)?.toDouble() ?? 0.0,
      saldo: (json['saldo'] as num?)?.toDouble() ?? 0.0,
      lancamentosEmAberto: json['lancamentos_em_aberto'] as int? ?? 0,
      lancamentosVencidos: json['lancamentos_vencidos'] as int? ?? 0,
      receitasPorCategoria: json['receitas_por_categoria'] != null
          ? (json['receitas_por_categoria'] as List)
              .map((e) => ReceitaPorCategoria.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      despesasPorCategoria: json['despesas_por_categoria'] != null
          ? (json['despesas_por_categoria'] as List)
              .map((e) => DespesaPorCategoria.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      saldosPorConta: json['saldos_por_conta'] != null
          ? (json['saldos_por_conta'] as List)
              .map((e) => SaldoPorConta.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receitas_previstas': receitasPrevistas,
      'receitas_recebidas': receitasRecebidas,
      'despesas_previstas': despesasPrevistas,
      'despesas_pagas': despesasPagas,
      'saldo_previsto': saldoPrevisto,
      'saldo_realizado': saldoRealizado,
      'total_receitas': totalReceitas,
      'total_despesas': totalDespesas,
      'saldo': saldo,
      'lancamentos_em_aberto': lancamentosEmAberto,
      'lancamentos_vencidos': lancamentosVencidos,
      'receitas_por_categoria': receitasPorCategoria.map((e) => e.toJson()).toList(),
      'despesas_por_categoria': despesasPorCategoria.map((e) => e.toJson()).toList(),
      'saldos_por_conta': saldosPorConta.map((e) => e.toJson()).toList(),
    };
  }

  // Propriedades computadas
  double get percentualDespesas {
    if (totalReceitas == 0) return 0;
    return (totalDespesas / totalReceitas) * 100;
  }

  double get variacaoPrevistoVsRealizado {
    if (saldoPrevisto == 0) return 0;
    return ((saldoRealizado - saldoPrevisto) / saldoPrevisto) * 100;
  }

  bool get temSaldoPositivo => saldo > 0;
  bool get temLancamentosVencidos => lancamentosVencidos > 0;
}

/// Model: Receita por Categoria
class ReceitaPorCategoria {
  final String categoriaId;
  final String categoriaNome;
  final double total;

  const ReceitaPorCategoria({
    required this.categoriaId,
    required this.categoriaNome,
    required this.total,
  });

  factory ReceitaPorCategoria.fromJson(Map<String, dynamic> json) {
    return ReceitaPorCategoria(
      categoriaId: json['categoria_id'] as String,
      categoriaNome: json['categoria_nome'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoria_id': categoriaId,
      'categoria_nome': categoriaNome,
      'total': total,
    };
  }
}

/// Model: Despesa por Categoria
class DespesaPorCategoria {
  final String categoriaId;
  final String categoriaNome;
  final double total;

  const DespesaPorCategoria({
    required this.categoriaId,
    required this.categoriaNome,
    required this.total,
  });

  factory DespesaPorCategoria.fromJson(Map<String, dynamic> json) {
    return DespesaPorCategoria(
      categoriaId: json['categoria_id'] as String,
      categoriaNome: json['categoria_nome'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoria_id': categoriaId,
      'categoria_nome': categoriaNome,
      'total': total,
    };
  }
}

/// Model: Saldo por Conta
class SaldoPorConta {
  final String contaId;
  final String contaNome;
  final double saldo;

  const SaldoPorConta({
    required this.contaId,
    required this.contaNome,
    required this.saldo,
  });

  factory SaldoPorConta.fromJson(Map<String, dynamic> json) {
    return SaldoPorConta(
      contaId: json['conta_id'] as String,
      contaNome: json['conta_nome'] as String,
      saldo: (json['saldo'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conta_id': contaId,
      'conta_nome': contaNome,
      'saldo': saldo,
    };
  }

  // Propriedades computadas
  bool get temSaldoPositivo => saldo > 0;
  bool get temSaldoNegativo => saldo < 0;
}
