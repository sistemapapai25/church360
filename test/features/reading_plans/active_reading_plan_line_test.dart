import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/reading_plans/domain/models/reading_plan.dart';
import 'package:church360_app/features/reading_plans/presentation/widgets/active_reading_plan_line.dart';

void main() {
  ReadingPlan plan({int modules = 0, int duration = 365}) => ReadingPlan(
    id: 'p1',
    title: 'Bíblia em 1 ano',
    durationDays: duration,
    modules: [
      for (var i = 1; i <= modules; i++)
        ReadingPlanModule(order: i, title: 'Dia $i'),
    ],
    createdAt: DateTime(2026, 10, 14),
  );

  ReadingPlanProgress progress(int day) => ReadingPlanProgress(
    planId: 'p1',
    memberId: 'm1',
    startedAt: DateTime(2026, 10, 1),
    currentDay: day,
  );

  testWidgets('mostra "Dia N de T · Ler hoje" e abre o módulo do dia', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveReadingPlanLine(
            data: (plan: plan(modules: 365), progress: progress(37)),
            onNavigate: (route) => opened = route,
          ),
        ),
      ),
    );

    expect(find.text('Bíblia em 1 ano'), findsOneWidget);
    expect(find.text('Dia 37 de 365 · Ler hoje'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('active-reading-plan-line')));
    expect(opened, '/reading-plans/p1/modules/37');
  });

  test('dia a abrir fica entre 1 e o total do plano', () {
    expect(
      ActiveReadingPlanLine.dayToOpen((plan: plan(), progress: progress(400))),
      365,
    );
    expect(
      ActiveReadingPlanLine.dayToOpen((plan: plan(), progress: progress(0))),
      1,
    );
    // Sem módulos, a duração em dias manda (como no detalhe do plano).
    expect(
      ActiveReadingPlanLine.dayToOpen((
        plan: plan(duration: 40),
        progress: progress(12),
      )),
      12,
    );
  });
}
