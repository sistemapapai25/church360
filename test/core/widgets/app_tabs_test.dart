import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tabs = [
  AppTab(label: 'Alunos', count: '9'),
  AppTab(label: 'Checklist', count: '10/41'),
  AppTab(label: 'Presenca'),
  AppTab(label: 'WhatsApp'),
  AppTab(label: 'Relatorios'),
];

Widget _host({
  required int selected,
  required ValueChanged<int> onChanged,
  Brightness brightness = Brightness.light,
  double width = 800,
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark
        ? AppTheme.darkTheme
        : AppTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: AppTabs(
            tabs: _tabs,
            selectedIndex: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mostra rotulos e contadores', (tester) async {
    await tester.pumpWidget(_host(selected: 0, onChanged: (_) {}));

    expect(find.text('Alunos'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('10/41'), findsOneWidget);
    expect(find.text('Relatorios'), findsOneWidget);
  });

  testWidgets('toque em uma aba devolve o indice dela', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _host(selected: 0, onChanged: (index) => tapped = index),
    );

    await tester.tap(find.text('Checklist'));
    expect(tapped, 1);
  });

  testWidgets('a aba ativa e a unica com fundo primary', (tester) async {
    await tester.pumpWidget(_host(selected: 2, onChanged: (_) {}));
    await tester.pumpAndSettle();

    final pintadas = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) => (c.decoration as BoxDecoration).color == AppTheme.primary)
        .length;

    expect(pintadas, 1);
  });

  testWidgets('cabe em tela estreita rolando na horizontal', (tester) async {
    // Cinco abas nao cabem em 360px: o teste garante que a barra rola em vez
    // de estourar o layout (que no Flutter vira um overflow vermelho).
    await tester.pumpWidget(
      _host(selected: 0, onChanged: (_) {}, width: 360),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
