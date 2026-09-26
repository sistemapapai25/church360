import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/domain/models/course_turma.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_access.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_detail_screen.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_origin.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_tabs.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_enrollment.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
import 'package:church360_app/features/study_groups/presentation/providers/study_group_provider.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material_link.dart';
import 'package:church360_app/features/support_materials/presentation/providers/support_materials_provider.dart';

const _courseId = 'course-1';
const _sgId = 'sg-1';

const _permissions = [
  'baptism.view',
  'baptism.edit',
  'courses.view',
  'courses.manage_lessons',
];

final _baptismTurma = CourseTurma(
  id: _sgId,
  name: 'Batizandos 2026',
  status: StudyGroupStatus.active,
  startDate: DateTime(2026, 9, 6),
  ministryId: 'min-1',
  baptismTurmaId: 'bt-1',
  courseId: _courseId,
);

const _genericTurma = CourseTurma(
  id: _sgId,
  name: 'Fundamentos da Fé',
  status: StudyGroupStatus.active,
  courseId: _courseId,
);

StudyParticipant _participant({
  ParticipantRole role = ParticipantRole.participant,
  bool active = true,
}) {
  final now = DateTime(2026, 9, 1);
  return StudyParticipant(
    id: 'sp-1',
    studyGroupId: _sgId,
    userId: 'auth-1',
    role: role,
    isActive: active,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

/// Overrides de tudo o que o [turmaAccessProvider] consulta.
List<Override> _accessOverrides({
  required CourseTurma? turma,
  bool elevated = false,
  bool canSeeAll = false,
  bool inMinistry = false,
  Set<String> permissions = const {},
  bool enrolled = false,
  StudyParticipant? participation,
}) {
  return [
    turmaByIdProvider(_sgId).overrideWith((ref) async => turma),
    currentUserIsElevatedProvider.overrideWith((ref) async => elevated),
    ministriesCanSeeAllProvider.overrideWith((ref) async => canSeeAll),
    ministryAccessProvider('min-1').overrideWith(
      (ref) async => canSeeAll || inMinistry,
    ),
    for (final code in _permissions)
      currentUserHasPermissionProvider(code).overrideWith(
        (ref) async => permissions.contains(code),
      ),
    myBaptismEnrollmentsProvider.overrideWith(
      (ref) async => [
        if (enrolled)
          const BaptismEnrollment(
            studentId: 'st-1',
            turmaId: 'bt-1',
            studyGroupId: _sgId,
            courseId: _courseId,
            status: 'ativo',
          ),
      ],
    ),
    turmaMyParticipationProvider(_sgId).overrideWith(
      (ref) async => participation,
    ),
  ];
}

Future<TurmaAccess> _access(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(turmaAccessProvider(_sgId).future);
}

Widget _host({
  required List<Override> overrides,
  String courseId = _courseId,
}) {
  final router = GoRouter(
    initialLocation: '/courses/$courseId/turmas/$_sgId',
    routes: [
      GoRoute(
        path: '/courses/:courseId/turmas/:studyGroupId',
        builder: (context, state) => TurmaDetailScreen(
          courseId: state.pathParameters['courseId']!,
          studyGroupId: state.pathParameters['studyGroupId']!,
        ),
      ),
      GoRoute(
        path: '/courses/:id/view',
        builder: (context, state) =>
            Text('curso ${state.pathParameters['id']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...overrides,
      // Conteúdo das abas compartilhadas vazio: estes testes são da casca.
      groupLessonsProvider(_sgId).overrideWith((ref) async => []),
      publishedLessonsProvider(_sgId).overrideWith((ref) async => []),
      materialsByEntityProvider((
        linkType: MaterialLinkType.studyGroup,
        entityId: _sgId,
      )).overrideWith((ref) async => []),
      courseByIdProvider(courseId).overrideWith(
        (ref) async => Course(
          id: courseId,
          title: 'Batismo',
          createdAt: DateTime(2026, 9, 1),
        ),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('TurmaOrigin', () {
    test('turma com baptism_turma_id e ministry_id é Batismo', () {
      final origin = TurmaOrigin.of(_baptismTurma);
      expect(origin, isA<BatismoTurmaOrigin>());
      origin as BatismoTurmaOrigin;
      expect(origin.ministryId, 'min-1');
      expect(origin.baptismTurmaId, 'bt-1');
      expect(origin.studyGroupId, _sgId);
    });

    test('sem baptism_turma_id é genérica', () {
      expect(TurmaOrigin.of(_genericTurma), isA<GenericaTurmaOrigin>());
    });

    test('baptism_turma_id sem ministry_id cai em genérica', () {
      const turma = CourseTurma(
        id: _sgId,
        name: 'Órfã',
        status: StudyGroupStatus.active,
        baptismTurmaId: 'bt-9',
      );
      expect(TurmaOrigin.of(turma), isA<GenericaTurmaOrigin>());
    });
  });

  group('turmaAccessProvider — Batismo', () {
    test('elevado é liderança e escreve aula', () async {
      final a = await _access(
        _accessOverrides(turma: _baptismTurma, elevated: true),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isTrue);
    });

    test('visão global de ministérios é liderança e escreve aula', () async {
      final a = await _access(
        _accessOverrides(turma: _baptismTurma, canSeeAll: true),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isTrue);
    });

    test('baptism.view + vínculo lê mas não escreve aula', () async {
      final a = await _access(
        _accessOverrides(
          turma: _baptismTurma,
          inMinistry: true,
          permissions: {'baptism.view'},
        ),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isFalse);
    });

    test('baptism.view + baptism.edit + vínculo escreve aula', () async {
      final a = await _access(
        _accessOverrides(
          turma: _baptismTurma,
          inMinistry: true,
          permissions: {'baptism.view', 'baptism.edit'},
        ),
      );
      expect(a.canWriteLessons, isTrue);
    });

    test('baptism.view sem vínculo não é liderança', () async {
      final a = await _access(
        _accessOverrides(
          turma: _baptismTurma,
          permissions: {'baptism.view', 'baptism.edit'},
        ),
      );
      expect(a.role, TurmaRole.none);
    });

    test('aluno matriculado é aluno', () async {
      final a = await _access(
        _accessOverrides(turma: _baptismTurma, enrolled: true),
      );
      expect(a.role, TurmaRole.student);
      expect(a.canWriteLessons, isFalse);
    });

    test('liderança que também é aluno fica em liderança', () async {
      final a = await _access(
        _accessOverrides(
          turma: _baptismTurma,
          inMinistry: true,
          permissions: {'baptism.view'},
          enrolled: true,
        ),
      );
      expect(a.role, TurmaRole.leadership);
    });

    test('participante de study_participants não conta no Batismo', () async {
      final a = await _access(
        _accessOverrides(
          turma: _baptismTurma,
          participation: _participant(role: ParticipantRole.leader),
        ),
      );
      expect(a.role, TurmaRole.none);
    });

    test('turma escondida pela RLS dá nenhum acesso', () async {
      final a = await _access(_accessOverrides(turma: null, elevated: true));
      expect(a.role, TurmaRole.none);
    });
  });

  group('turmaAccessProvider — genérica', () {
    test('líder ativo é liderança e escreve aula', () async {
      final a = await _access(
        _accessOverrides(
          turma: _genericTurma,
          participation: _participant(role: ParticipantRole.leader),
        ),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isTrue);
    });

    test('co-líder ativo também', () async {
      final a = await _access(
        _accessOverrides(
          turma: _genericTurma,
          participation: _participant(role: ParticipantRole.coLeader),
        ),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isTrue);
    });

    test('courses.view lê mas não escreve aula', () async {
      final a = await _access(
        _accessOverrides(turma: _genericTurma, permissions: {'courses.view'}),
      );
      expect(a.role, TurmaRole.leadership);
      expect(a.canWriteLessons, isFalse);
    });

    test('participante ativo é aluno', () async {
      final a = await _access(
        _accessOverrides(turma: _genericTurma, participation: _participant()),
      );
      expect(a.role, TurmaRole.student);
    });

    test('participante inativo não tem acesso', () async {
      final a = await _access(
        _accessOverrides(
          turma: _genericTurma,
          participation: _participant(active: false),
        ),
      );
      expect(a.role, TurmaRole.none);
    });

    test('líder inativo não é liderança', () async {
      final a = await _access(
        _accessOverrides(
          turma: _genericTurma,
          participation: _participant(
            role: ParticipantRole.leader,
            active: false,
          ),
        ),
      );
      expect(a.role, TurmaRole.none);
    });

    test('baptism.view não dá nada na genérica', () async {
      final a = await _access(
        _accessOverrides(
          turma: _genericTurma,
          inMinistry: true,
          permissions: {'baptism.view', 'baptism.edit'},
        ),
      );
      expect(a.role, TurmaRole.none);
    });

    test('matrícula do Batismo não dá nada na genérica', () async {
      final a = await _access(
        _accessOverrides(turma: _genericTurma, enrolled: true),
      );
      expect(a.role, TurmaRole.none);
    });
  });

  group('turmaTabsFor', () {
    test('liderança: Aulas, Alunos, Presença, Materiais', () {
      expect(
        turmaTabsFor(const TurmaAccess(role: TurmaRole.leadership)),
        [
          TurmaTabId.aulas,
          TurmaTabId.alunos,
          TurmaTabId.presenca,
          TurmaTabId.materiais,
        ],
      );
    });

    test('aluno: Aulas, Minha frequência, Materiais — sem Alunos', () {
      expect(turmaTabsFor(TurmaAccess.student), [
        TurmaTabId.aulas,
        TurmaTabId.minhaFrequencia,
        TurmaTabId.materiais,
      ]);
    });

    test('nenhum: sem abas', () {
      expect(turmaTabsFor(TurmaAccess.none), isEmpty);
    });
  });

  group('TurmaDetailScreen', () {
    testWidgets('liderança vê cabeçalho e as quatro abas', (tester) async {
      await tester.pumpWidget(
        _host(
          overrides: _accessOverrides(
            turma: _baptismTurma,
            inMinistry: true,
            permissions: {'baptism.view'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batizandos 2026'), findsOneWidget);
      expect(find.text('Batismo'), findsOneWidget);
      for (final label in ['Aulas', 'Alunos', 'Presença', 'Materiais']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Minha frequência'), findsNothing);
      expect(
        find.text('Nenhuma aula cadastrada nesta turma ainda.'),
        findsOneWidget,
      );
    });

    testWidgets('aluno não vê a aba Alunos', (tester) async {
      await tester.pumpWidget(
        _host(overrides: _accessOverrides(turma: _baptismTurma, enrolled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Minha frequência'), findsOneWidget);
      expect(find.text('Alunos'), findsNothing);
      expect(find.text('Presença'), findsNothing);
    });

    testWidgets('trocar de aba troca o conteúdo', (tester) async {
      await tester.pumpWidget(
        _host(overrides: _accessOverrides(turma: _baptismTurma, enrolled: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum material vinculado a esta turma.'),
        findsOneWidget,
      );
    });

    testWidgets('link do curso abre o curso', (tester) async {
      await tester.pumpWidget(
        _host(overrides: _accessOverrides(turma: _baptismTurma, enrolled: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('turma-course-link')));
      await tester.pumpAndSettle();
      expect(find.text('curso $_courseId'), findsOneWidget);
    });

    testWidgets('sem papel na turma mostra sem acesso', (tester) async {
      await tester.pumpWidget(
        _host(overrides: _accessOverrides(turma: _baptismTurma)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Você não tem acesso a esta turma.'), findsOneWidget);
      expect(find.text('Aulas'), findsNothing);
    });

    testWidgets('courseId do endereço diferente do da turma: sem acesso', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          courseId: 'outro-curso',
          overrides: _accessOverrides(turma: _baptismTurma, elevated: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Você não tem acesso a esta turma.'), findsOneWidget);
      expect(find.text('Batizandos 2026'), findsNothing);
    });

    testWidgets('turma escondida pela RLS: sem acesso', (tester) async {
      await tester.pumpWidget(
        _host(overrides: _accessOverrides(turma: null, elevated: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Você não tem acesso a esta turma.'), findsOneWidget);
    });
  });

  // Gate 5: nenhum `if origin == baptism` espalhado. Só a origem e o acesso
  // (e, a partir da 5.2, os adapters em turma/adapters/) podem saber que a
  // turma é do Batismo.
  test('régua: só origem, acesso e adapters conhecem o Batismo', () {
    final dir = Directory('lib/features/courses/presentation/turma');
    const allowed = {'turma_origin.dart', 'turma_access.dart'};
    final forbidden = RegExp(
      r'baptismTurmaId|isBaptismTurma|BatismoTurmaOrigin|GenericaTurmaOrigin|baptism_turma_id',
    );
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final name = path.split('/').last;
      if (allowed.contains(name) || path.contains('/turma/adapters/')) {
        continue;
      }
      if (forbidden.hasMatch(entity.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'origem vazou para: $offenders');
  });
}
