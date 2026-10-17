import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/courses/domain/models/course_lesson.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_lesson_notes_section.dart';

Widget _host(List<CourseLessonNote> notes) => ProviderScope(
  overrides: [
    courseLessonNotesProvider.overrideWith((ref, id) async => notes),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CourseLessonNotesSection(lessonId: 'l1'),
      ),
    ),
  ),
);

void main() {
  testWidgets('sem anotação: campo e aviso de vazio', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Minhas anotações'), findsOneWidget);
    expect(find.byKey(const ValueKey('curso-nota-campo')), findsOneWidget);
    expect(find.text('Nenhuma anotação ainda.'), findsOneWidget);
  });

  testWidgets('lista as anotações com botão de apagar', (tester) async {
    await tester.pumpWidget(
      _host([
        (id: 'n1', body: 'Ler Romanos 8', createdAt: DateTime(2026, 10, 17)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ler Romanos 8'), findsOneWidget);
    expect(find.byKey(const ValueKey('curso-nota-n1')), findsOneWidget);
    expect(find.byTooltip('Apagar'), findsOneWidget);
    expect(find.text('Nenhuma anotação ainda.'), findsNothing);
  });
}
