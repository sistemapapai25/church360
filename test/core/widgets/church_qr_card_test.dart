// QR E1 (roadmap QR 19/10/2026 §2.3): cartão único do QR. Ações por tipo,
// sem padrão universal; validade com "Código vencido".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:church360_app/core/widgets/church_qr_card.dart';
import 'package:church360_app/features/church_info/domain/models/church_info.dart';
import 'package:church360_app/features/church_info/presentation/providers/church_info_provider.dart';

Widget _app(Widget child, {ChurchInfo? church}) => ProviderScope(
  overrides: [churchInfoProvider.overrideWith((ref) async => church)],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(child: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  testWidgets(
    'sem ações por padrão (credencial); fundo branco no tema escuro',
    (tester) async {
      await tester.pumpWidget(
        _app(const ChurchQrCard(data: 'x', title: 'Kids')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Compartilhar'), findsNothing);
      expect(find.text('Imprimir'), findsNothing);
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, Colors.white);
      expect(
        qr.errorCorrectionLevel,
        QrErrorCorrectLevel.M,
        reason: 'sem logo',
      );
    },
  );

  testWidgets('link público mostra Compartilhar e Imprimir', (tester) async {
    await tester.pumpWidget(
      _app(
        const ChurchQrCard(
          data: 'https://papai.church360.com.br/events/1',
          title: 'Evento',
          actions: {ChurchQrAction.share, ChurchQrAction.print},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
  });

  testWidgets('com logo usa correção H; logo quebrada não derruba o cartão', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ChurchQrCard(data: 'x', title: 'Evento'),
        church: ChurchInfo(
          id: '1',
          name: 'Igreja Teste',
          logoUrl: 'https://invalido.example/logo.png',
          createdAt: DateTime(2026),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
    expect(tester.takeException(), isNull);
    expect(find.text('Evento'), findsOneWidget);
  });

  testWidgets('validade: mostra o horário e, vencido, apaga o código', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ChurchQrCard(
          data: 'x',
          title: 'Kids',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          onRefresh: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Código vencido'), findsOneWidget);
    expect(find.textContaining('Venceu às'), findsOneWidget);
    expect(find.text('Gerar outro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
