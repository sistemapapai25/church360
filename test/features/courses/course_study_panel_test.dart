import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/courses/domain/models/course_lesson.dart';
import 'package:church360_app/features/courses/domain/models/course_progress.dart';
import 'package:church360_app/features/courses/domain/models/course_subject.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_study_panel.dart';

CourseLesson _lesson(String id, int i, {String? subject, int? seconds}) =>
    CourseLesson(
      id: id,
      courseId: 'c1',
      title: 'Aula $id',
      orderIndex: i,
      subjectId: subject,
      videoDuration: seconds,
      createdAt: DateTime(2026, 10, 1),
    );

const _subjects = [
  CourseSubject(id: 's1', courseId: 'c1', title: 'Fundamentos', lessonCount: 2),
  CourseSubject(id: 's2', courseId: 'c1', title: 'Prática', lessonCount: 1),
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('anel, módulos e "Continuar de onde parou"', (tester) async {
    final lessons = [
      _lesson('l1', 0, subject: 's1', seconds: 600),
      _lesson('l2', 1, subject: 's1', seconds: 900),
      _lesson('l3', 2, subject: 's2', seconds: 300),
    ];
    String? opened;
    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: lessons,
          subjects: _subjects,
          progress: const CourseProgress(
            courseId: 'c1',
            total: 3,
            done: 1,
            resumeLessonId: 'l2',
            resumePositionS: 120,
          ),
          lessonProgress: {
            'l1': LessonProgress(
              lessonId: 'l1',
              completedAt: DateTime(2026, 10, 2),
            ),
          },
          onNavigate: (route) => opened = route,
        ),
      ),
    );

    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1 de 3 aulas concluídas'), findsOneWidget);
    expect(find.text('2 módulos · 3 aulas · 30min'), findsOneWidget);
    expect(find.text('Módulo 1 · Fundamentos'), findsOneWidget);
    expect(find.text('Módulo 2 · Prática'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Continuar de onde parou'));
    expect(opened, '/courses/c1/lessons/l2/view');

    await tester.ensureVisible(find.byKey(const ValueKey('lesson-l3')));
    await tester.tap(find.byKey(const ValueKey('lesson-l3')));
    expect(opened, '/courses/c1/lessons/l3/view');
  });

  testWidgets('sem matéria é módulo único; "Começar" e "Tudo concluído"', (
    tester,
  ) async {
    final lessons = [_lesson('l1', 0), _lesson('l2', 1)];
    String? opened;
    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: lessons,
          subjects: const [],
          progress: null,
          lessonProgress: const {},
          onNavigate: (route) => opened = route,
        ),
      ),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('1 módulo · 2 aulas'), findsOneWidget);
    expect(find.textContaining('Módulo 1'), findsNothing);
    await tester.tap(find.text('Começar'));
    expect(opened, '/courses/c1/lessons/l1/view');

    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: lessons,
          subjects: const [],
          progress: const CourseProgress(courseId: 'c1', total: 2, done: 2),
          lessonProgress: {
            for (final l in lessons)
              l.id: LessonProgress(
                lessonId: l.id,
                completedAt: DateTime(2026, 10, 2),
              ),
          },
          onNavigate: (route) => opened = route,
        ),
      ),
    );

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Curso concluído'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('course-resume')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Tudo concluído'), findsOneWidget);
  });

  test('modulesOf: aula sem matéria vai para "Outras aulas"', () {
    final modules = CourseStudyPanel.modulesOf([
      _lesson('l1', 0, subject: 's1'),
      _lesson('l2', 1),
    ], _subjects);
    expect(modules.map((m) => m.title), ['Fundamentos', 'Outras aulas']);
    expect(modules.last.lessons.single.id, 'l2');
  });
}
