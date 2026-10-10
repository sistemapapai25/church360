// CHU-310: QA automatizado do gating de widgets do Dashboard de Liderança
// por perfil (membro, quem tem só members.view, quem tem events.view,
// financeiro, admin/owner). Cobre a lógica central em
// lib/core/providers/dashboard_widget_provider.dart, que decide quais cards
// aparecem para o usuário atual.
//
// CHU-384 (29/09/2026): estes testes passavam com a regra antiga, em que
// `upcoming_events` exigia também ser `coordinator` de algum ministério —
// porque o cenário "é coordinator" era um booleano injetado no container. Em
// produção esse papel não existe em nenhuma das 195 linhas de
// `ministry_member`, então o card sumia para todos, Owner incluído, e nenhum
// teste reclamava. A régua agora é só a permissão RBAC, e o caso que faltava
// ("tem events.view e não é coordenador de nada") virou teste explícito.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/domain/models/dashboard_widget.dart';
import 'package:church360_app/core/providers/dashboard_widget_provider.dart';
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
/// (birthdays_month), um gated por permissão simples (recent_members), a
/// Agenda completa (upcoming_events, gated por events.view desde a CHU-384) e
/// um gated por financial.view_reports (financial_summary).
final _tenantWidgets = [
  _widget('birthdays_month'),
  _widget('recent_members'),
  _widget('upcoming_events'),
  _widget('financial_summary'),
];

ProviderContainer _buildContainer({
  required Set<String> grantedPermissions,
  Map<String, bool> personalPreferences = const {},
  List<DashboardWidget>? widgets,
}) {
  final container = ProviderContainer(
    overrides: [
      tenantEnabledDashboardWidgetsProvider.overrideWith(
        (ref) => widgets ?? _tenantWidgets,
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
        grantedPermissions: {},
      );
      addTearDown(container.dispose);

      final keys = await _permittedKeys(container);

      expect(keys, {'birthdays_month'});
    });

    test(
      'Quem tem members.view não vê Agenda nem Financeiro',
      () async {
        final container = _buildContainer(
          grantedPermissions: {'members.view'},
        );
        addTearDown(container.dispose);

        final keys = await _permittedKeys(container);

        expect(keys, {'birthdays_month', 'recent_members'});
        expect(keys, isNot(contains('upcoming_events')));
        expect(keys, isNot(contains('financial_summary')));
      },
    );

    test(
      'CHU-384: quem tem events.view vê a Agenda, sem ser coordenador de nada',
      () async {
        final container = _buildContainer(
          grantedPermissions: {'events.view'},
        );
        addTearDown(container.dispose);

        final keys = await _permittedKeys(container);

        expect(
          keys,
          contains('upcoming_events'),
          reason: 'a Agenda segue events.view e mais nada; era este o caso '
              'que o gate de coordinator derrubava para todo mundo',
        );
      },
    );

    test(
      'Sem events.view não vê a Agenda, mesmo com as outras permissões',
      () async {
        final container = _buildContainer(
          grantedPermissions: {'members.view', 'financial.view_reports'},
        );
        addTearDown(container.dispose);

        final keys = await _permittedKeys(container);

        expect(keys, isNot(contains('upcoming_events')));
      },
    );

    test('Usuário com financial.view_reports vê o card Financeiro', () async {
      final container = _buildContainer(
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

  group('cards fora do mapa (lote 10, A11)', () {
    final widgets = [
      _widget('birthdays_month'),
      _widget('custom_report_abc'),
      _widget('dispatch_auto_scheduler'),
      _widget('card_que_ninguem_mapeou'),
    ];

    test('membro comum não vê relatório customizado, agendador nem card desconhecido',
        () async {
      final container = _buildContainer(grantedPermissions: {}, widgets: widgets);
      addTearDown(container.dispose);

      expect(await _permittedKeys(container), {'birthdays_month'});
    });

    test('reports.view libera o relatório customizado; dispatch.configure o agendador',
        () async {
      final container = _buildContainer(
        grantedPermissions: {'reports.view', 'dispatch.configure'},
        widgets: widgets,
      );
      addTearDown(container.dispose);

      expect(
        await _permittedKeys(container),
        {'birthdays_month', 'custom_report_abc', 'dispatch_auto_scheduler'},
      );
    });
  });

  group('enabledDashboardWidgetsProvider — preferência pessoal (CHU-304)', () {
    test(
      'widget permitido mas desativado manualmente pelo usuário não aparece',
      () async {
        final container = _buildContainer(
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

  // Regressão da troca de Realtime por busca sob demanda: enquanto os widgets
  // vinham de um StreamProvider, o canal empurrava o dado e ninguém reparava
  // que o RefreshIndicator invalidava só a folha da cadeia.
  group('refreshDashboardWidgetsProvider — recarga da cadeia', () {
    test(
      'invalidar só a folha não rebusca; o refresh da cadeia rebusca',
      () async {
        var buscas = 0;
        final container = ProviderContainer(
          overrides: [
            tenantEnabledDashboardWidgetsProvider.overrideWith((ref) {
              buscas++;
              // A segunda ida ao "banco" traz um card a mais.
              return buscas == 1
                  ? [_widget('birthdays_month')]
                  : [_widget('birthdays_month'), _widget('recent_members')];
            }),
            currentUserHasPermissionProvider.overrideWith(
              (ref, permissionCode) async => true,
            ),
            currentUserDashboardWidgetPreferencesProvider.overrideWith(
              (ref) async => const <String, bool>{},
            ),
          ],
        );
        addTearDown(container.dispose);

        Future<Set<String>> lerKeys() async {
          final enabled =
              await container.read(enabledDashboardWidgetsProvider.future);
          return enabled.map((w) => w.widgetKey).toSet();
        }

        expect(await lerKeys(), {'birthdays_month'});
        expect(buscas, 1);

        // Comportamento antigo do RefreshIndicator: recomputa a folha, que dá
        // await no .future já em cache do provider do tenant.
        container.invalidate(enabledDashboardWidgetsProvider);
        expect(await lerKeys(), {'birthdays_month'});
        expect(
          buscas,
          1,
          reason: 'invalidar só a folha não pode disparar nova busca',
        );

        container.read(refreshDashboardWidgetsProvider)();
        expect(await lerKeys(), {'birthdays_month', 'recent_members'});
        expect(buscas, 2);
      },
    );
  });
}
