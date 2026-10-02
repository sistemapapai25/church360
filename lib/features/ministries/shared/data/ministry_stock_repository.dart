import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/ministry_stock.dart';

/// Erro de estoque/auditoria já traduzido para a tela.
class MinistryStockException implements Exception {
  final String message;

  const MinistryStockException(this.message);

  @override
  String toString() => message;
}

/// Estoque do ministério e a auditoria (Caixa + Estoque).
///
/// O cliente só faz SELECT em `ministry_stock_item`; toda escrita passa
/// pelas RPCs da migration `20261001001800_ministry_stock`, que decidem
/// permissão, saldo e alerta. As capacidades vêm das mesmas funções que o
/// banco usa, para a tela nunca prometer o que a RPC recusa.
class MinistryStockRepository {
  final SupabaseClient _supabase;

  MinistryStockRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<bool> canView(String ministryId) =>
      _flag('ministry_stock_can_view', ministryId);

  Future<bool> canManage(String ministryId) =>
      _flag('ministry_stock_can_manage', ministryId);

  Future<bool> canAudit(String ministryId) =>
      _flag('ministry_audit_can_view', ministryId);

  Future<bool> _flag(String fn, String ministryId) async {
    try {
      final r = await _supabase.rpc(fn, params: {'p_ministry_id': ministryId});
      return r == true;
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// Itens do ministério, arquivados inclusive (a tela separa).
  Future<List<StockItem>> getItems(String ministryId) async {
    try {
      final response = await _supabase
          .from('ministry_stock_item')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .order('name');
      return (response as List)
          .map((j) => StockItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  Future<List<StockMovement>> getHistory(String itemId) async {
    final rows = await _rpc('ministry_stock_history', {'p_item_id': itemId});
    return [
      for (final r in rows as List)
        StockMovement.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Quem não pode auditar recebe lista vazia, não erro.
  Future<List<AuditEntry>> getAuditFeed(String ministryId) async {
    final rows = await _rpc('ministry_audit_feed', {
      'p_ministry_id': ministryId,
      'p_limit': 500,
    });
    return [
      for (final r in rows as List)
        AuditEntry.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Cadastra ([itemId] nulo) ou edita. Na edição a quantidade não muda.
  Future<String> saveItem({
    required String ministryId,
    String? itemId,
    required String name,
    required String unit,
    String? category,
    String? location,
    String? notes,
    double? minQuantity,
    double initialQuantity = 0,
  }) async {
    final id = await _rpc('ministry_stock_item_save', {
      'p_ministry_id': ministryId,
      'p_item_id': itemId,
      'p_name': name,
      'p_unit': unit,
      'p_category': category,
      'p_location': location,
      'p_notes': notes,
      'p_min_quantity': minQuantity,
      'p_initial_quantity': itemId == null ? initialQuantity : 0,
    });
    return id as String;
  }

  Future<void> archiveItem(String itemId, bool archived) =>
      _rpc('ministry_stock_item_archive', {
        'p_item_id': itemId,
        'p_archived': archived,
      });

  /// `saida`/`entrada`: quantidade positiva. `ajuste`: delta com sinal.
  /// `conferencia`: a quantidade contada. Devolve a nova quantidade.
  Future<double> move({
    required String itemId,
    required StockMoveKind kind,
    required double quantity,
    String? note,
  }) async {
    final r = await _rpc('ministry_stock_move', {
      'p_item_id': itemId,
      'p_kind': kind.value,
      'p_quantity': quantity,
      'p_note': note,
    });
    return (r as num).toDouble();
  }

  Future<double> revert({
    required String movementId,
    required String note,
  }) async {
    final r = await _rpc('ministry_stock_revert', {
      'p_movement_id': movementId,
      'p_note': note,
    });
    return (r as num).toDouble();
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw _traduzir(e);
    }
  }

  /// As mensagens das RPCs já vêm em português (sem acento) e dizem o caso
  /// exato; aqui elas ganham acento e os códigos genéricos viram frase.
  MinistryStockException _traduzir(PostgrestException e) {
    final msg = _acentuar(e.message);
    switch (e.code) {
      case '28000':
        return const MinistryStockException(
          'Sua sessão expirou. Entre de novo.',
        );
      case '42501':
        return MinistryStockException(
          e.message.isNotEmpty && !e.message.contains('row-level')
              ? msg
              : 'Você não tem permissão para esta ação no estoque.',
        );
      case 'P0002':
        return const MinistryStockException(
          'Este item ou movimento não existe mais. Atualize a lista.',
        );
      case '23505':
        return MinistryStockException(
          e.message.contains('corrigido')
              ? msg
              : 'Já existe um item com esse nome neste ministério.',
        );
      case '23514':
        return MinistryStockException(
          e.message.startsWith('Estoque')
              ? msg
              : 'Confira os dados: o nome precisa ter de 1 a 120 letras e a '
                    'unidade tem de ser uma das da lista.',
        );
      case '22023':
        return MinistryStockException(msg);
    }
    return MinistryStockException(msg);
  }

  static const _acentos = {
    'disponivel': 'disponível',
    'Nao autenticado': 'Não autenticado',
    'so numero inteiro': 'só número inteiro',
    'So quem e do ministerio registra saida':
        'Só quem é do ministério registra saída',
    'Sem permissao': 'Sem permissão',
    'Movimento invalido': 'Movimento inválido',
    'observacao': 'observação',
    'nao pode': 'não pode',
    'So quem lancou': 'Só quem lançou',
    'Correcao nao se corrige': 'Correção não se corrige',
    'ja corrigido': 'já corrigido',
    'correcao': 'correção',
    'nao encontrado': 'não encontrado',
    'fracao; faca uma conferencia': 'fração; faça uma conferência',
    'conferencia': 'conferência',
    'saida': 'saída',
  };

  String _acentuar(String s) {
    var out = s;
    _acentos.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
