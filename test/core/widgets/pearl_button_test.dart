import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/pearl_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ação Pearl pode ser acionada por teclado', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PearlButton(
            color: AppTheme.primary,
            onTap: () => count++,
            child: const Text('Cadastrar'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(count, 1);
  });
}
