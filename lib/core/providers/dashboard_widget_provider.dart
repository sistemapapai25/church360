import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
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

/// Provider para todos os widgets (para tela de configuração).
///
/// `FutureProvider` de propósito, não `StreamProvider`: `dashboard_widget` é
/// tabela de configuração e muda raríssimo, mas o canal Realtime derrubava a
/// tela inteira quando o JWT do socket expirava (aba em segundo plano no web).
/// Quem altera a tabela chama [refreshDashboardWidgetsProvider].
final allDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.getAll();
});

/// Widgets habilitados no tenant (toggle geral da igreja, sem filtro por
/// usuário). Base para [permittedDashboardWidgetsProvider].
///
/// `FutureProvider` pelo mesmo motivo de [allDashboardWidgetsProvider]: como
/// [permittedDashboardWidgetsProvider] dá `await` no `.future` daqui, qualquer
/// erro de canal virava erro do Dashboard inteiro, sem retry e sem fallback.
final tenantEnabledDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) {
  final repository = ref.watch(dashboardWidgetRepositoryProvider);
  return repository.getEnabled();
});

/// Preferências pessoais do usuário atual: `widget_key -> (visível, ordem)`.
final currentUserDashboardWidgetPreferencesProvider =
    FutureProvider<Map<String, UserDashboardWidgetPref>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final repository = ref.watch(userDashboardWidgetRepositoryProvider);
  return repository.getPreferences(userId);
});

/// Widgets habilitados no tenant que o usuário atual tem permissão de ver
/// (CHU-305/306): cruza a permissão RBAC exigida por cada widget em
/// [dashboardWidgetPermissionMap]. Widgets fora desse conjunto nunca
/// aparecem, mesmo que o usuário tenha uma preferência salva pra exibi-los.
///
/// CHU-384: havia aqui um segundo filtro, que exigia ser `coordinator` de
/// algum ministério para ver `upcoming_events`. Ele escondia o card de todo
/// mundo, porque esse papel não existe no dado — ver
/// `dashboard_widget_permissions.dart`. A permissão RBAC é a única régua.
final permittedDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) async {
  final tenantWidgets = await ref.watch(tenantEnabledDashboardWidgetsProvider.future);

  final permitted = <DashboardWidget>[];
  for (final widget in tenantWidgets) {
    // Card fora do mapa não aparece (antes aparecia para todos). Relatório
    // customizado no card segue a permissão da lista de relatórios.
    final key = widget.widgetKey;
    final requiredPermission = key.startsWith('custom_report_')
        ? 'reports.view'
        : dashboardWidgetPermissionMap[key];
    if (requiredPermission == null &&
        !dashboardWidgetPermissionMap.containsKey(key)) {
      continue;
    }
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
///
/// Ordem (B1): o que a pessoa ordenou vem primeiro, pelo `sort_order` dela;
/// o que ela nunca ordenou (card novo que a igreja ligou depois) vai para o
/// **fim**, na ordem da igreja — a mesma regra de chave nova do
/// `more_menu_layout_provider`. Quem nunca ordenou nada vê a ordem da igreja.
final enabledDashboardWidgetsProvider = FutureProvider<List<DashboardWidget>>((ref) async {
  final permitted = await ref.watch(permittedDashboardWidgetsProvider.future);
  final preferences = await ref.watch(currentUserDashboardWidgetPreferencesProvider.future);

  final ordenados = <(DashboardWidget, int)>[];
  final novos = <DashboardWidget>[];
  for (final widget in permitted) {
    final pref = preferences[widget.widgetKey];
    if (pref != null && !pref.isVisible) continue;
    if (pref?.sortOrder case final order?) {
      ordenados.add((widget, order));
    } else {
      novos.add(widget);
    }
  }
  ordenados.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (widget, _) in ordenados) widget, ...novos];
});

/// Invalida a cadeia inteira por trás da lista de widgets do Dashboard.
///
/// Invalidar só a folha ([enabledDashboardWidgetsProvider]) não basta:
/// `invalidate` recomputa o provider e seus dependentes, nunca as dependências
/// dele — a folha daria `await` no `.future` já em cache de
/// [tenantEnabledDashboardWidgetsProvider] e nada iria ao banco. Enquanto os
/// widgets vinham de Realtime isso passava batido, porque o canal empurrava o
/// dado sozinho.
void _invalidateDashboardWidgetChain(Ref ref) {
  ref.invalidate(allDashboardWidgetsProvider);
  ref.invalidate(tenantEnabledDashboardWidgetsProvider);
  ref.invalidate(currentUserDashboardWidgetPreferencesProvider);
  ref.invalidate(permittedDashboardWidgetsProvider);
  ref.invalidate(enabledDashboardWidgetsProvider);
}

/// Recarrega a lista de widgets do Dashboard a partir do banco. Use em
/// pull-to-refresh, no botão de retry da tela de erro e depois de qualquer
/// escrita em `dashboard_widget`.
final refreshDashboardWidgetsProvider = Provider<void Function()>((ref) {
  return () => _invalidateDashboardWidgetChain(ref);
});

/// Preferências efetivas do usuário atual via RPC `get_user_dashboard_widgets`
/// (CHU-309): `widget_key -> (visível, ordem)`, já restrito aos widgets que
/// ele tem permissão RBAC de ver e **na ordem da Dashboard**. Base da tela de
/// gerenciamento pessoal (CHU-308).
final myEffectiveDashboardWidgetPreferencesProvider =
    FutureProvider<Map<String, UserDashboardWidgetPref>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final repository = ref.watch(userDashboardWidgetRepositoryProvider);
  return repository.getEffectivePreferences(userId);
});

/// Widgets que o usuário atual pode gerenciar na tela pessoal (CHU-308):
/// metadados do widget ([DashboardWidget]) cruzados com a visibilidade
/// efetiva ([myEffectiveDashboardWidgetPreferencesProvider]), na ordem em que
/// a RPC devolve (a mesma da Dashboard). Nunca inclui widget que o usuário
/// não tem permissão de ver.
final myDashboardWidgetSettingsProvider = FutureProvider<List<(DashboardWidget widget, bool isVisible)>>((ref) async {
  final tenantWidgets = await ref.watch(tenantEnabledDashboardWidgetsProvider.future);
  final preferences = await ref.watch(myEffectiveDashboardWidgetPreferencesProvider.future);

  final byKey = {for (final w in tenantWidgets) w.widgetKey: w};
  return [
    for (final MapEntry(key: key, value: pref) in preferences.entries)
      if (byKey[key] case final widget?) (widget, pref.isVisible),
  ];
});

void _invalidateMyDashboardLayout(Ref ref) {
  ref.invalidate(currentUserDashboardWidgetPreferencesProvider);
  ref.invalidate(myEffectiveDashboardWidgetPreferencesProvider);
  ref.invalidate(myDashboardWidgetSettingsProvider);
  ref.invalidate(enabledDashboardWidgetsProvider);
}

/// Grava visibilidade + ordem escolhidas na tela "Meu Dashboard" (B1).
///
/// [itens] vem com o que a tela listou (só o que a pessoa pode ver). As
/// chaves com linha salva que ficaram de fora (card que ela não vê mais)
/// são anexadas no fim preservando o `is_visible`, para o `sort_order` delas
/// não colidir com os novos índices — igual ao `saveMoreMenuLayoutProvider`.
final saveMyDashboardLayoutProvider =
    Provider<Future<void> Function(List<(DashboardWidget, bool)>)>((ref) {
  return (itens) async {
    final repository = ref.read(userDashboardWidgetRepositoryProvider);
    final prefs = await ref.read(currentUserDashboardWidgetPreferencesProvider.future);
    final naTela = {for (final (w, _) in itens) w.widgetKey};
    await repository.saveLayout([
      for (final (w, isVisible) in itens) (w.widgetKey, isVisible),
      for (final MapEntry(key: key, value: pref) in prefs.entries)
        if (!naTela.contains(key)) (key, pref.isVisible),
    ]);
    _invalidateMyDashboardLayout(ref);
  };
});

/// "Restaurar padrão da igreja": apaga as preferências pessoais; a pessoa
/// volta a ver tudo que pode, na ordem da igreja.
final resetMyDashboardLayoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(userDashboardWidgetRepositoryProvider).saveLayout(const []);
    _invalidateMyDashboardLayout(ref);
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
    _invalidateDashboardWidgetChain(ref);
    return widget;
  };
});

