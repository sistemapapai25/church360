// B6 (roadmap Home/culto/Dashboard, 14/10/2026): o botão flutuante do
// Leitor de QR Code arrasta, guarda a posição, vira aba ao segurar (ou ao
// sair pela lateral) e volta ao tocar na aba.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/widgets/qr_scanner_fab.dart';

Widget _app({VoidCallback? onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          const Center(child: Text('corpo')),
          QrScannerFab(onTap: onTap),
        ],
      ),
    ),
  );
}

Offset _topLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byIcon(AppIcons.qrCode).first);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('aparece no canto inferior esquerdo e abre ao tocar', (
    tester,
  ) async {
    var aberto = 0;
    await tester.pumpWidget(_app(onTap: () => aberto++));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.qrCode), findsOneWidget);
    final pos = _topLeft(tester);
    expect(pos.dx, lessThan(400), reason: 'lado esquerdo (viewport 800)');
    expect(pos.dy, greaterThan(300), reason: 'metade de baixo (viewport 600)');

    await tester.tap(find.byIcon(AppIcons.qrCode));
    expect(aberto, 1);
  });

  testWidgets('arrastar move e guarda a posição', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final antes = _topLeft(tester);

    await tester.drag(find.byIcon(AppIcons.qrCode), const Offset(200, -150));
    await tester.pumpAndSettle();

    // O reconhecedor de pan só aceita depois da folga de toque (kPanSlop);
    // o que importa é mover na direção do dedo e gravar.
    final depois = _topLeft(tester);
    expect(depois.dx - antes.dx, closeTo(200, 40));
    expect(depois.dy - antes.dy, closeTo(-150, 40));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(QrScannerFab.prefX), isNotNull);
    expect(prefs.getDouble(QrScannerFab.prefY), isNotNull);
  });

  testWidgets('segurar esconde na aba; tocar na aba traz de volta', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(AppIcons.qrCode));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.qrCode), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(QrScannerFab.prefHidden),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.qrCode), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('arrastar para fora da lateral direita vira aba na direita', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byIcon(AppIcons.qrCode), const Offset(900, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.qrCode), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('abre escondido quando a preferência diz', (tester) async {
    SharedPreferences.setMockInitialValues({QrScannerFab.prefHidden: true});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.qrCode), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
