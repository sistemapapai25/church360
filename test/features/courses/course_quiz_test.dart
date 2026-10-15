import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/courses/domain/certificate_pdf.dart';
import 'package:church360_app/features/courses/domain/models/course_lesson.dart';
import 'package:church360_app/features/courses/domain/models/course_progress.dart';
import 'package:church360_app/features/courses/domain/models/course_quiz.dart';
import 'package:church360_app/features/courses/domain/models/course_subject.dart';
import 'package:church360_app/features/courses/presentation/screens/quiz_screen.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_study_panel.dart';

CourseLesson _lesson(String id, int i, {String? subject}) => CourseLesson(
  id: id,
  courseId: 'c1',
  title: 'Aula $id',
  orderIndex: i,
  subjectId: subject,
  createdAt: DateTime(2026, 10, 1),
);

LessonProgress _done(String id) =>
    LessonProgress(lessonId: id, completedAt: DateTime(2026, 10, 2));

const _subjects = [
  CourseSubject(id: 's1', courseId: 'c1', title: 'Fundamentos', lessonCount: 2),
  CourseSubject(id: 's2', courseId: 'c1', title: 'Prática', lessonCount: 1),
];

final _lessons = [
  _lesson('l1', 0, subject: 's1'),
  _lesson('l2', 1, subject: 's1'),
  _lesson('l3', 2, subject: 's2'),
];

const _quizzes = [
  CourseQuiz(id: 'q1', courseId: 'c1', subjectId: 's1', title: 'Prova 1'),
  CourseQuiz(id: 'qf', courseId: 'c1', title: 'Prova final'),
];

QuizAttempt _attempt(String quiz, int score, bool passed) => QuizAttempt(
  id: 'a-$quiz',
  quizId: quiz,
  score: score,
  passed: passed,
  createdAt: DateTime(2026, 10, 3),
);

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('locksOf (E3)', () {
    final modules = CourseStudyPanel.modulesOf(_lessons, _subjects);

    test('curso livre não tranca nada', () {
      final locks = CourseStudyPanel.locksOf(
        sequential: false,
        modules: modules,
        quizzes: _quizzes,
        lessonProgress: const {},
        attempts: const {},
      );
      expect(locks.lessons, isEmpty);
      expect(locks.quizzes, isEmpty);
    });

    test('sequencial: só a 1ª aula abre; provas trancadas', () {
      final locks = CourseStudyPanel.locksOf(
        sequential: true,
        modules: modules,
        quizzes: _quizzes,
        lessonProgress: const {},
        attempts: const {},
      );
      expect(locks.lessons, {'l2', 'l3'});
      expect(locks.quizzes, {'q1', 'qf'});
    });

    test('módulo 1 feito sem a prova: a prova abre, a aula 3 não', () {
      final locks = CourseStudyPanel.locksOf(
        sequential: true,
        modules: modules,
        quizzes: _quizzes,
        lessonProgress: {'l1': _done('l1'), 'l2': _done('l2')},
        attempts: {'q1': _attempt('q1', 50, false)},
      );
      expect(locks.lessons, {'l3'});
      expect(locks.quizzes, {'qf'});
    });

    test('prova aprovada libera o módulo 2; tudo feito libera a final', () {
      final locks = CourseStudyPanel.locksOf(
        sequential: true,
        modules: modules,
        quizzes: _quizzes,
        lessonProgress: {
          'l1': _done('l1'),
          'l2': _done('l2'),
          'l3': _done('l3'),
        },
        attempts: {'q1': _attempt('q1', 100, true)},
      );
      expect(locks.lessons, isEmpty);
      expect(locks.quizzes, isEmpty);
    });
  });

  testWidgets('painel: prova, cadeado, "Fazer a prova" e certificado', (
    tester,
  ) async {
    String? opened;
    var issued = false;
    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: _lessons,
          subjects: _subjects,
          progress: const CourseProgress(courseId: 'c1', total: 3, done: 2),
          lessonProgress: {'l1': _done('l1'), 'l2': _done('l2')},
          quizzes: _quizzes,
          attempts: {'q1': _attempt('q1', 50, false)},
          sequential: true,
          onNavigate: (route) => opened = route,
          onIssueCertificate: () => issued = true,
        ),
      ),
    );

    expect(find.text('Reprovado · 50% · toque para refazer'), findsOneWidget);
    expect(find.text('Conclua a etapa anterior para abrir'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));

    await tester.tap(find.text('Fazer a prova: Prova 1'));
    expect(opened, '/courses/c1/quiz/q1');

    await tester.ensureVisible(find.byKey(const ValueKey('quiz-q1')));
    await tester.tap(find.byKey(const ValueKey('quiz-q1')));
    expect(opened, '/courses/c1/quiz/q1');

    // Aula trancada não navega.
    opened = null;
    await tester.ensureVisible(find.byKey(const ValueKey('lesson-l3')));
    await tester.tap(find.byKey(const ValueKey('lesson-l3')));
    expect(opened, isNull);

    // Certificado ainda não elegível: sem botão.
    expect(find.text('Emitir'), findsNothing);
    expect(issued, isFalse);
  });

  testWidgets('painel: tudo feito emite; emitido abre /certificado', (
    tester,
  ) async {
    String? opened;
    var issued = false;
    final all = {
      'l1': _done('l1'),
      'l2': _done('l2'),
      'l3': _done('l3'),
    };
    final passed = {
      'q1': _attempt('q1', 100, true),
      'qf': _attempt('qf', 80, true),
    };
    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: _lessons,
          subjects: _subjects,
          progress: const CourseProgress(courseId: 'c1', total: 3, done: 3),
          lessonProgress: all,
          quizzes: _quizzes,
          attempts: passed,
          onNavigate: (route) => opened = route,
          onIssueCertificate: () => issued = true,
        ),
      ),
    );
    expect(find.text('Aprovado · 80%'), findsOneWidget);
    await tester.ensureVisible(find.text('Emitir'));
    await tester.tap(find.text('Emitir'));
    expect(issued, isTrue);

    await tester.pumpWidget(
      _host(
        CourseStudyPanel(
          courseId: 'c1',
          lessons: _lessons,
          subjects: _subjects,
          progress: const CourseProgress(courseId: 'c1', total: 3, done: 3),
          lessonProgress: all,
          quizzes: _quizzes,
          attempts: passed,
          certificate: CourseCertificate(
            code: 'ABCD-1234-EF56',
            courseId: 'c1',
            issuedAt: DateTime(2026, 10, 15),
          ),
          onNavigate: (route) => opened = route,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Ver'));
    await tester.tap(find.text('Ver'));
    expect(opened, '/certificado/ABCD-1234-EF56');
  });

  testWidgets('QuizTaker: uma questão por vez e envia {id: índice}', (
    tester,
  ) async {
    Map<String, int>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizTaker(
            questions: const [
              QuizQuestion(
                id: 'x',
                orderIndex: 0,
                text: 'Primeira?',
                options: ['a', 'b'],
              ),
              QuizQuestion(
                id: 'y',
                orderIndex: 1,
                text: 'Segunda?',
                options: ['c', 'd', 'e'],
              ),
            ],
            passScore: 70,
            onSubmit: (answers) => sent = answers,
          ),
        ),
      ),
    );
    expect(find.text('Questão 1 de 2'), findsOneWidget);
    expect(find.text('Segunda?'), findsNothing);
    // Sem resposta o botão fica desabilitado.
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await tester.pump();
    expect(find.text('Questão 1 de 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('option-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await tester.pump();
    expect(find.text('Segunda?'), findsOneWidget);
    expect(find.text('Enviar respostas'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('option-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    expect(sent, {'x': 1, 'y': 2});
  });

  testWidgets('QuizResultView mostra nota, gabarito e explicação', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizResultView(
            questions: const [
              QuizQuestion(
                id: 'x',
                orderIndex: 0,
                text: 'Primeira?',
                options: ['a', 'b'],
              ),
            ],
            result: const QuizResult(
              score: 0,
              passed: false,
              passScore: 70,
              total: 1,
              correct: 0,
              questions: [
                QuizCorrection(
                  questionId: 'x',
                  chosen: 0,
                  correctIndex: 1,
                  explanation: 'porque b',
                ),
              ],
            ),
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Sua resposta: a'), findsOneWidget);
    expect(find.text('Resposta certa: b'), findsOneWidget);
    expect(find.text('porque b'), findsOneWidget);
    expect(find.text('Refazer'), findsOneWidget);
  });

  test('PDF do certificado gera bytes (Latin-1 saneado)', () async {
    final bytes = await buildCertificatePdf(
      CertificateInfo(
        code: 'ABCD-1234-EF56',
        personName: 'Maria — Teste',
        courseTitle: 'Curso “Gravado”',
        churchName: 'Igreja Papai',
        issuedAt: DateTime(2026, 10, 15),
      ),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
