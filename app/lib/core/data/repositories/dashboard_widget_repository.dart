import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/dashboard_widget.dart';

/// Repositório para gerenciar widgets da Dashboard
class DashboardWidgetRepository {
  final SupabaseClient _supabase;

  DashboardWidgetRepository(this._supabase);

  /// Buscar todos os widgets
  Future<List<DashboardWidget>> getAll() async {
    final response = await _supabase
        .from('dashboard_widget')
        .select()
        .order('display_order', ascending: true);

    return (response as List)
        .map((json) => DashboardWidget.fromJson(json))
        .toList();
  }

  /// Buscar apenas widgets habilitados
  Future<List<DashboardWidget>> getEnabled() async {
    final response = await _supabase
        .from('dashboard_widget')
        .select()
        .eq('is_enabled', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((json) => DashboardWidget.fromJson(json))
        .toList();
  }

  /// Buscar widget por key
  Future<DashboardWidget?> getByKey(String widgetKey) async {
    final response = await _supabase
        .from('dashboard_widget')
        .select()
        .eq('widget_key', widgetKey)
        .maybeSingle();

    if (response == null) return null;
    return DashboardWidget.fromJson(response);
  }

  /// Atualizar status de habilitado/desabilitado
  Future<void> updateEnabled(String id, bool isEnabled) async {
    await _supabase
        .from('dashboard_widget')
        .update({'is_enabled': isEnabled})
        .eq('id', id);
  }

  /// Atualizar ordem de exibição
  Future<void> updateDisplayOrder(String id, int displayOrder) async {
    await _supabase
        .from('dashboard_widget')
        .update({'display_order': displayOrder})
        .eq('id', id);
  }

  /// Atualizar múltiplos widgets (para reordenação em lote)
  Future<void> updateMultiple(List<Map<String, dynamic>> updates) async {
    for (var update in updates) {
      await _supabase
          .from('dashboard_widget')
          .update({
            'display_order': update['display_order'],
          })
          .eq('id', update['id']);
    }
  }

  /// Restaurar configuração padrão
  Future<void> restoreDefaults() async {
    await _supabase.rpc('restore_default_dashboard_widgets');
  }

  /// Stream de widgets (para atualizações em tempo real)
  Stream<List<DashboardWidget>> watchAll() {
    return _supabase
        .from('dashboard_widget')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .map((data) => data.map((json) => DashboardWidget.fromJson(json)).toList());
  }

  /// Stream de widgets habilitados
  Stream<List<DashboardWidget>> watchEnabled() {
    return _supabase
        .from('dashboard_widget')
        .stream(primaryKey: ['id'])
        .eq('is_enabled', true)
        .order('display_order', ascending: true)
        .map((data) => data.map((json) => DashboardWidget.fromJson(json)).toList());
  }

  /// Criar um novo widget customizado
  Future<DashboardWidget> createCustomWidget({
    required String widgetKey,
    required String widgetName,
    String? description,
    required String category,
    String? iconName,
    bool isEnabled = true,
  }) async {
    // Buscar o maior display_order atual
    final maxOrderResponse = await _supabase
        .from('dashboard_widget')
        .select('display_order')
        .order('display_order', ascending: false)
        .limit(1);

    int nextOrder = 0;
    if (maxOrderResponse.isNotEmpty) {
      nextOrder = (maxOrderResponse[0]['display_order'] as int) + 1;
    }

    final response = await _supabase
        .from('dashboard_widget')
        .insert({
          'widget_key': widgetKey,
          'widget_name': widgetName,
          'description': description,
          'category': category,
          'icon_name': iconName,
          'is_enabled': isEnabled,
          'display_order': nextOrder,
          'is_default': false, // Widgets customizados não são padrão
        })
        .select()
        .single();

    return DashboardWidget.fromJson(response);
  }

  /// Verificar se um widget_key já existe
  Future<bool> widgetKeyExists(String widgetKey) async {
    final response = await _supabase
        .from('dashboard_widget')
        .select('id')
        .eq('widget_key', widgetKey)
        .maybeSingle();

    return response != null;
  }

  /// Deletar widget customizado (apenas não-padrão)
  Future<void> deleteCustomWidget(String id) async {
    await _supabase
        .from('dashboard_widget')
        .delete()
        .eq('id', id)
        .eq('is_default', false); // Só deleta se não for padrão
  }
}

