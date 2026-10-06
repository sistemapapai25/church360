import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/courses/presentation/turma/tabs/turma_aulas_tab.dart';

void main() {
  group('lessonRepeatDates', () {
    test('toda terça por 30 dias', () {
      final dates = lessonRepeatDates(
        start: DateTime(2026, 10, 6), // terça
        until: DateTime(2026, 11, 5),
        weekdays: {DateTime.tuesday},
      );
      expect(dates, [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 3),
      ]);
    });

    test('primeira data no meio da semana não pega dia anterior', () {
      final dates = lessonRepeatDates(
        start: DateTime(2026, 10, 7), // quarta
        until: DateTime(2026, 10, 20),
        weekdays: {DateTime.tuesday, DateTime.thursday},
      );
      expect(dates, [
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 20),
      ]);
    });

    test('a cada 2 semanas conta da semana da primeira data', () {
      final dates = lessonRepeatDates(
        start: DateTime(2026, 10, 6),
        until: DateTime(2026, 11, 10),
        weekdays: {DateTime.tuesday},
        intervalWeeks: 2,
      );
      expect(dates, [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 20),
        DateTime(2026, 11, 3),
      ]);
    });

    test('para logo depois do teto', () {
      final dates = lessonRepeatDates(
        start: DateTime(2026, 1, 1),
        until: DateTime(2027, 1, 1),
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(dates.length, lessonRepeatMax + 1);
    });
  });
}
