import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/screens/events_list_screen.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
import 'package:church360_app/features/study_groups/domain/models/teaching_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

TeachingLesson _lesson(String date, [String? start, int? minutes]) =>
    TeachingLesson.fromJson({
      'id': 'l-$date-$start',
      'study_group_id': 'g',
      'lesson_number': 1,
      'title': 'Doutrina — 1/4',
      'scheduled_date': date,
      'start_time': start,
      'duration_minutes': minutes,
      'status': 'draft',
      'turma_name': 'Turma Março',
    });

Event _event(String startUtc) => Event.fromJson({
  'id': 'e-$startUtc',
  'name': 'Culto',
  'start_date': startUtc,
  'created_at': startUtc,
});

void main() {
  // Agora = 08/10/2026 19:00 no relógio de parede.
  final now = DateTime(2026, 10, 8, 19);

  group('TeachingLesson.isUpcoming (regra de Próximos Eventos)', () {
    test('dia seguinte entra; dia anterior sai', () {
      expect(_lesson('2026-10-09', '08:00').isUpcoming(now), isTrue);
      expect(_lesson('2026-10-07', '23:00').isUpcoming(now), isFalse);
    });

    test('hoje: entra até a hora de começar, sai depois', () {
      expect(_lesson('2026-10-08', '19:30').isUpcoming(now), isTrue);
      expect(_lesson('2026-10-08', '19:00').isUpcoming(now), isTrue);
      expect(_lesson('2026-10-08', '18:59').isUpcoming(now), isFalse);
    });

    test('hoje sem horário fica até o fim do dia', () {
      expect(_lesson('2026-10-08').isUpcoming(now), isTrue);
    });
  });

  test('timeRange e status vêm da RPC', () {
    final l = _lesson('2026-10-08', '19:30', 15);
    expect(l.timeRange, '19:30–19:45');
    expect(l.status, LessonStatus.draft);
    expect(l.startsAt, DateTime.utc(2026, 10, 8, 19, 30));
  });

  test('mergeByStart intercala pela hora; empate deixa o evento antes', () {
    final culto = _event('2026-10-08T19:30:00.000Z');
    final domingo = _event('2026-10-11T10:00:00.000Z');
    final antes = _lesson('2026-10-08', '19:00');
    final empate = _lesson('2026-10-08', '19:30');
    final depois = _lesson('2026-10-12', '20:00');

    expect(mergeByStart([culto, domingo], [antes, empate, depois]), [
      antes,
      culto,
      empate,
      domingo,
      depois,
    ]);
    expect(mergeByStart([culto], const []), [culto]);
  });
}
