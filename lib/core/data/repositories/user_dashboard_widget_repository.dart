import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositório de preferências pessoais de cards do Dashboard (CHU-304).
///
/// Distinto de [DashboardWidgetRepository], que controla o toggle geral por
/// tenant (liga/desliga pra igreja toda).
class UserDashboardWidgetRepository {
  final SupabaseClient _supabase;

  UserDashboardWidgetRepository(this._supabase);

  /// Preferências do usuário: `widget_key -> is_visible`. Um widget sem
  /// entrada aqui ainda não foi configurado manualmente pelo usuário.
  Future<Map<String, bool>> getPreferences(String userId) async {
    final response = await _supabase
        .from('user_dashboard_widget')
        .select('widget_key, is_visible')
        .eq('user_id', userId);

    return {
      for (final row in response as List)
        row['widget_key'] as String: row['is_visible'] as bool,
    };
  }

  /// Preferências efetivas do usuário via RPC `get_user_dashboard_widgets`
  /// (CHU-309): `widget_key -> is_visible`, já restrito aos widgets que ele
  /// tem permissão RBAC de ver (e, quando exigido, é coordinator de algum
  /// ministério). Diferente de [getPreferences], que retorna a preferência
  /// crua sem cruzar com a permissão atual — usar esta para a tela de
  /// gerenciamento pessoal (CHU-308).
  Future<Map<String, bool>> getEffectivePreferences(String userId) async {
    final response = await _supabase.rpc(
      'get_user_dashboard_widgets',
      params: {'p_user_id': userId},
    );

    return {
      for (final row in response as List)
        row['widget_key'] as String: row['is_visible'] as bool,
    };
  }

  /// Liga/desliga um widget na preferência pessoal do usuário atual, via RPC
  /// `set_user_dashboard_widget_visibility` (CHU-309).
  Future<void> setVisibility({
    required String widgetKey,
    required bool isVisible,
  }) async {
    await _supabase.rpc(
      'set_user_dashboard_widget_visibility',
      params: {
        'p_widget_key': widgetKey,
        'p_is_visible': isVisible,
      },
    );
  }
}
