import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/schedule/domain/auto_scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

MinistrySchedule _s(String eventId, int day, String uid) => MinistrySchedule(
  id: '',
  eventId: eventId,
  eventName: '',
  eventStartDate: DateTime.utc(2026, 10, day, 20),
  ministryId: 'm',
  ministryName: '',
  memberId: uid,
  memberName: '',
  createdAt: DateTime.utc(2026),
);

void main() {
  // Quarta 07, domingo 11, quarta 14: seguidos são eventos do ministério,
  // não "escala nos últimos 9 dias".
  final history = [
    _s('qua07', 7, 'renato'),
    _s('dom11', 11, 'dudu'),
  ];

  test('quem pulou o evento anterior não está em sequência', () {
    expect(consecutiveStreak('renato', 'qua14', DateTime.utc(2026, 10, 14, 20), history), 0);
  });

  test('quem tocou no evento anterior está em sequência', () {
    expect(consecutiveStreak('dudu', 'qua14', DateTime.utc(2026, 10, 14, 20), history), 1);
  });

  test('sequência conta eventos seguidos e ignora o próprio evento e os futuros', () {
    final h = [
      ...history,
      _s('dom11', 11, 'renato'),
      _s('qua14', 14, 'renato'),
      _s('dom18', 18, 'renato'),
    ];
    expect(consecutiveStreak('renato', 'qua14', DateTime.utc(2026, 10, 14, 20), h), 2);
  });
}
