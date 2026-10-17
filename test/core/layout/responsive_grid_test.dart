import 'package:church360_app/core/layout/responsive_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card(String k) => SizedBox(key: ValueKey(k), height: 60);

Future<void> _pump(WidgetTester tester, double width, List<Widget> kids) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ResponsiveGrid(children: kids),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('celular: 1 coluna, igual a uma pilha', (tester) async {
    await _pump(tester, 390, [_card('a'), _card('b')]);
    expect(tester.getTopLeft(find.byKey(const ValueKey('a'))), Offset.zero);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))),
      const Offset(0, 72),
    );
    expect(tester.getSize(find.byKey(const ValueKey('a'))).width, 390);
  });

  testWidgets('PC: 3 colunas e item escondido não deixa buraco', (
    tester,
  ) async {
    await _pump(tester, 1000, [
      _card('a'),
      const SizedBox.shrink(), // gate que negou
      _card('b'),
      _card('c'),
      _card('d'),
    ]);
    final w = (1000 - 24) / 3;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))),
      Offset(w + 12, 0),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('c'))),
      Offset(2 * (w + 12), 0),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('d'))),
      const Offset(0, 72),
    );
  });

  testWidgets('tudo escondido: altura zero', (tester) async {
    await _pump(tester, 1000, [const SizedBox.shrink()]);
    expect(tester.getSize(find.byType(ResponsiveGrid)).height, 0);
  });
}
