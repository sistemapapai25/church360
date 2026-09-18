import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

Color _labelColor(WidgetTester tester) {
  return tester.widget<Text>(find.byType(Text)).style!.color!;
}

void main() {
  testWidgets('exibe o rotulo em maiusculas', (tester) async {
    await tester.pumpWidget(
      _host(
        const StatusBadge(label: 'Ativo', tone: AppStatusTone.active),
        brightness: Brightness.light,
      ),
    );

    expect(find.text('ATIVO'), findsOneWidget);
  });

  testWidgets('desistente e neutro, nunca a cor de erro', (tester) async {
    await tester.pumpWidget(
      _host(
        const StatusBadge.dropped(label: 'Desistente'),
        brightness: Brightness.light,
      ),
    );

    final color = _labelColor(tester);
    expect(color, AppTheme.statusDropped);
    expect(color, isNot(AppTheme.errorColor));
  });

  testWidgets('no tema escuro o verde de ativo e clareado', (tester) async {
    await tester.pumpWidget(
      _host(
        const StatusBadge.active(label: 'Ativo'),
        brightness: Brightness.dark,
      ),
    );

    final darkColor = _labelColor(tester);
    // O token claro (#16A34A) sobre fundo escuro cai abaixo do contraste que
    // os badges do app ja exigem — o escuro tem que clarear.
    expect(darkColor, isNot(AppTheme.statusActive));
    expect(
      HSLColor.fromColor(darkColor).lightness,
      greaterThan(HSLColor.fromColor(AppTheme.statusActive).lightness),
    );
  });

  testWidgets('concluido usa o par escuro do tema', (tester) async {
    await tester.pumpWidget(
      _host(
        const StatusBadge.done(label: 'Concluido'),
        brightness: Brightness.dark,
      ),
    );

    expect(_labelColor(tester), AppTheme.statusDoneDark);
  });
}
