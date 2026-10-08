import 'package:church360_app/features/courses/domain/models/course_subject.dart';
import 'package:church360_app/features/courses/presentation/turma/professor_aula.dart';
import 'package:church360_app/features/courses/presentation/turma/teaching_plan.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
import 'package:church360_app/features/study_groups/domain/models/teaching_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

CourseSubject subject(String id, int count, {String? teacher}) => CourseSubject(
  id: id,
  courseId: 'c',
  title: id,
  lessonCount: count,
  defaultTeacherId: teacher,
);

StudyLesson lesson(
  int number, {
  String? subjectId,
  DateTime? date,
  String? time,
}) => StudyLesson(
  id: 'l$number',
  studyGroupId: 'g',
  lessonNumber: number,
  title: 'Aula $number',
  status: LessonStatus.draft,
  scheduledDate: date,
  startTime: time,
  subjectId: subjectId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('planLessons', () {
    test('bloco 19:30, 15 min, intervalo 0 e 5', () {
      final subjects = [subject('Doutrina', 3)];
      String times(int interval) => planLessons(
        subjects: subjects,
        lessons: const [],
        start: 19 * 60 + 30,
        duration: 15,
        interval: interval,
      ).map((p) => hhmm(p.start)).join(' ');

      expect(times(0), '19:30 19:45 20:00');
      expect(times(5), '19:30 19:50 20:10');
    });

    test('cria só a diferença, na ordem das matérias, após o maior número', () {
      final planned = planLessons(
        subjects: [subject('Doutrina', 4), subject('Batismo', 1)],
        lessons: [
          lesson(1, subjectId: 'Doutrina'),
          lesson(2, subjectId: 'Doutrina'),
          lesson(7),
        ],
        start: 0,
        duration: 10,
      );
      expect(planned.map((p) => '${p.lessonNumber} ${p.title}'), [
        '8 Doutrina — 3/4',
        '9 Doutrina — 4/4',
        '10 Batismo — 1/1',
      ]);
    });

    test('matéria completa não gera nada', () {
      expect(
        planLessons(
          subjects: [subject('A', 1)],
          lessons: [lesson(1, subjectId: 'A')],
          start: 0,
          duration: 10,
        ),
        isEmpty,
      );
    });

    test('planEnd acusa bloco que passa da meia-noite', () {
      final planned = planLessons(
        subjects: [subject('A', 2)],
        lessons: const [],
        start: 23 * 60 + 30,
        duration: 20,
      );
      expect(planEnd(planned, 20), greaterThan(24 * 60));
    });
  });

  group('planEventLessons', () {
    Event meeting(String id, int day, {int minutes = 90}) => Event(
      id: id,
      name: 'Encontro',
      eventType: 'aula',
      startDate: DateTime(2026, 10, day, 19),
      endDate: DateTime(2026, 10, day, 19).add(Duration(minutes: minutes)),
      createdAt: DateTime(2026),
    );

    String plan(List<StudyLesson> lessons, List<Event> events) =>
        planEventLessons(
              subjects: [subject('A', 2), subject('B', 1), subject('C', 2)],
              lessons: lessons,
              events: events,
            )
            .map(
              (r) =>
                  '${r.date.day} ${hhmm(r.lesson.start)}+${r.duration} '
                  '${r.lesson.title}',
            )
            .join(' | ');

    test('rodada por matéria; o horário divide entre as aulas do encontro', () {
      expect(
        plan(const [], [meeting('e1', 6), meeting('e2', 13)]),
        '6 19:00+30 A — 1/2 | 6 19:30+30 B — 1/1 | 6 20:00+30 C — 1/2 | '
        '13 19:00+45 A — 2/2 | 13 19:45+45 C — 2/2',
      );
    });

    test('23 tópicos em 10 encontros: 3,3,3 e depois 2, em sequência', () {
      final rows = planEventLessons(
        subjects: [for (var i = 1; i <= 23; i++) subject('T$i', 1)],
        lessons: const [],
        events: [for (var d = 1; d <= 10; d++) meeting('e$d', d)],
      );
      final perDay = <int, int>{};
      for (final r in rows) {
        perDay[r.date.day] = (perDay[r.date.day] ?? 0) + 1;
      }
      expect(perDay.values, [3, 3, 3, 2, 2, 2, 2, 2, 2, 2]);
      expect(rows.map((r) => r.lesson.subject.id).take(4), [
        'T1',
        'T2',
        'T3',
        'T4',
      ]);
      expect(rows.first.duration, 30);
    });

    test('encontro nunca leva duas aulas da mesma matéria', () {
      final rows = planEventLessons(
        subjects: [subject('A', 4)],
        lessons: const [],
        events: [meeting('e1', 6)],
      );
      expect(rows.map((r) => r.lesson.title), ['A — 1/4']);
    });

    test('encontro que já tem aula da turma e encontro sem término pulam', () {
      final done = lesson(1, subjectId: 'A');
      final linked = StudyLesson.fromJson({...done.toJson(), 'event_id': 'e1'});
      final open = Event(
        id: 'e2',
        name: 'Sem fim',
        eventType: 'aula',
        startDate: DateTime(2026, 10, 13, 19),
        createdAt: DateTime(2026),
      );
      expect(
        plan([linked], [meeting('e1', 6), open, meeting('e3', 20)]),
        '20 19:00+30 A — 2/2 | 20 19:30+30 B — 1/1 | 20 20:00+30 C — 1/2',
      );
    });
  });

  test('Agenda: aula cujo encontro está na lista não aparece de novo', () {
    TeachingLesson mine(String id, String? eventId) => TeachingLesson(
      id: id,
      studyGroupId: 'g',
      lessonNumber: 1,
      title: id,
      scheduledDate: DateTime(2026, 10, 13),
      status: LessonStatus.published,
      turmaName: 'T',
      eventId: eventId,
    );
    final shown = Event(
      id: 'e1',
      name: 'Aula · T',
      eventType: 'aula',
      startDate: DateTime(2026, 10, 13, 19),
      createdAt: DateTime(2026),
    );
    expect(
      lessonsOutsideEvents(
        [
          mine('no-encontro', 'e1'),
          mine('encontro-oculto', 'e9'),
          mine('sem-encontro', null),
        ],
        [shown],
      ).map((l) => l.id),
      ['encontro-oculto', 'sem-encontro'],
    );
  });

  group('assignTeachers', () {
    const empty = (current: null, subjectDefault: null);

    test('5 aulas, G/D/B → G, D, B, G, D', () {
      final r = assignTeachers(
        List.filled(5, empty),
        eligible: {'G', 'D', 'B'},
        rotation: ['G', 'D', 'B'],
      );
      expect(r.map((e) => e.teacherId).join(), 'GDBGD');
      expect(r.every((e) => e.source == TeacherSource.rotation), isTrue);
    });

    test('manual nunca muda; padrão só se elegível; rodízio equilibra', () {
      final r = assignTeachers(
        [
          (current: 'X', subjectDefault: 'G'),
          (current: null, subjectDefault: 'G'),
          (current: null, subjectDefault: 'Fora'),
          empty,
        ],
        eligible: {'G', 'D'},
        rotation: ['G', 'D'],
      );
      expect(r.map((e) => e.teacherId), ['X', 'G', 'D', 'G']);
      expect(r.map((e) => e.source), [
        TeacherSource.kept,
        TeacherSource.subjectDefault,
        TeacherSource.rotation,
        TeacherSource.rotation,
      ]);
    });

    test('curso sem ministério: sem rodízio, o resto fica vazio', () {
      final r = assignTeachers(
        [(current: null, subjectDefault: 'G'), empty],
        eligible: {'G'},
        rotation: const [],
      );
      expect(r.map((e) => e.teacherId), ['G', null]);
      expect(r.last.source, TeacherSource.none);
    });
  });

  test('lessonsInScheduleOrder: data, horário, número; sem data no fim', () {
    final ordered = lessonsInScheduleOrder([
      lesson(1),
      lesson(2, date: DateTime(2026, 10, 5), time: '20:00'),
      lesson(3, date: DateTime(2026, 10, 5), time: '19:30'),
      lesson(4, date: DateTime(2026, 10, 4)),
    ]);
    expect(ordered.map((l) => l.lessonNumber), [4, 3, 2, 1]);
  });
}
