import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/domain/models/course_turma.dart';
import 'package:church360_app/features/courses/presentation/hub/course_enroll_sheet.dart';
import 'package:church360_app/features/courses/presentation/hub/course_hub.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/screens/course_viewer_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/ministries/batismo/data/baptism_repository.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_enrollment.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_public_info.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';

const _courseId = 'course-b';
const _ministryId = 'min-1';

Course _baptismCourse() => Course(
  id: _courseId,
  title: 'Batismo',
  createdAt: DateTime(2026, 9, 1),
  ministryId: _ministryId,
  code: 'baptism',
);

const _turmaA = CourseTurma(
  id: 'sg-a',
  name: 'Batizandos 2026',
  status: StudyGroupStatus.active,
  ministryId: _ministryId,
  baptismTurmaId: 'bt-a',
  courseId: _courseId,
);

const _openA = BaptismPublicTurma(id: 'bt-a', name: 'Batizandos 2026');
const _openB = BaptismPublicTurma(id: 'bt-b', name: 'Turma de Outubro');

class _FakeRepo implements BaptismRepository {
  Map<String, Object?>? ultimaInscricao;

  @override
  Future<String> registerPublicStudent({
    required String ministryId,
    required String turmaId,
    required String fullName,
    required String phone,
    String? email,
    DateTime? birthDate,
  }) async {
    ultimaInscricao = {
      'ministryId': ministryId,
      'turmaId': turmaId,
      'fullName': fullName,
      'phone': phone,
    };
    return 'novo-aluno';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Overrides do `courseHubProvider` de verdade, no ramo Batismo.
List<Override> _baptismOverrides({
  bool elevated = false,
  bool courseView = false,
  bool canSeeAll = false,
  bool baptismView = false,
  bool inMinistry = false,
  bool enrolled = false,
  List<BaptismPublicTurma> open = const [],
  bool publicInfoFails = false,
  List<String>? publicInfoCalls,
}) {
  return [
    courseByIdProvider(_courseId).overrideWith((ref) async => _baptismCourse()),
    courseStudyGroupsProvider(_courseId).overrideWith((ref) async => [_turmaA]),
    currentUserIsElevatedProvider.overrideWith((ref) async => elevated),
    currentUserHasPermissionProvider(
      'courses.view',
    ).overrideWith((ref) async => courseView),
    currentUserHasPermissionProvider(
      'baptism.view',
    ).overrideWith((ref) async => baptismView),
    ministriesCanSeeAllProvider.overrideWith((ref) async => canSeeAll),
    ministryAccessProvider(_ministryId).overrideWith((ref) async => inMinistry),
    myBaptismEnrollmentsProvider.overrideWith(
      (ref) async => [
        if (enrolled)
          const BaptismEnrollment(
            studentId: 'st-1',
            turmaId: 'bt-a',
            studyGroupId: 'sg-a',
            courseId: _courseId,
            status: 'ativo',
          ),
      ],
    ),
    baptismPublicInfoProvider(_ministryId).overrideWith((ref) async {
      publicInfoCalls?.add(_ministryId);
      if (publicInfoFails) throw Exception('rpc caiu');
      return BaptismPublicInfo(ministryName: 'Batismo', turmas: open);
    }),
  ];
}

Future<CourseHubState> _hub(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(courseHubProvider(_courseId).future);
}

Widget _screen(List<Override> overrides) {
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
        builder: (context, state) =>
            Text('turma ${state.pathParameters['studyGroupId']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      ...overrides,
      courseLessonsProvider(_courseId).overrideWith((ref) async => []),
      currentUserHasPermissionProvider(
        'courses.edit',
      ).overrideWith((ref) async => false),
      currentUserHasPermissionProvider(
        'courses.manage_lessons',
      ).overrideWith((ref) async => false),
      currentMemberProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
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

  group('Course', () {
    test('lê ministry_id e code, e não os devolve no toJson', () {
      final course = Course.fromJson({
        'id': 'c1',
        'title': 'Batismo',
        'created_at': '2026-09-01T00:00:00Z',
        'ministry_id': 'm1',
        'code': 'baptism',
      });
      expect(course.isBaptismProgram, isTrue);
      expect(course.toJson().containsKey('code'), isFalse);
      expect(course.toJson().containsKey('ministry_id'), isFalse);
    });

    test('curso sem code não é programa do Batismo', () {
      final course = Course(
        id: 'c2',
        title: 'Teologia',
        createdAt: DateTime(2026),
      );
      expect(course.isBaptismProgram, isFalse);
    });
  });

  // Tabela da decisão 24.
  group('CourseHubState.primary', () {
    test('não inscrito + turma aberta → Inscrever-se', () {
      const hub = CourseHubState(
        management: false,
        acceptsEnrollment: true,
        openTurmas: [_openA],
      );
      expect(hub.primary, CourseCta.enroll);
    });

    test('não inscrito + nenhuma aberta → Inscrições fechadas', () {
      const hub = CourseHubState(management: false, acceptsEnrollment: true);
      expect(hub.primary, CourseCta.closed);
    });

    test('aluno → Acessar minha turma, sem Gerenciar', () {
      const hub = CourseHubState(management: false, myTurmas: [_turmaA]);
      expect(hub.primary, CourseCta.myTurma);
      expect(hub.showManageSecondary, isFalse);
    });

    test('liderança → Ver turmas / Gerenciar', () {
      const hub = CourseHubState(management: true, acceptsEnrollment: true);
      expect(hub.primary, CourseCta.manage);
    });

    test('líder que também é aluno → minha turma + Gerenciar secundário', () {
      const hub = CourseHubState(management: true, myTurmas: [_turmaA]);
      expect(hub.primary, CourseCta.myTurma);
      expect(hub.showManageSecondary, isTrue);
    });

    test('curso sem inscrição pelo app e sem turma minha → nada', () {
      const hub = CourseHubState(management: false);
      expect(hub.primary, CourseCta.none);
    });
  });

  group('courseHubProvider (Batismo)', () {
    test('aluno matriculado vê a própria turma', () async {
      final hub = await _hub(_baptismOverrides(enrolled: true));
      expect(hub.primary, CourseCta.myTurma);
      expect(hub.myTurmas.single.id, 'sg-a');
      expect(hub.management, isFalse);
    });

    test('membro sem matrícula com turma aberta → Inscrever-se', () async {
      final hub = await _hub(_baptismOverrides(open: [_openA, _openB]));
      expect(hub.primary, CourseCta.enroll);
      expect(hub.openTurmas, hasLength(2));
      expect(hub.ministryId, _ministryId);
    });

    test('baptism.view sem vínculo no ministério não é gestão', () async {
      final hub = await _hub(_baptismOverrides(baptismView: true));
      expect(hub.management, isFalse);
      expect(hub.primary, CourseCta.closed);
    });

    test(
      'baptism.view com vínculo é gestão e não consulta turmas abertas',
      () async {
        final calls = <String>[];
        final hub = await _hub(
          _baptismOverrides(
            baptismView: true,
            inMinistry: true,
            publicInfoCalls: calls,
          ),
        );
        expect(hub.primary, CourseCta.manage);
        expect(calls, isEmpty);
      },
    );

    test('elevado é gestão', () async {
      final hub = await _hub(_baptismOverrides(elevated: true));
      expect(hub.primary, CourseCta.manage);
    });

    test(
      'RPC das turmas abertas falhando esconde o botão, não mente',
      () async {
        final hub = await _hub(_baptismOverrides(publicInfoFails: true));
        expect(hub.primary, CourseCta.none);
      },
    );
  });

  group('tela do curso', () {
    testWidgets('aluno toca "Acessar minha turma" e cai na rota canônica', (
      tester,
    ) async {
      await _pump(tester, _screen(_baptismOverrides(enrolled: true)));

      expect(find.text('Acessar minha turma'), findsOneWidget);
      expect(find.text('Gerenciar'), findsNothing);
      await tester.tap(find.text('Acessar minha turma'));
      await tester.pumpAndSettle();
      expect(find.text('turma sg-a'), findsOneWidget);
    });

    testWidgets('sem turma aberta mostra "Inscrições fechadas" desligado', (
      tester,
    ) async {
      await _pump(tester, _screen(_baptismOverrides()));

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Inscrições fechadas'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      // Sem matrícula e sem gestão, a seção Turmas some.
      expect(find.text('Batizandos 2026'), findsNothing);
    });

    testWidgets('liderança vê "Ver turmas / Gerenciar" e todas as turmas', (
      tester,
    ) async {
      await _pump(tester, _screen(_baptismOverrides(elevated: true)));

      expect(find.text('Ver turmas / Gerenciar'), findsOneWidget);
      expect(find.text('Turmas'), findsOneWidget);
      expect(find.text('Batizandos 2026'), findsOneWidget);
    });

    testWidgets(
      'Inscrever-se com duas turmas pede a escolha e grava na certa',
      (tester) async {
        final repo = _FakeRepo();
        await _pump(
          tester,
          _screen([
            ..._baptismOverrides(open: [_openA, _openB]),
            baptismRepositoryProvider.overrideWithValue(repo),
          ]),
        );

        await tester.tap(find.text('Inscrever-se'));
        await tester.pumpAndSettle();
        expect(find.byType(CourseEnrollSheet), findsOneWidget);
        expect(find.text('Escolha a turma'), findsOneWidget);

        // Sem escolher, não envia.
        await tester.tap(find.text('Confirmar inscrição'));
        await tester.pumpAndSettle();
        expect(
          find.text('Escolha a turma em que você quer entrar.'),
          findsOneWidget,
        );
        expect(repo.ultimaInscricao, isNull);

        await tester.tap(find.text('Turma de Outubro'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nome completo *'),
          'Maria da Silva',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'WhatsApp *'),
          '(62) 99999-0000',
        );
        await tester.tap(find.text('Confirmar inscrição'));
        await tester.pumpAndSettle();

        expect(repo.ultimaInscricao?['turmaId'], 'bt-b');
        expect(repo.ultimaInscricao?['ministryId'], _ministryId);
        expect(find.byType(CourseEnrollSheet), findsNothing);
        expect(find.textContaining('Inscrição feita!'), findsOneWidget);
      },
    );
  });
}
