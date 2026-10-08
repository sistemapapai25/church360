import 'package:church360_app/features/legal/terms_acceptance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(DateTime? acceptedAt) {
  return ProviderScope(
    overrides: [
      currentTermsAcceptanceProvider.overrideWith((ref) async => acceptedAt),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => askTermsAcceptanceIfPending(context, ref),
            child: const Text('entrar'),
          ),
        ),
      ),
    ),
  );
}

// A ordem importa: o "uma vez por sessão" é estado do app inteiro.
void main() {
  testWidgets('quem já aceitou a versão atual não é perguntado', (
    tester,
  ) async {
    await tester.pumpWidget(_host(DateTime(2026, 10, 8)));
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Li e aceito'), findsNothing);
  });

  testWidgets('pendente: pergunta e deixa adiar', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Li e aceito'), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(find.text('Li e aceito'), findsNothing);
  });

  testWidgets('adiado: não pergunta de novo na mesma sessão', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Li e aceito'), findsNothing);
  });
}
