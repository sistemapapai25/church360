import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/devotionals/presentation/providers/devotional_provider.dart';
import 'package:church360_app/features/edificacao/edificacao_screen.dart';
import 'package:church360_app/features/reading_plans/presentation/providers/reading_plans_provider.dart';

void main() {
  testWidgets('C3: abas Devocionais e Planos trocam a tela', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDevotionalsProvider.overrideWith((ref) async => []),
          activeReadingPlansProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EdificacaoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum devocional encontrado'), findsOneWidget);

    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano disponível'), findsOneWidget);
    expect(find.text('Nenhum devocional encontrado'), findsNothing);
  });
}
