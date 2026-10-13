import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/screens/ministry_about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Ministry _ministry({String? vision, String? rules}) => Ministry(
  id: 'm1',
  name: 'Diaconato',
  color: '#2196F3',
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  vision: vision,
  rules: rules,
);

Future<void> _pump(WidgetTester tester, Ministry m, {VoidCallback? onEdit}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [ministryByIdProvider('m1').overrideWith((ref) async => m)],
        child: MaterialApp(
          home: MinistryAboutScreen(ministryId: 'm1', onEdit: onEdit),
        ),
      ),
    );

void main() {
  testWidgets('mostra só as seções preenchidas', (tester) async {
    await _pump(tester, _ministry(vision: 'Servir', rules: '  '));
    await tester.pumpAndSettle();

    expect(find.text('Visão'), findsOneWidget);
    expect(find.text('Servir'), findsOneWidget);
    expect(find.text('Regras'), findsNothing);
    expect(find.text('Ainda não preenchido'), findsNothing);
  });

  testWidgets('vazio: aviso, e Preencher só para quem edita', (tester) async {
    await _pump(tester, _ministry());
    await tester.pumpAndSettle();
    expect(find.text('Ainda não preenchido'), findsOneWidget);
    expect(find.text('Preencher'), findsNothing);

    var tapped = false;
    await _pump(tester, _ministry(), onEdit: () => tapped = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preencher'));
    expect(tapped, isTrue);
  });
}
