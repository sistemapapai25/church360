// =====================================================
// CHURCH 360 - FINANCIAL REPOSITORY: CONTAS FINANCEIRAS
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/conta_financeira.dart';
import '../domain/models/dashboard_data.dart';

/// Repository de Contas Financeiras
/// Responsável por toda comunicação com a tabela 'contas_financeiras' no Supabase
class ContasRepository {
  final SupabaseClient _supabase;

  ContasRepository(this._supabase);

  /// Buscar todas as contas
  Future<List<ContaFinanceira>> getAllContas() async {
    try {
      // Preferir view (saldo_atual calculado). Se ainda não existir no ambiente,
      // cair no fallback para a tabela base.
      dynamic response;
      try {
        response = await _supabase
            .from('vw_contas_financeiras_saldo')
            .select()
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .order('nome', ascending: true);
      } catch (e) {
        response = await _supabase
            .from('contas_financeiras')
            .select()
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .order('nome', ascending: true);
      }

      return (response as List).map((json) => ContaFinanceira.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar conta por ID
  Future<ContaFinanceira?> getContaById(String id) async {
    try {
      dynamic response;
      try {
        response = await _supabase
            .from('vw_contas_financeiras_saldo')
            .select()
            .eq('id', id)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .maybeSingle();
      } catch (e) {
        response = await _supabase
            .from('contas_financeiras')
            .select()
            .eq('id', id)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .maybeSingle();
      }

      if (response == null) return null;
      return ContaFinanceira.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar nova conta
  Future<ContaFinanceira> createConta(
    ContaFinanceira conta, {
    bool returnCreatedRow = true,
  }) async {
    try {
      final data = conta.toJson();
      data['tenant_id'] = SupabaseConstants.currentTenantId;
      data['created_by'] = _supabase.auth.currentUser?.id;

      if (!returnCreatedRow) {
        await _supabase.from('contas_financeiras').insert(data);
        return conta;
      }

      final response = await _supabase
          .from('contas_financeiras')
          .insert(data)
          .select()
          .single();

      return ContaFinanceira.fromJson(response);
    } catch (e) {
      if (e is PostgrestException && (e.code ?? '').trim() == '23505') {
        final existing = await _supabase
            .from('contas_financeiras')
            .select()
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .ilike('nome', conta.nome)
            .maybeSingle();
        if (existing != null) return ContaFinanceira.fromJson(existing);
      }
      rethrow;
    }
  }

  /// Atualizar conta
  Future<ContaFinanceira> updateConta(ContaFinanceira conta) async {
    try {
      final data = conta.toJson();

      final response = await _supabase
          .from('contas_financeiras')
          .update(data)
          .eq('id', conta.id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return ContaFinanceira.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar conta
  Future<void> deleteConta(String id) async {
    try {
      await _supabase
          .from('contas_financeiras')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar dados do dashboard
  Future<DashboardData> getDashboardData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final hoje = DateTime.now();
      final inicio = startDate ?? DateTime(hoje.year, hoje.month, 1);
      final fim = endDate ?? DateTime(hoje.year, hoje.month + 1, 0);
      final hojeDate = DateTime(hoje.year, hoje.month, hoje.day);

      // Buscar totais de receitas e despesas
      final lancamentos = await _supabase
          .from('lancamentos')
          .select('tipo, valor, valor_pago, status, vencimento, categoria_id, categoria:categories(name)')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .gte('vencimento', inicio.toIso8601String().split('T')[0])
          .lte('vencimento', fim.toIso8601String().split('T')[0])
          .isFilter('deleted_at', null);

      double receitasPrevistas = 0;
      double receitasRecebidas = 0;
      double despesasPrevistas = 0;
      double despesasPagas = 0;
      int lancamentosEmAberto = 0;
      int lancamentosVencidos = 0;
      final receitasPorCat = <String, ReceitaPorCategoria>{};
      final despesasPorCat = <String, DespesaPorCategoria>{};

      for (final lanc in lancamentos) {
        final tipo = lanc['tipo'] as String;
        final valor = (lanc['valor'] as num).toDouble();
        final status = lanc['status'] as String;
        final vencimento = DateTime.parse(lanc['vencimento'] as String);
        final categoriaId = lanc['categoria_id'] as String;
        final categoriaNome = lanc['categoria']?['name'] as String? ?? 'Sem categoria';

        final isCancelado = status == 'CANCELADO';
        final isPago = status == 'PAGO';

        // Previsto: tudo exceto cancelado
        if (!isCancelado) {
          if (tipo == 'RECEITA') {
            receitasPrevistas += valor;
          } else {
            despesasPrevistas += valor;
          }
        }

        // Realizado: apenas pagos
        if (isPago) {
          final valorReal = (lanc['valor_pago'] as num?)?.toDouble() ?? valor;
          if (tipo == 'RECEITA') {
            receitasRecebidas += valorReal;
          } else {
            despesasPagas += valorReal;
          }
        }

        // Resumo por categoria: usar previsto (não cancelado)
        if (!isCancelado) {
          if (tipo == 'RECEITA') {
            final key = categoriaId;
            if (receitasPorCat.containsKey(key)) {
              final atual = receitasPorCat[key]!;
              receitasPorCat[key] = ReceitaPorCategoria(
                categoriaId: categoriaId,
                categoriaNome: categoriaNome,
                total: atual.total + valor,
              );
            } else {
              receitasPorCat[key] = ReceitaPorCategoria(
                categoriaId: categoriaId,
                categoriaNome: categoriaNome,
                total: valor,
              );
            }
          } else {
            final key = categoriaId;
            if (despesasPorCat.containsKey(key)) {
              final atual = despesasPorCat[key]!;
              despesasPorCat[key] = DespesaPorCategoria(
                categoriaId: categoriaId,
                categoriaNome: categoriaNome,
                total: atual.total + valor,
              );
            } else {
              despesasPorCat[key] = DespesaPorCategoria(
                categoriaId: categoriaId,
                categoriaNome: categoriaNome,
                total: valor,
              );
            }
          }
        }

        if (status == 'EM_ABERTO') {
          lancamentosEmAberto++;
          if (vencimento.isBefore(hojeDate)) {
            lancamentosVencidos++;
          }
        }
      }

      // Buscar saldos por conta
      final contas = await getAllContas();
      final saldosPorConta = <SaldoPorConta>[];
      for (final conta in contas) {
        saldosPorConta.add(SaldoPorConta(
          contaId: conta.id,
          contaNome: conta.nome,
          saldo: conta.saldoAtual ?? conta.saldoInicial,
        ));
      }

      final saldoPrevisto = receitasPrevistas - despesasPrevistas;
      final saldoRealizado = receitasRecebidas - despesasPagas;

      return DashboardData(
        receitasPrevistas: receitasPrevistas,
        receitasRecebidas: receitasRecebidas,
        despesasPrevistas: despesasPrevistas,
        despesasPagas: despesasPagas,
        saldoPrevisto: saldoPrevisto,
        saldoRealizado: saldoRealizado,
        totalReceitas: receitasRecebidas,
        totalDespesas: despesasPagas,
        saldo: saldoRealizado,
        lancamentosEmAberto: lancamentosEmAberto,
        lancamentosVencidos: lancamentosVencidos,
        receitasPorCategoria: receitasPorCat.values.toList(),
        despesasPorCategoria: despesasPorCat.values.toList(),
        saldosPorConta: saldosPorConta,
      );
    } catch (e) {
      rethrow;
    }
  }
}
