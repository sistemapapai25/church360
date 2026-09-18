import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/more_menu_item.dart';

/// Repositório do layout pessoal da aba "Mais" (F6).
///
/// Leitura é `select` direto: as policies "own" de `user_more_menu_item`
/// (`tenant_id = current_tenant_id() AND user_id = auth.uid()`) já restringem
/// a linha, e não há nada para cruzar no servidor — o gate de quem pode ver
/// cada item é do cliente. Escrita passa pela RPC, que grava o layout inteiro
/// numa única statement (a reordenação nunca fica meio gravada).
class MoreMenuLayoutRepository {
  final SupabaseClient _supabase;

  MoreMenuLayoutRepository(this._supabase);

  /// Preferências salvas: `item_key -> (is_visible, sort_order)`.
  ///
  /// Um item sem entrada aqui nunca foi configurado por esta pessoa.
  /// [userId] é o `auth.uid()` — a mesma chave que as policies comparam.
  Future<Map<String, MoreMenuPreference>> getMyLayout(String userId) async {
    final response = await _supabase
        .from('user_more_menu_item')
        .select('item_key, is_visible, sort_order')
        .eq('user_id', userId)
        .order('sort_order');

    return {
      for (final row in response as List)
        row['item_key'] as String: MoreMenuPreference(
          isVisible: row['is_visible'] as bool,
          sortOrder: (row['sort_order'] as num).toInt(),
        ),
    };
  }

  /// Grava o layout inteiro via `set_my_more_menu_layout`.
  ///
  /// A RPC não tem parâmetro de ator (CHU-326): o sujeito é sempre
  /// `auth.uid()`. [items] vem na ordem final da tela; o `sort_order` é o
  /// índice, reescrito por completo a cada gravação em vez de incrementado.
  Future<void> saveLayout(List<(MoreMenuItem, bool)> items) async {
    final payload = <Map<String, Object?>>[
      for (final (index, (item, isVisible)) in items.indexed)
        {
          'item_key': item.key,
          'is_visible': isVisible,
          'sort_order': index,
        },
    ];

    await _supabase.rpc(
      'set_my_more_menu_layout',
      params: {'p_items': payload},
    );
  }
}
