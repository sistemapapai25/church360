// CHU-310: QA automatizado do gating de widgets do Dashboard de Liderança
// por perfil (membro, líder não-coordinator, coordinator, financeiro,
// admin/owner). Cobre a lógica central em
// lib/core/providers/dashboard_widget_provider.dart, que decide quais cards
// aparecem para o usuário atual.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/domain/models/dashboard_widget.dart';
import 'package:church360_app/core/providers/dashboard_widget_provider.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;

DashboardWidget _widget(String key) {
  final now = DateTime(2026, 1, 1);
  return DashboardWidget(
    id: key,
    widgetKey: key,
    widgetName: key,
    category: 'test',
    isEnabled: true,
    displayOrder: 0,
    isDefault: true,
    createdAt: now,
    updatedAt: now,
  );
}

/// Conjunto de widgets do tenant usado nos cenários: um card sempre visível
/// (birthdays_month), um gated por permissão simples (recent_members), um
/// gated por coordinator + permissão (upcoming_events, a Agenda completa) e
/// um gated por financial.view_reports (financial_summary).
final _tenantWidgets = [
  _widget('birthdays_month'),
  _widget('recent_members'),
  _widget('upcoming_events'),
  _widget('financial_summary'),
];

ProviderContainer _buildContainer({
  required bool isCoordinator,
  required Set<String> grantedPermissions,
  Map<String, bool> personalPreferences = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      tenantEnabledDashboardWidgetsProvider.overrideWith(
        (ref) => Stream.value(_tenantWidgets),
      ),
      currentUserIsMinistryCoordinatorProvider.overrideWith(
        (ref) async => isCoordinator,
      ),
      currentUserHasPermissionProvider.overrideWith(
        (ref, permissionCode) async => grantedPermissions.contains(permissionCode),
      ),
      currentUserDashboardWidgetPreferencesProvider.overrideWith(
        (ref) async => personalPreferences,
      ),
    ],
  );
  return container;
}

Future<Set<String>> _permittedKeys(ProviderContainer container) async {
  final permitted = await container.read(permittedDashboardWidgetsProvider.future);
  return permitted.map((w) => w.widgetKey).toSet();
}

void main() {
  group('permittedDashboardWidgetsProvider — perfis do CHU-310', () {
    test('Membro comum sem permissão extra vê só Aniversariantes', () async {
      final container = _buildContainer(
        isCoordinator: false,
        grantedPermissions: {},
      );
      addTearDown(container.dispose);

      final keys = await _permittedKeys(container);

      expect(keys, {'birthdays_month'});
    });

    test(
      'Líder de ministério (não-coordinator) não vê Agenda nem Financeiro '
      'mesmo tendo outra permissão',
      () async {
        final container = _buildContainer(
          isCoordinator: false,
          grantedPermissions: {'members.view'},
        );
        addTearDown(container.dispose);

        final keys = await _permittedKeys(container);

        expect(keys, {'birthdays_month', 'recent_members'});
        expect(keys, isNot(contains('upcoming_events')));
        expect(keys, isNot(contains('financial_summary')));
      },
    );

    test('Coordinator de um ministério vê a Agenda completa', () async {
      final container = _buildContainer(
        isCoordinator: true,
        grantedPermissions: {'events.view'},
      );
      addTearDown(container.dispose);

      final keys = await _permittedKeys(container);

      expect(keys, contains('upcoming_events'));
    });

    test(
      'Coordinator sem events.view continua sem ver a Agenda '
      '(precisa das duas condições)',
      () async {
        final container = _buildContainer(
          isCoordinator: true,
          grantedPermissions: {},
        );
        addTearDown(container.dispose);

        final keys = await _permittedKeys(container);

        expect(keys, isNot(contains('upcoming_events')));
      },
    );

    test('Usuário com financial.view_reports vê o card Financeiro', () async {
      final container = _buildContainer(
        isCoordinator: false,
        grantedPermissions: {'financial.view_reports'},
      );
      addTearDown(container.dispose);

      final keys = await _permittedKeys(container);

      expect(keys, contains('financial_summary'));
      expect(keys, isNot(contains('upcoming_events')));
      expect(keys, isNot(contains('recent_members')));
    });

    test('Admin/owner com todas as permissões vê todos os cards', () async {
      final container = _buildContainer(
        isCoordinator: true,
        grantedPermissions: {
          'members.view',
          'events.view',
          'financial.view_reports',
        },
      );
      addTearDown(container.dispose);

      final keys = await _permittedKeys(container);

      expect(
        keys,
        {'birthdays_month', 'recent_members', 'upcoming_events', 'financial_summary'},
      );
    });
  });

  group('enabledDashboardWidgetsProvider — preferência pessoal (CHU-304)', () {
    test(
      'widget permitido mas desativado manualmente pelo usuário não aparece',
      () async {
        final container = _buildContainer(
          isCoordinator: true,
          grantedPermissions: {
            'members.view',
            'events.view',
            'financial.view_reports',
          },
          personalPreferences: {'birthdays_month': false},
        );
        addTearDown(container.dispose);

        final enabled = await container.read(enabledDashboardWidgetsProvider.future);
        final keys = enabled.map((w) => w.widgetKey).toSet();

        expect(keys, isNot(contains('birthdays_month')));
        expect(keys, contains('upcoming_events'));
      },
    );

    test(
      'widget permitido sem preferência salva aparece por padrão (CHU-302)',
      () async {
        final container = _buildContainer(
          isCoordinator: false,
          grantedPermissions: {},
        );
        addTearDown(container.dispose);

        final enabled = await container.read(enabledDashboardWidgetsProvider.future);
        final keys = enabled.map((w) => w.widgetKey).toSet();

        expect(keys, {'birthdays_month'});
      },
    );

    test(
      'preferência pessoal não libera widget sem permissão RBAC',
      () async {
        final container = _buildContainer(
          isCoordinator: false,
          grantedPermissions: {},
          personalPreferences: {'financial_summary': true},
        );
        addTearDown(container.dispose);

        final enabled = await container.read(enabledDashboardWidgetsProvider.future);
        final keys = enabled.map((w) => w.widgetKey).toSet();

        expect(keys, isNot(contains('financial_summary')));
      },
    );
  });
}
