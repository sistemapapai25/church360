import 'package:church360_app/features/courses/domain/models/course_subject.dart';
import 'package:church360_app/features/courses/presentation/turma/teaching_plan.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
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
