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
  Widget? trailing,
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
            trailing: trailing,
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

  testWidgets('quando cabem, as abas dividem a barra em partes iguais', (
    tester,
  ) async {
    // A janela de teste tem 800px e recorta qualquer largura maior; sem
    // `setSurfaceSize` a barra "larga" seria medida apertada e cairia no modo
    // rolavel.
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(selected: 0, onChanged: (_) {}, width: 1200));
    await tester.pumpAndSettle();

    // Nada rola: a barra coube, entao ela se distribui em vez de deixar
    // metade da largura vazia a direita.
    expect(find.byType(SingleChildScrollView), findsNothing);

    final larguras = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    expect(larguras.length, _tabs.length);

    final medidas = <double>[
      for (var i = 0; i < _tabs.length; i++)
        tester.getSize(find.byType(AnimatedContainer).at(i)).width,
    ];
    for (final medida in medidas) {
      expect((medida - medidas.first).abs(), lessThan(1));
    }

    // E as fatias somadas ocupam a largura da barra, nao um bloco no canto.
    final soma = medidas.reduce((a, b) => a + b);
    expect(soma, greaterThan(1200 - 40));
  });

  testWidgets('o trailing fecha a barra depois da ultima aba', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        selected: 0,
        onChanged: (_) {},
        width: 1200,
        trailing: const Icon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();

    final engrenagem = tester.getCenter(find.byIcon(Icons.settings_outlined));
    final ultimaAba = tester.getCenter(find.text('Relatorios'));
    expect(engrenagem.dx, greaterThan(ultimaAba.dx));
  });

  testWidgets('em tela estreita o trailing continua visivel', (tester) async {
    // Com a trilha rolando, um controle dentro dela so apareceria depois de
    // arrastar as cinco abas ate o fim. Ele fica fora da parte rolavel.
    await tester.pumpWidget(
      _host(
        selected: 0,
        onChanged: (_) {},
        width: 360,
        trailing: const Icon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Visivel dentro da barra, e nao empurrada para fora dela pela trilha.
    final barra = find.byType(AppTabs);
    final engrenagem = tester.getCenter(find.byIcon(Icons.settings_outlined));
    expect(engrenagem.dx, lessThan(tester.getBottomRight(barra).dx));
    expect(engrenagem.dx, greaterThan(tester.getTopLeft(barra).dx));
  });
}
