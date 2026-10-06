import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/permissions/presentation/widgets/permission_gate.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

/// Tela de exibição esconde a gestão mesmo para quem tem a permissão; a
/// entrada da Dashboard (enabled: false) mostra e leva o modo adiante.
Future<void> _pump(WidgetTester tester, {required bool viewOnly}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserHasPermissionProvider(
          'groups.edit',
        ).overrideWith((ref) async => true),
      ],
      child: MaterialApp(
        home: ViewOnlyScope(
          enabled: viewOnly,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text('rota${ViewOnlyScope.fromQuery(context)}'),
                const PermissionGate(
                  permission: 'groups.edit',
                  child: Text('Editar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exibição: gate some e não propaga gestão', (tester) async {
    await _pump(tester, viewOnly: true);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('rota'), findsOneWidget);
  });

  testWidgets('Dashboard: gate aparece e propaga ?from=dashboard', (
    tester,
  ) async {
    await _pump(tester, viewOnly: false);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('rota?from=dashboard'), findsOneWidget);
  });
}
