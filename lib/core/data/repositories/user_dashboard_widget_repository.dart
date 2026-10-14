import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/dashboard_widget.dart';

/// Repositório de preferências pessoais de cards do Dashboard (CHU-304, B1).
///
/// Distinto de [DashboardWidgetRepository], que controla o toggle geral por
/// tenant (liga/desliga pra igreja toda). Leitura crua é `select` direto
/// (policies "own"); escrita passa pela RPC `set_my_dashboard_layout`, que
/// grava visível + ordem numa única statement, como `set_my_more_menu_layout`.
class UserDashboardWidgetRepository {
  final SupabaseClient _supabase;

  UserDashboardWidgetRepository(this._supabase);

  /// Preferências cruas do usuário: `widget_key -> (visível, ordem)`. Um
  /// widget sem entrada aqui ainda não foi configurado por esta pessoa.
  Future<Map<String, UserDashboardWidgetPref>> getPreferences(String userId) async {
    final response = await _supabase
        .from('user_dashboard_widget')
        .select('widget_key, is_visible, sort_order')
        .eq('user_id', userId);

    return {
      for (final row in response as List)
        row['widget_key'] as String: UserDashboardWidgetPref(
          isVisible: row['is_visible'] as bool,
          sortOrder: (row['sort_order'] as num?)?.toInt(),
        ),
    };
  }

  /// Preferências efetivas via RPC `get_user_dashboard_widgets` (CHU-309):
  /// só os widgets que a igreja ligou e que o usuário tem permissão de ver,
  /// **já na ordem** em que a Dashboard mostra (ordem pessoal primeiro; o que
  /// nunca foi ordenado no fim, na ordem da igreja). O mapa preserva essa
  /// ordem. Base da tela "Meu Dashboard".
  Future<Map<String, UserDashboardWidgetPref>> getEffectivePreferences(String userId) async {
    final response = await _supabase.rpc(
      'get_user_dashboard_widgets',
      params: {'p_user_id': userId},
    );

    return {
      for (final row in response as List)
        row['widget_key'] as String: UserDashboardWidgetPref(
          isVisible: row['is_visible'] as bool,
          sortOrder: (row['sort_order'] as num?)?.toInt(),
        ),
    };
  }

  /// Grava o layout inteiro via `set_my_dashboard_layout`: [items] vem na
  /// ordem final da tela e o `sort_order` é o índice, reescrito por completo
  /// a cada gravação. Lista vazia apaga as preferências pessoais ("Restaurar
  /// padrão da igreja").
  Future<void> saveLayout(List<(String widgetKey, bool isVisible)> items) async {
    await _supabase.rpc(
      'set_my_dashboard_layout',
      params: {
        'p_items': [
          for (final (index, (key, isVisible)) in items.indexed)
            {'widget_key': key, 'is_visible': isVisible, 'sort_order': index},
        ],
      },
    );
  }
}
