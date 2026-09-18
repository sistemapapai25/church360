import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/app_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta a barra numa janela do tamanho pedido.
///
/// O tamanho vem de `setSurfaceSize`, nao de um `SizedBox`: a janela de
/// teste tem 800x600 e recorta qualquer largura maior, o que faria um teste
/// de "tela larga" medir 800 sem avisar.
Future<void> _pumpBar(
  WidgetTester tester, {
  required double width,
  ValueChanged<String>? onSearchChanged,
  VoidCallback? onPrimary,
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: AppFilterBar(
            searchHint: 'Buscar por aluno...',
            onSearchChanged: onSearchChanged,
            filters: const [
              AppFilterButton(label: 'Todos os status'),
              AppFilterButton(label: 'Todas as turmas'),
            ],
            onSort: () {},
            secondaryAction: const AppFilterAction(label: 'Turmas'),
            primaryAction: AppFilterAction(
              label: 'Novo aluno',
              icon: Icons.add,
              onPressed: onPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('em tela larga cabe tudo numa linha so', (tester) async {
    await _pumpBar(tester, width: 1400);

    expect(tester.takeException(), isNull);
    // A faixa rolavel so existe no modo compacto.
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Turmas'), findsOneWidget);
    expect(find.text('Novo aluno'), findsOneWidget);

    final distancia =
        (tester.getCenter(find.byType(TextField)).dy -
                tester.getCenter(find.text('Novo aluno')).dy)
            .abs();
    expect(distancia, lessThan(8));
  });

  testWidgets('em janela apertada os controles descem sem estourar', (
    tester,
  ) async {
    // Busca + 2 filtros + ordenacao + 2 acoes pedem perto de 900px. Em 800 a
    // barra tem que quebrar, nao virar a barra listrada de overflow.
    await _pumpBar(tester, width: 800);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Novo aluno')).dy,
      greaterThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
  });

  testWidgets('em tela de celular quebra em duas linhas sem estourar', (
    tester,
  ) async {
    await _pumpBar(tester, width: 360);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a busca devolve o texto digitado', (tester) async {
    String? digitado;
    await _pumpBar(
      tester,
      width: 1400,
      onSearchChanged: (value) => digitado = value,
    );

    await tester.enterText(find.byType(TextField), 'maria');
    expect(digitado, 'maria');
  });

  testWidgets('a acao primaria dispara no toque', (tester) async {
    var tocou = false;
    await _pumpBar(tester, width: 1400, onPrimary: () => tocou = true);

    await tester.tap(find.text('Novo aluno'));
    await tester.pumpAndSettle();

    expect(tocou, isTrue);
  });

  testWidgets('a busca nao fixa fundo claro no tema escuro', (tester) async {
    await _pumpBar(tester, width: 1400, brightness: Brightness.dark);

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;

    // Um `fillColor` local aqui sobrescreveria o tema e devolveria a caixa
    // branca no escuro — a terceira raiz que o PR #83 varreu do app.
    expect(decoration.fillColor, isNull);
    expect(decoration.filled, isNull);
  });
}
