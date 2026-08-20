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
}
