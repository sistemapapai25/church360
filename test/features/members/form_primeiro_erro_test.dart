import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church360_app/features/members/presentation/screens/member_form_screen.dart';

void main() {
  testWidgets('acha o 1º campo com erro e rola até ele', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(key: const Key('ok'), validator: (_) => null),
                  const SizedBox(height: 2000),
                  TextFormField(key: const Key('cpf'), validator: (_) => 'CPF'),
                  TextFormField(key: const Key('cep'), validator: (_) => 'CEP'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(primeiroCampoComErro(formKey.currentContext!), isNull);

    formKey.currentState!.validate();
    await tester.pump();
    final alvo = primeiroCampoComErro(formKey.currentContext!);
    expect(alvo?.widget.key, const Key('cpf'));

    Scrollable.ensureVisible(alvo!);
    await tester.pumpAndSettle();
    expect(find.text('CPF'), findsOneWidget);
  });
}
