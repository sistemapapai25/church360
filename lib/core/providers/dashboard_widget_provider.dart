import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/ministries/presentation/providers/ministries_provider.dart';
import '../../features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;
import '../constants/dashboard_widget_permissions.dart';
import '../data/repositories/dashboard_widget_repository.dart';
import '../data/repositories/user_dashboard_widget_repository.dart';
import '../domain/models/dashboard_widget.dart';

/// Provider do repositório de widgets da Dashboard
final dashboardWidgetRepositoryProvider = Provider<DashboardWidgetRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DashboardWidgetRepository(supabase);
});

/// Provider do repositório de preferências pessoais de widgets (CHU-304)
final userDashboardWidgetRepositoryProvider = Provider<UserDashboardWidgetRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return UserDashboardWidgetRepository(supabase);
});

/// Provider para todos os widgets (para tela de configuração)
final allDashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.watchAll();
});

/// Widgets habilitados no tenant (toggle geral da igreja, sem filtro por
/// usuário). Base para [permittedDashboardWidgetsProvider].
final tenantEnabledDashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.watchEnabled();
});

/// Preferências pessoais do usuário atual: `widget_key -> is_visible`.
final currentUserDashboardWidgetPreferencesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final repository = ref.watch(userDashboardWidgetRepositoryProvider);
  return repository.getPreferences(userId);
});

/// Widgets habilitados no tenant que o usuário atual tem permissão de ver
/// (CHU-305/306): cruza a permissão RBAC exigida por cada widget e, pros
/// que exigem líder direto do departamento, se o usuário é `coordinator`
/// de algum ministério. Widgets fora desse conjunto nunca aparecem, mesmo
/// que o usuário tenha uma preferência salva pra exibi-los.
final permittedDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) async {
  final tenantWidgets = await ref.watch(tenantEnabledDashboardWidgetsProvider.future);
  final isCoordinator = await ref.watch(currentUserIsMinistryCoordinatorProvider.future);

  final permitted = <DashboardWidget>[];
  for (final widget in tenantWidgets) {
    if (dashboardWidgetsRequiringCoordinator.contains(widget.widgetKey) && !isCoordinator) {
      continue;
    }

    final requiredPermission = dashboardWidgetPermissionMap[widget.widgetKey];
    if (requiredPermission != null) {
      final hasPermission = await ref.watch(
        currentUserHasPermissionProvider(requiredPermission).future,
      );
      if (!hasPermission) continue;
    }

    permitted.add(widget);
  }
  return permitted;
});

/// Provider para widgets habilitados (para Dashboard): dentre os widgets
/// permitidos pra esse usuário ([permittedDashboardWidgetsProvider]),
/// respeita a preferência pessoal dele — se nunca configurou um widget
/// permitido, mostra por padrão (CHU-302); se desativou manualmente,
/// respeita a escolha.
final enabledDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) async {
  final permitted = await ref.watch(permittedDashboardWidgetsProvider.future);
  final preferences = await ref.watch(currentUserDashboardWidgetPreferencesProvider.future);

  return permitted
      .where((widget) => preferences[widget.widgetKey] ?? true)
      .toList();
});

/// Preferências efetivas do usuário atual via RPC `get_user_dashboard_widgets`
/// (CHU-309): `widget_key -> is_visible`, já restrito aos widgets que ele tem
/// permissão RBAC de ver. Base da tela de gerenciamento pessoal (CHU-308).
final myEffectiveDashboardWidgetPreferencesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final repository = ref.watch(userDashboardWidgetRepositoryProvider);
  return repository.getEffectivePreferences(userId);
});

/// Widgets que o usuário atual pode gerenciar na tela pessoal (CHU-308):
/// metadados do widget ([DashboardWidget]) cruzados com a visibilidade
/// efetiva ([myEffectiveDashboardWidgetPreferencesProvider]). Nunca inclui
/// widget que o usuário não tem permissão de ver.
final myDashboardWidgetSettingsProvider = FutureProvider<List<(DashboardWidget widget, bool isVisible)>>((ref) async {
  final tenantWidgets = await ref.watch(tenantEnabledDashboardWidgetsProvider.future);
  final preferences = await ref.watch(myEffectiveDashboardWidgetPreferencesProvider.future);

  final settings = tenantWidgets
      .where((widget) => preferences.containsKey(widget.widgetKey))
      .map((widget) => (widget, preferences[widget.widgetKey]!))
      .toList();
  settings.sort((a, b) => a.$1.displayOrder.compareTo(b.$1.displayOrder));
  return settings;
});

/// Atualiza a visibilidade pessoal de um widget (CHU-308/309) e invalida os
/// providers dependentes, para refletir a mudança tanto na tela de
/// gerenciamento pessoal quanto no Dashboard.
final setMyDashboardWidgetVisibilityProvider = Provider<Future<void> Function({
  required String widgetKey,
  required bool isVisible,
})>((ref) {
  return ({required String widgetKey, required bool isVisible}) async {
    final repository = ref.read(userDashboardWidgetRepositoryProvider);
    await repository.setVisibility(widgetKey: widgetKey, isVisible: isVisible);
    ref.invalidate(myEffectiveDashboardWidgetPreferencesProvider);
    ref.invalidate(currentUserDashboardWidgetPreferencesProvider);
    ref.invalidate(enabledDashboardWidgetsProvider);
  };
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

