import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../financeiro/domain/models/lancamento.dart';
import '../domain/ministry_finance.dart';

/// Erro de caixa do ministério já traduzido para a tela.
///
/// O banco recusa por `42501` em dois pontos diferentes — a policy de
/// escrita e o trigger que guarda `approval_status` —, e o código cru não
/// diz nada a quem está usando o app.
class MinistryFinanceException implements Exception {
  final String message;

  const MinistryFinanceException(this.message);

  @override
  String toString() => message;
}

/// Acesso ao caixa de um ministério: a fatia de `lancamentos` com
/// `ministry_id` preenchido.
///
/// Os três repositórios antigos de `lancamentos` continuam existindo e
/// cuidando do livro-caixa da igreja; este é o único que enxerga o recorte
/// do departamento, e é o único que manda `ministry_id`.
class MinistryFinanceRepository {
  final SupabaseClient _supabase;

  MinistryFinanceRepository(this._supabase);

  /// Lançamentos do ministério, mais recentes primeiro.
  ///
  /// **Sem embed de categoria e beneficiário, de propósito.** As tabelas
  /// `categories` e `beneficiaries` são fechadas por `can_manage_financial`
  /// (`20260118000002`), e o PostgREST devolve embed proibido como NULL, sem
  /// erro: quem cuida do ministério veria a lista inteira com o nome da
  /// rubrica em branco e nada indicaria o motivo. Os nomes vêm do catálogo,
  /// que passa pela RPC.
  Future<List<Lancamento>> getLancamentos(String ministryId) async {
    try {
      final response = await _supabase
          .from('lancamentos')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .isFilter('deleted_at', null)
          .order('vencimento', ascending: false);

      return (response as List)
          .map((json) => Lancamento.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Catálogo de apoio (categorias e beneficiários) pela RPC
  /// `ministry_finance_catalog`.
  Future<MinistryFinanceCatalog> getCatalog(String ministryId) async {
    try {
      final response = await _supabase.rpc(
        'ministry_finance_catalog',
        params: {'p_ministry_id': ministryId},
      );

      final categorias = <MinistryFinanceOption>[];
      final beneficiarios = <MinistryFinanceOption>[];

      for (final row in (response as List? ?? const [])) {
        final map = row as Map<String, dynamic>;
        final option = MinistryFinanceOption(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? '',
          tipo: map['tipo'] as String?,
        );
        if (map['kind'] == 'categoria') {
          categorias.add(option);
        } else {
          beneficiarios.add(option);
        }
      }

      return MinistryFinanceCatalog(
        categorias: categorias,
        beneficiarios: beneficiarios,
      );
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Cria um lançamento do departamento.
  ///
  /// `approval_status` **não** vai no payload: o trigger
  /// `lancamentos_set_approval` decide (entrada nasce aprovada, saída nasce
  /// pendente) e sobrescreve o que o cliente mandar. Mandar a coluna aqui
  /// não adiantaria e esconderia a régua real dentro do app.
  ///
  /// `beneficiarioId` é obrigatório em saída por constraint do banco
  /// (`lancamentos_beneficiario_required`), não por escolha desta tela.
  Future<Lancamento> createLancamento({
    required String ministryId,
    required TipoLancamento tipo,
    required String categoriaId,
    required double valor,
    required DateTime vencimento,
    String? beneficiarioId,
    String? descricao,
    bool efetivado = false,
  }) async {
    final data = <String, dynamic>{
      'tenant_id': SupabaseConstants.currentTenantId,
      'created_by': _supabase.auth.currentUser?.id,
      'ministry_id': ministryId,
      'tipo': tipo.value,
      'categoria_id': categoriaId,
      'beneficiario_id': beneficiarioId,
      'descricao': descricao,
      'valor': valor,
      'vencimento': vencimento.toIso8601String().split('T')[0],
      // `lancamentos_pagamento_consistente` exige os três campos juntos:
      // PAGO com data e valor, ou nenhum dos três.
      'status': efetivado ? 'PAGO' : 'EM_ABERTO',
      if (efetivado) ...{
        'data_pagamento': DateTime.now().toIso8601String().split('T')[0],
        'valor_pago': valor,
      },
    };

    try {
      final response = await _supabase
          .from('lancamentos')
          .insert(data)
          .select()
          .single();
      return Lancamento.fromJson(response);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Aprova ou rejeita uma saída do departamento.
  ///
  /// Só `approval_status` vai no payload: `approved_by` e `approved_at` são
  /// carimbados pelo trigger `lancamentos_guard_approval`, e mandá-los do
  /// app seria o cliente se eleger aprovador.
  Future<Lancamento> setApproval({
    required String id,
    required bool aprovado,
  }) async {
    try {
      final response = await _supabase
          .from('lancamentos')
          .update({
            'approval_status': aprovado ? 'APROVADO' : 'REJEITADO',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();
      return Lancamento.fromJson(response);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Pede edição de um lançamento do departamento.
  ///
  /// **Não é UPDATE.** Vai pela RPC `request_lancamento_change` porque policy
  /// autoriza a LINHA e não a COLUNA: com UPDATE direto o app escolheria o
  /// que escrever em `change_requested_by` e se declararia autor de um
  /// pedido. O trigger `lancamentos_guard_change_request` recusa (42501)
  /// qualquer escrita nessas colunas fora das duas RPCs.
  ///
  /// Quem tem `ministry_finance.approve` (ou cuida do financeiro da igreja)
  /// não abre pedido: o banco aplica na hora. Quem é do departamento abre o
  /// pedido e o lançamento **continua como está** até alguém decidir.
  ///
  /// `tipo` não entra: trocar receita por despesa numa linha aprovada seria
  /// uma saída aprovada que nunca passou pela fila. O banco recusa a chave
  /// com `22023`.
  Future<Lancamento> requestEdit({
    required String id,
    String? categoriaId,
    String? beneficiarioId,
    double? valor,
    DateTime? vencimento,
    String? descricao,
    String? motivo,
  }) async {
    final payload = <String, dynamic>{
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (beneficiarioId != null) 'beneficiario_id': beneficiarioId,
      if (valor != null) 'valor': valor,
      if (vencimento != null)
        'vencimento': vencimento.toIso8601String().split('T')[0],
      if (descricao != null) 'descricao': descricao,
    };

    if (payload.isEmpty) {
      throw const MinistryFinanceException(
        'Nada mudou neste lançamento, então não há o que pedir.',
      );
    }

    return _chamarRpc('request_lancamento_change', {
      'p_lancamento_id': id,
      'p_action': 'EDICAO',
      'p_payload': payload,
      'p_reason': motivo,
    });
  }

  /// Pede a exclusão de um lançamento do departamento.
  ///
  /// Quem pode aprovar apaga na hora (soft delete); quem não pode deixa o
  /// pedido em aberto, e o lançamento **continua no saldo** até a decisão —
  /// de propósito: pedido de exclusão não pode mexer no resultado antes da
  /// hora.
  Future<Lancamento> requestDelete({
    required String id,
    String? motivo,
  }) async {
    return _chamarRpc('request_lancamento_change', {
      'p_lancamento_id': id,
      'p_action': 'EXCLUSAO',
      'p_payload': null,
      'p_reason': motivo,
    });
  }

  /// Decide um pedido de edição ou exclusão.
  ///
  /// Aprovar uma edição aplica os valores propostos; aprovar uma exclusão
  /// carimba `deleted_at`; recusar só limpa o pedido, porque o lançamento
  /// nunca chegou a mudar.
  Future<Lancamento> resolveChange({
    required String id,
    required bool aprovado,
  }) async {
    return _chamarRpc('resolve_lancamento_change', {
      'p_lancamento_id': id,
      'p_aprovar': aprovado,
    });
  }

  /// As duas RPCs devolvem a linha inteira de `lancamentos`.
  Future<Lancamento> _chamarRpc(
    String nome,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _supabase.rpc(nome, params: params);
      if (response == null) {
        throw const MinistryFinanceException(
          'O banco não devolveu o lançamento depois da operação.',
        );
      }
      final json = response is List
          ? response.first as Map<String, dynamic>
          : response as Map<String, dynamic>;
      return Lancamento.fromJson(json);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Apaga um lançamento do departamento (soft delete).
  ///
  /// É UPDATE, e não DELETE: a migration de 21/09 não criou policy de DELETE
  /// de propósito — este financeiro apaga por `deleted_at`.
  Future<void> deleteLancamento(String id) async {
    try {
      await _supabase
          .from('lancamentos')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Traduz a recusa do banco para uma frase que diz o que fazer.
  ///
  /// `42501` chega de dois lugares diferentes — a policy de escrita e o
  /// trigger da coluna de aprovação — e nos dois casos o código cru na tela
  /// só assusta.
  MinistryFinanceException _traduzir(PostgrestException e) {
    if (e.code == '42501' ||
        e.message.toLowerCase().contains('row-level security')) {
      return const MinistryFinanceException(
        'Você não tem permissão para esta ação no caixa do ministério. '
        'É preciso ter a permissão correspondente em um cargo e estar '
        'vinculado a este ministério.',
      );
    }
    if (e.code == '23505') {
      return const MinistryFinanceException(
        'Este lançamento já tem um pedido esperando decisão. '
        'É preciso resolver o pedido atual antes de abrir outro.',
      );
    }
    if (e.code == '22023') {
      return const MinistryFinanceException(
        'Esta mudança não pode ser pedida: o tipo do lançamento (entrada ou '
        'saída) não muda por edição. Exclua e lance de novo.',
      );
    }
    if (e.code == 'P0002') {
      return const MinistryFinanceException(
        'Este lançamento não existe mais, ou o pedido já foi decidido por '
        'outra pessoa. Atualize a lista.',
      );
    }
    if (e.code == '23514') {
      return const MinistryFinanceException(
        'O lançamento não passou nas regras do financeiro: saída precisa de '
        'beneficiário e o valor tem de ser maior que zero.',
      );
    }
    return MinistryFinanceException(e.message);
  }
}
