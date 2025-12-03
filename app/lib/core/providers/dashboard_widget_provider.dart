import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../data/repositories/dashboard_widget_repository.dart';
import '../domain/models/dashboard_widget.dart';

/// Provider do repositório de widgets da Dashboard
final dashboardWidgetRepositoryProvider = Provider<DashboardWidgetRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DashboardWidgetRepository(supabase);
});

/// Provider para todos os widgets (para tela de configuração)
final allDashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.watchAll();
});

/// Provider para widgets habilitados (para Dashboard)
final enabledDashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.watchEnabled();
});

/// Provider para buscar widget por key
final dashboardWidgetByKeyProvider = FutureProvider.family<DashboardWidget?, String>((ref, widgetKey) async {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.getByKey(widgetKey);
});

/// Provider para criar widget customizado
final createCustomDashboardWidgetProvider = Provider<Future<DashboardWidget> Function({
  required String widgetKey,
  required String widgetName,
  String? description,
  required String category,
  String? iconName,
  bool isEnabled,
})>((ref) {
  return ({
    required String widgetKey,
    required String widgetName,
    String? description,
    required String category,
    String? iconName,
    bool isEnabled = true,
  }) async {
    final repository = ref.read(dashboardWidgetRepositoryProvider);
    final widget = await repository.createCustomWidget(
      widgetKey: widgetKey,
      widgetName: widgetName,
      description: description,
      category: category,
      iconName: iconName,
      isEnabled: isEnabled,
    );
    ref.invalidate(allDashboardWidgetsProvider);
    ref.invalidate(enabledDashboardWidgetsProvider);
    return widget;
  };
});

