// B2 (roadmap Home/culto/Dashboard, 14/10/2026): a moldura do card.
// No celular o card passa direto (sem botão); em tablet/PC um card mais alto
// que o limite ganha "Expandir", que vira "Recolher" ao tocar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/widgets/dashboard_card_frame.dart';

Widget _app({required double width, required double childHeight}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: DashboardCardFrame(
                widgetKey: 'teste',
                maxHeight: 200,
                child: SizedBox(height: childHeight, child: const Text('card')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('celular: sem moldura, sem botão', (tester) async {
    await tester.pumpWidget(_app(width: 400, childHeight: 1000));
    await tester.pump();

    expect(find.text('card'), findsOneWidget);
    expect(find.text('Expandir'), findsNothing);
    expect(
      find.byType(SingleChildScrollView),
      findsOneWidget,
      reason: 'só a rolagem da página; nada dentro do card',
    );
  });

  testWidgets('PC: card que cabe não ganha botão', (tester) async {
    await tester.pumpWidget(_app(width: 1000, childHeight: 100));
    await tester.pump();

    expect(find.text('Expandir'), findsNothing);
  });

  testWidgets('PC: card alto ganha Expandir, que vira Recolher', (
    tester,
  ) async {
    await tester.pumpWidget(_app(width: 1000, childHeight: 1000));
    await tester.pump();

    expect(find.text('Expandir'), findsOneWidget);

    await tester.tap(find.text('Expandir'));
    await tester.pump();

    expect(find.text('Recolher'), findsOneWidget);
    expect(find.text('Expandir'), findsNothing);
  });
}
