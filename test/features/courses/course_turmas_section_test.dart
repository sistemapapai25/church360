import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/domain/models/course_lesson.dart';
import 'package:church360_app/features/courses/domain/models/course_turma.dart';
import 'package:church360_app/features/courses/presentation/hub/course_hub.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/screens/course_viewer_screen.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_turmas_section.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';

const _courseId = 'course-1';

Course _course({CourseType type = CourseType.onlineRecorded}) {
  return Course(
    id: _courseId,
    title: 'Batismo',
    courseType: type,
    createdAt: DateTime(2026, 9, 1),
  );
}

CourseLesson _lesson() {
  return CourseLesson(
    id: 'lesson-1',
    courseId: _courseId,
    title: 'O que é o batismo',
    orderIndex: 0,
    createdAt: DateTime(2026, 9, 1),
  );
}

final _baptismTurma = CourseTurma(
  id: 'sg-1',
  name: 'Turma de Setembro',
  status: StudyGroupStatus.active,
  startDate: DateTime(2026, 9, 6),
  endDate: DateTime(2026, 10, 25),
  ministryId: 'min-1',
  baptismTurmaId: 'bt-1',
  courseId: _courseId,
);

final _nativeTurma = CourseTurma(
  id: 'sg-2',
  name: 'Turma de Março',
  status: StudyGroupStatus.completed,
  startDate: DateTime(2026, 3, 1),
  courseId: _courseId,
);

/// Monta a tela do curso de verdade (não só a seção), para provar que a
/// seção de turmas não derruba capa, informações e aulas.
Widget _host({
  required AsyncValue<List<CourseTurma>> Function() turmas,
  List<CourseLesson> lessons = const [],
  CourseType type = CourseType.onlineRecorded,
  CourseHubState hub = const CourseHubState(management: true),
}) {
  final router = GoRouter(
    initialLocation: '/courses/$_courseId/view',
    routes: [
      GoRoute(
        path: '/courses/:id/view',
        builder: (context, state) =>
            CourseViewerScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/courses/:courseId/turmas/:studyGroupId',
        builder: (context, state) => Text(
          'turma ${state.pathParameters['courseId']}/${state.pathParameters['studyGroupId']}',
        ),
      ),
      GoRoute(
        path: '/ministries/:id/batismo',
        builder: (context, state) =>
            Text('batismo ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/study-groups/:id',
        builder: (context, state) =>
            Text('grupo ${state.pathParameters['id']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      courseByIdProvider(
        _courseId,
      ).overrideWith((ref) async => _course(type: type)),
      courseLessonsProvider(_courseId).overrideWith((ref) async => lessons),
      courseStudyGroupsProvider(_courseId).overrideWith((ref) async {
        final value = turmas();
        if (value is AsyncError) {
          throw value.error!;
        }
        return value.requireValue;
      }),
      courseHubProvider(_courseId).overrideWith((ref) async => hub),
      currentUserHasPermissionProvider(
        'courses.edit',
      ).overrideWith((ref) async => false),
      currentUserHasPermissionProvider(
        'courses.manage_lessons',
      ).overrideWith((ref) async => false),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  // A tela é um CustomScrollView com capa de 250px: em 800x600 a seção
  // de turmas fica abaixo da dobra.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('CourseTurma', () {
    test('turma de Batismo abre a rota canônica dentro de Cursos', () {
      expect(_baptismTurma.route, '/courses/$_courseId/turmas/sg-1');
    });

    test('grupo nativo abre a mesma rota canônica', () {
      expect(_nativeTurma.route, '/courses/$_courseId/turmas/sg-2');
    });

    // Gate 6: nenhum card leva mais para /ministries/...
    test('sem course_id a turma de Batismo não cai mais no ministério', () {
      final turma = CourseTurma.fromJson({
        'id': 'sg-4',
        'name': 'Antiga',
        'status': 'active',
        'ministry_id': 'min-1',
        'baptism_turma_id': 'bt-4',
      });
      expect(turma.route, '/study-groups/sg-4');
      expect(turma.route, isNot(contains('/ministries/')));
    });

    test('routeWithin usa o curso da seção quando a linha não traz', () {
      final turma = CourseTurma.fromJson({
        'id': 'sg-6',
        'name': 'Sem curso na linha',
        'status': 'active',
        'ministry_id': 'min-1',
        'baptism_turma_id': 'bt-6',
      });
      expect(turma.routeWithin('c-1'), '/courses/c-1/turmas/sg-6');
      expect(_baptismTurma.routeWithin('outro'), _baptismTurma.route);
    });

    test('fromJson lê course_id', () {
      final turma = CourseTurma.fromJson({
        'id': 'sg-5',
        'name': 'Com curso',
        'status': 'active',
        'course_id': 'c-9',
      });
      expect(turma.courseId, 'c-9');
      expect(turma.route, '/courses/c-9/turmas/sg-5');
    });

    test('baptism_turma_id sem ministry_id cai no detalhe do grupo', () {
      final turma = CourseTurma.fromJson({
        'id': 'sg-3',
        'name': 'Órfã',
        'status': 'active',
        'start_date': '2026-09-01',
        'end_date': null,
        'ministry_id': null,
        'baptism_turma_id': 'bt-3',
      });
      expect(turma.route, '/study-groups/sg-3');
    });

    test('fromJson tolera status e datas nulos', () {
      final turma = CourseTurma.fromJson({
        'id': 'sg-4',
        'name': 'Sem datas',
        'status': null,
        'start_date': null,
        'end_date': null,
      });
      expect(turma.status, StudyGroupStatus.active);
      expect(turma.startDate, isNull);
      expect(turma.endDate, isNull);
    });
  });

  testWidgets('lista as turmas do curso com status e datas', (tester) async {
    await _pump(
      tester,
      _host(
        turmas: () => AsyncData([_baptismTurma, _nativeTurma]),
        lessons: [_lesson()],
      ),
    );

    expect(find.byType(CourseTurmasSection), findsOneWidget);
    expect(find.text('Turmas'), findsOneWidget);
    expect(find.text('Turma de Setembro'), findsOneWidget);
    expect(find.text('Turma de Março'), findsOneWidget);
    expect(find.text('06/09/2026 a 25/10/2026'), findsOneWidget);
    expect(find.text('Início: 01/03/2026'), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.text('CONCLUÍDO'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CourseTurmasSection),
        matching: find.byType(StatusBadge),
      ),
      findsNWidgets(2),
    );
    // As aulas continuam na tela junto das turmas.
    expect(find.text('O que é o batismo'), findsOneWidget);
  });

  testWidgets('card de turma de Batismo abre a tela da turma no curso', (
    tester,
  ) async {
    await _pump(tester, _host(turmas: () => AsyncData([_baptismTurma])));

    await tester.tap(find.text('Turma de Setembro'));
    await tester.pumpAndSettle();

    expect(find.text('turma $_courseId/sg-1'), findsOneWidget);
  });

  testWidgets('curso sem turmas mostra o estado vazio', (tester) async {
    await _pump(tester, _host(turmas: () => const AsyncData([])));

    expect(find.text('Nenhuma turma neste curso ainda.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CourseTurmasSection),
        matching: find.byType(GlassCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets('erro nas turmas fica contido e as aulas continuam', (
    tester,
  ) async {
    await _pump(
      tester,
      _host(
        turmas: () => AsyncError(Exception('boom'), StackTrace.empty),
        lessons: [_lesson()],
      ),
    );

    expect(find.text('Não foi possível carregar as turmas.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('O que é o batismo'), findsOneWidget);
    expect(find.text('Aulas'), findsOneWidget);
  });

  testWidgets('aulas vazias por RLS não quebram a tela nem as turmas', (
    tester,
  ) async {
    await _pump(tester, _host(turmas: () => AsyncData([_baptismTurma])));

    expect(find.text('Nenhuma aula disponível'), findsOneWidget);
    expect(find.text('Turma de Setembro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('curso presencial também mostra as turmas', (tester) async {
    await _pump(
      tester,
      _host(
        turmas: () => AsyncData([_baptismTurma]),
        type: CourseType.presencial,
      ),
    );

    expect(find.text('Curso Presencial'), findsOneWidget);
    expect(find.text('Turma de Setembro'), findsOneWidget);
  });

  group('seção contextual', () {
    testWidgets('aluno vê só a própria turma, com o título "Minha turma"', (
      tester,
    ) async {
      await _pump(
        tester,
        _host(
          turmas: () => AsyncData([_baptismTurma, _nativeTurma]),
          hub: CourseHubState(management: false, myTurmas: [_baptismTurma]),
        ),
      );

      expect(find.text('Minha turma'), findsOneWidget);
      expect(find.text('Turma de Setembro'), findsWidgets);
      expect(find.text('Turma de Março'), findsNothing);
    });

    testWidgets('quem não é aluno nem gestão não vê a seção', (tester) async {
      await _pump(
        tester,
        _host(
          turmas: () => AsyncData([_baptismTurma, _nativeTurma]),
          hub: const CourseHubState(management: false),
        ),
      );

      expect(find.byType(CourseTurmasSection), findsOneWidget);
      expect(find.text('Turmas'), findsNothing);
      expect(find.text('Turma de Setembro'), findsNothing);
      expect(find.text('Turma de Março'), findsNothing);
    });
  });
}
