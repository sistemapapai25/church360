import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/dismissed_pair.dart';
import '../domain/models/duplicate_group.dart';

/// Erro ja traduzido para a tela. As RPCs de duplicata levantam excecao com
/// mensagem escrita para humano (portao de owner, dois logins, ficha de outro
/// tenant); guardar so o texto evita vazar o stack do PostgREST na UI.
class DuplicatesFailure implements Exception {
  final String mensagem;
  const DuplicatesFailure(this.mensagem);

  @override
  String toString() => mensagem;
}

final duplicatesRepositoryProvider = Provider<DuplicatesRepository>((ref) {
  return DuplicatesRepository(Supabase.instance.client);
});

/// Conversa com as RPCs de duplicata.
///
/// Nenhuma chamada passa `p_tenant_id`: as funcoes resolvem o tenant pela
/// ficha do proprio chamador e recusam um tenant que nao seja o dele. Mandar
/// o id daqui so criaria uma forma a mais de errar.
class DuplicatesRepository {
  final SupabaseClient _supabase;

  DuplicatesRepository(this._supabase);

  /// Grupos de fichas que repetem login, CPF, telefone ou e-mail — ja sem os
  /// pares que alguem marcou como pessoas diferentes.
  Future<List<DuplicateGroup>> findDuplicates() async {
    return _guard(() async {
      final resposta = await _supabase.rpc('find_duplicate_user_accounts');
      return (resposta as List? ?? const [])
          .map((linha) => DuplicateGroup.fromJson(Map<String, dynamic>.from(linha as Map)))
          .toList();
    });
  }

  /// O que ja foi dispensado, para a aba de reabrir.
  Future<List<DismissedPair>> listDismissed() async {
    return _guard(() async {
      final resposta = await _supabase.rpc('list_dismissed_duplicate_pairs');
      return (resposta as List? ?? const [])
          .map((linha) => DismissedPair.fromJson(Map<String, dynamic>.from(linha as Map)))
          .toList();
    });
  }

  /// "Ja olhei, sao pessoas diferentes." Idempotente: repetir o mesmo par so
  /// atualiza o motivo e a data.
  Future<void> dismissPair({
    required String userAId,
    required String userBId,
    String? motivo,
  }) async {
    await _guard(() => _supabase.rpc('dismiss_duplicate_pair', params: {
          'p_user_a_id': userAId,
          'p_user_b_id': userBId,
          'p_motivo': motivo,
        }));
  }

  /// Desfaz a dispensa: o par volta a aparecer na deteccao.
  Future<void> restorePair({
    required String userAId,
    required String userBId,
  }) async {
    await _guard(() => _supabase.rpc('restore_duplicate_pair', params: {
          'p_user_a_id': userAId,
          'p_user_b_id': userBId,
        }));
  }

  /// Funde fichas. Com `apply: false` (o padrao) a RPC executa tudo e desfaz,
  /// devolvendo o mesmo relatorio que a fusao real devolveria — e' o ensaio,
  /// e a tela sempre roda ele antes de perguntar qualquer coisa.
  Future<Map<String, dynamic>> mergeAccounts({
    required String keepId,
    required List<String> dropIds,
    bool apply = false,
  }) async {
    return _guard(() async {
      final resposta = await _supabase.rpc('merge_user_accounts', params: {
        'p_keep_id': keepId,
        'p_drop_ids': dropIds,
        'p_apply': apply,
      });
      return Map<String, dynamic>.from(resposta as Map);
    });
  }

  Future<T> _guard<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw DuplicatesFailure(e.message);
    } catch (e) {
      throw DuplicatesFailure(e.toString());
    }
  }
}
