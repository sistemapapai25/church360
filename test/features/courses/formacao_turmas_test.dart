import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/domain/models/course_turma.dart';
import 'package:church360_app/features/courses/presentation/legacy_study_group_redirect.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/screens/courses_list_screen.dart';
import 'package:church360_app/features/courses/presentation/widgets/formacao_turmas_tab.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';

const _baptism = CourseTurma(
  id: 'sg-b',
  name: 'Batizandos 2026',
  status: StudyGroupStatus.active,
  ministryId: 'min-1',
  baptismTurmaId: 'bt-1',
  courseId: 'c-b',
);

const _study = CourseTurma(
  id: 'sg-e',
  name: 'Evangelho de João',
  status: StudyGroupStatus.completed,
  courseId: 'c-e',
);

Widget _host({
  String initial = '/courses?tab=turmas',
  List<CourseTurma> turmas = const [_baptism, _study],
  Map<String, CourseTurma?> byId = const {},
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/courses',
        builder: (context, state) => CoursesListScreen(
          initialTab: state.uri.queryParameters['tab'] == 'turmas' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: '/study-groups',
        redirect: (context, state) => studyGroupsListRedirect(state.uri),
      ),
      GoRoute(
        path: '/study-groups/:id',
        builder: (context, state) => LegacyStudyGroupRedirect(
          studyGroupId: state.pathParameters['id']!,
          fallback: Text('antigo ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/courses/:courseId/turmas/:studyGroupId',
        builder: (context, state) => Text(
          'turma ${state.pathParameters['courseId']}/${state.pathParameters['studyGroupId']}',
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      formacaoTurmasProvider.overrideWith((ref) async => turmas),
      allCoursesProvider.overrideWith(
        (ref) async => [
          Course(id: 'c-b', title: 'Batismo', createdAt: DateTime(2026)),
          Course(id: 'c-e', title: 'Teologia', createdAt: DateTime(2026)),
        ],
      ),
      activeCoursesProvider.overrideWith((ref) async => []),
      upcomingCoursesProvider.overrideWith((ref) async => []),
      allMinistriesProvider.overrideWith((ref) async => []),
      currentUserHasPermissionProvider(
        'courses.create',
      ).overrideWith((ref) async => false),
      currentUserHasPermissionProvider(
        'courses.edit',
      ).overrideWith((ref) async => false),
      currentUserHasPermissionProvider(
        'study_groups.create',
      ).overrideWith((ref) async => false),
      for (final entry in byId.entries)
        turmaByIdProvider(entry.key).overrideWith((ref) async => entry.value),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
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

  group('studyGroupsListRedirect', () {
    test('a central antiga vai para Formação → Turmas', () {
      expect(
        studyGroupsListRedirect(Uri.parse('/study-groups')),
        '/courses?tab=turmas',
      );
    });

    test('mantém o from=dashboard', () {
      expect(
        studyGroupsListRedirect(Uri.parse('/study-groups?from=dashboard')),
        '/courses?tab=turmas&from=dashboard',
      );
    });
  });

  testWidgets('/study-groups abre Formação na aba Turmas', (tester) async {
    await _pump(tester, _host(initial: '/study-groups'));

    expect(find.text('Formação'), findsOneWidget);
    expect(find.byType(FormacaoTurmasTab), findsOneWidget);
    expect(find.text('Batizandos 2026'), findsOneWidget);
    expect(find.text('Evangelho de João'), findsOneWidget);
  });

  testWidgets('card mostra origem e curso, sem ação destrutiva', (
    tester,
  ) async {
    await _pump(tester, _host());

    expect(find.text('Batismo · Batismo'), findsOneWidget);
    expect(find.text('Grupo de estudo · Teologia'), findsOneWidget);
    final cards = find.byType(FormacaoTurmaCard);
    expect(cards, findsNWidgets(2));
    for (final matcher in [
      find.byType(PopupMenuButton<String>),
      find.byIcon(Icons.delete_outline),
      find.byTooltip('Excluir turma'),
    ]) {
      expect(find.descendant(of: cards, matching: matcher), findsNothing);
    }
  });

  testWidgets('filtro por origem separa Batismo de grupo de estudo', (
    tester,
  ) async {
    await _pump(tester, _host());

    await tester.tap(find.text('Todas as origens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batismo').last);
    await tester.pumpAndSettle();

    expect(find.text('Batizandos 2026'), findsOneWidget);
    expect(find.text('Evangelho de João'), findsNothing);

    await tester.tap(find.text('Batismo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grupos de estudo').last);
    await tester.pumpAndSettle();

    expect(find.text('Batizandos 2026'), findsNothing);
    expect(find.text('Evangelho de João'), findsOneWidget);
  });

  testWidgets('busca filtra pelo nome da turma', (tester) async {
    await _pump(tester, _host());

    await tester.enterText(find.byType(TextField).first, 'joão');
    await tester.pumpAndSettle();

    expect(find.text('Evangelho de João'), findsOneWidget);
    expect(find.text('Batizandos 2026'), findsNothing);
  });

  testWidgets('card abre a tela canônica da turma', (tester) async {
    await _pump(tester, _host());

    await tester.tap(find.text('Batizandos 2026'));
    await tester.pumpAndSettle();

    expect(find.text('turma c-b/sg-b'), findsOneWidget);
  });

  testWidgets('sem turma visível mostra estado vazio', (tester) async {
    await _pump(tester, _host(turmas: const []));

    expect(
      find.text('Nenhuma turma para você por aqui ainda.'),
      findsOneWidget,
    );
  });

  group('/study-groups/:id antigo', () {
    testWidgets('turma com curso troca para a rota canônica', (tester) async {
      await _pump(
        tester,
        _host(initial: '/study-groups/sg-b', byId: {'sg-b': _baptism}),
      );

      expect(find.text('turma c-b/sg-b'), findsOneWidget);
    });

    testWidgets('grupo sem curso fica na tela antiga', (tester) async {
      const semCurso = CourseTurma(
        id: 'sg-x',
        name: 'Antigo',
        status: StudyGroupStatus.active,
      );
      await _pump(
        tester,
        _host(initial: '/study-groups/sg-x', byId: {'sg-x': semCurso}),
      );

      expect(find.text('antigo sg-x'), findsOneWidget);
    });

    testWidgets('turma escondida pela RLS fica na tela antiga', (tester) async {
      await _pump(
        tester,
        _host(initial: '/study-groups/sg-z', byId: {'sg-z': null}),
      );

      expect(find.text('antigo sg-z'), findsOneWidget);
    });
  });
}
