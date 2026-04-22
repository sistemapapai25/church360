import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/reading_plans/domain/models/reading_plan.dart';

void main() {
  group('ReadingPlan', () {
    test('totalModules uses durationDays when modules is empty', () {
      final plan = ReadingPlan(
        id: 'plan-1',
        title: 'Plano',
        durationDays: 60,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(plan.hasModules, isFalse);
      expect(plan.totalModules, 60);
    });

    test('totalModules uses modules length when configured', () {
      final plan = ReadingPlan(
        id: 'plan-2',
        title: 'Plano',
        durationDays: 60,
        modules: const [
          ReadingPlanModule(order: 1, title: 'Dia 1'),
          ReadingPlanModule(order: 2, title: 'Dia 2'),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      expect(plan.hasModules, isTrue);
      expect(plan.totalModules, 2);
    });
  });

  group('ReadingPlanModule', () {
    test('fromJson uses fallback order/title when missing', () {
      final module = ReadingPlanModule.fromJson({}, fallbackOrder: 3);
      expect(module.order, 3);
      expect(module.title, 'Módulo 3');
      expect(module.reference, isNull);
      expect(module.content, isNull);
    });
  });
}

