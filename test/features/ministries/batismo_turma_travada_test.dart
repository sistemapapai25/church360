import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/data/baptism_repository.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_checklist.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_meeting.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_presenca_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/widgets/baptism_locked_turma_unavailable.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Decisão 5 do DESENHO-2026-09-25-TELA-DA-TURMA: as abas Alunos e Presença
// do Batismo com `lockedTurmaId`. Os dois modos, com os providers de
// verdade sobre um repositório falso — é o repositório que prova que o
// recorte é feito na consulta, e não na tela.

const _ministryId = 'm1';
const _turmaA = 'turma-a';
const _turmaB = 'turma-b';

BaptismTurma _turma(String id, String name, {String ministryId = _ministryId}) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: ministryId,
    name: name,
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 9, 1),
  );
}

BaptismStudent _student(String name, String turmaId) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    status: BaptismStudentStatus.ativo,
    source: BaptismStudentSource.manual,
    createdAt: DateTime(2026, 9, 1),
  );
}

BaptismMeeting _meeting(String id, String turmaId, String title) {
  return BaptismMeeting(
    id: id,
    tenantId: 't1',
    turmaId: turmaId,
    meetingDate: DateTime(2026, 9, 20),
    title: title,
    createdAt: DateTime(2026, 9, 20),
  );
}

/// Repositório falso: guarda o que foi pedido e o que foi gravado.
class _FakeBaptismRepository implements BaptismRepository {
  final List<BaptismTurma> turmas;
  final List<BaptismStudent> students;
  final List<BaptismMeeting> meetings;

  final studentQueries = <String?>[];
  final meetingQueries = <List<String>>[];
  final marked = <({String meetingId, String studentId})>[];
  final createdStudents = <BaptismStudent>[];
  final createdMeetings = <BaptismMeeting>[];

  _FakeBaptismRepository({
    required this.turmas,
    required this.students,
    required this.meetings,
  });

  @override
  Future<List<BaptismTurma>> getTurmas(String ministryId) async => [
    for (final t in turmas)
      if (t.ministryId == ministryId) t,
  ];

  @override
  Future<List<BaptismStudent>> getStudents(
    String ministryId, {
    String? turmaId,
  }) async {
    studentQueries.add(turmaId);
    final ids = {
      for (final t in turmas)
        if (t.ministryId == ministryId) t.id,
    };
    return [
      for (final s in students)
        if (ids.contains(s.turmaId) &&
            (turmaId == null || s.turmaId == turmaId))
          s,
    ];
  }

  @override
  Future<List<BaptismMeeting>> getMeetings(List<String> turmaIds) async {
    meetingQueries.add(turmaIds);
    return [
      for (final m in meetings)
        if (turmaIds.contains(m.turmaId)) m,
    ];
  }

  @override
  Future<List<BaptismAttendance>> getAttendance(
    List<String> meetingIds,
  ) async => const [];

  @override
  Future<List<BaptismChecklistItem>> getChecklistItems(
    String ministryId,
  ) async => const [];

  @override
  Future<List<BaptismChecklistEntry>> getChecklistEntries(
    List<String> studentIds,
  ) async => const [];

  @override
  Future<void> markAttendance(
    List<({String meetingId, String studentId, BaptismAttendanceStatus status})>
    marks,
  ) async {
    for (final m in marks) {
      marked.add((meetingId: m.meetingId, studentId: m.studentId));
    }
  }

  @override
  Future<BaptismStudent> createStudent(BaptismStudent student) async {
    createdStudents.add(student);
    return student;
  }

  @override
  Future<BaptismMeeting> createMeeting(BaptismMeeting meeting) async {
    createdMeetings.add(meeting);
    return meeting;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_FakeBaptismRepository _repo() => _FakeBaptismRepository(
  turmas: [
    _turma(_turmaA, 'Turma A'),
    _turma(_turmaB, 'Turma B'),
    _turma('turma-x', 'Turma de outro ministério', ministryId: 'm2'),
  ],
  students: [
    _student('Ana', _turmaA),
    _student('Bruno', _turmaA),
    _student('Carla', _turmaB),
  ],
  meetings: [
    _meeting('e-a', _turmaA, 'Aula da A'),
    _meeting('e-b', _turmaB, 'Aula da B'),
  ],
);

Widget _host(_FakeBaptismRepository repo, Widget tab) {
  return ProviderScope(
    overrides: [
      baptismRepositoryProvider.overrideWithValue(repo),
      ministryByIdProvider(_ministryId).overrideWith((ref) async => null),
      for (final action in BaptismWriteAction.values)
        baptismCanWriteProvider((
          ministryId: _ministryId,
          action: action,
        )).overrideWith((ref) async => true),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: tab),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('providers da turma travada', () {
    test('alunos da turma saem da consulta com turma_id', () async {
      final repo = _repo();
      final container = ProviderContainer(
        overrides: [baptismRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final students = await container.read(
        baptismTurmaStudentsProvider((
          ministryId: _ministryId,
          turmaId: _turmaA,
        )).future,
      );

      expect(students.map((s) => s.fullName), ['Ana', 'Bruno']);
      expect(repo.studentQueries, [_turmaA]);
    });

    test('encontros da turma pedem só a turma', () async {
      final repo = _repo();
      final container = ProviderContainer(
        overrides: [baptismRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final meetings = await container.read(
        baptismTurmaMeetingsProvider((
          ministryId: _ministryId,
          turmaId: _turmaA,
        )).future,
      );

      expect(meetings.map((m) => m.id), ['e-a']);
      expect(repo.meetingQueries, [
        [_turmaA],
      ]);
    });

    test('turma de outro ministério não busca nada', () async {
      final repo = _repo();
      final container = ProviderContainer(
        overrides: [baptismRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      const key = (ministryId: _ministryId, turmaId: 'turma-x');

      expect(
        await container.read(baptismLockedTurmaProvider(key).future),
        isNull,
      );
      expect(
        await container.read(baptismTurmaStudentsProvider(key).future),
        isEmpty,
      );
      expect(
        await container.read(baptismTurmaMeetingsProvider(key).future),
        isEmpty,
      );
      expect(repo.studentQueries, isEmpty);
      expect(repo.meetingQueries, isEmpty);
    });
  });

  group('BatismoAlunosTab', () {
    testWidgets('sem trava: seletor de turma, Turmas e todos os alunos', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(repo, const BatismoAlunosTab(ministryId: _ministryId)),
      );

      expect(find.text('Todas as turmas'), findsOneWidget);
      expect(find.text('Turmas'), findsOneWidget);
      expect(find.text('Link de inscrição'), findsOneWidget);
      expect(find.text('Carla'), findsOneWidget);
      expect(repo.studentQueries, everyElement(isNull));
    });

    testWidgets('travada: só a turma, sem gerenciamento estrutural', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoAlunosTab(
            ministryId: _ministryId,
            lockedTurmaId: _turmaA,
          ),
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Carla'), findsNothing);
      expect(find.text('Todas as turmas'), findsNothing);
      expect(find.text('Turmas'), findsNothing);
      expect(find.text('Link de inscrição'), findsNothing);
      // Nenhuma consulta de alunos do ministério inteiro.
      expect(repo.studentQueries, everyElement(_turmaA));
    });

    testWidgets('travada: novo aluno grava na turma, sem seletor', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoAlunosTab(
            ministryId: _ministryId,
            lockedTurmaId: _turmaB,
          ),
        ),
      );

      await tester.tap(find.text('Novo aluno'));
      await tester.pumpAndSettle();
      expect(find.text('Turma *'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome completo *'),
        'Davi',
      );
      await tester.ensureVisible(find.text('Cadastrar'));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(repo.createdStudents, hasLength(1));
      expect(repo.createdStudents.single.turmaId, _turmaB);
    });

    testWidgets('travada em turma de outro ministério: fail-closed', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoAlunosTab(
            ministryId: _ministryId,
            lockedTurmaId: 'turma-x',
          ),
        ),
      );

      expect(find.byType(BaptismLockedTurmaUnavailable), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
      expect(find.text('Carla'), findsNothing);
      expect(find.text('Novo aluno'), findsNothing);
      expect(repo.studentQueries, isEmpty);
    });
  });

  group('BatismoPresencaTab', () {
    testWidgets('sem trava: filtro de turma e encontros de todas', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(repo, const BatismoPresencaTab(ministryId: _ministryId)),
      );

      expect(find.text('Todas as turmas'), findsOneWidget);
      expect(find.text('Aula da A'), findsOneWidget);
      expect(find.text('Aula da B'), findsOneWidget);
    });

    testWidgets('travada: só os encontros da turma, sem filtro de turma', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoPresencaTab(
            ministryId: _ministryId,
            lockedTurmaId: _turmaA,
          ),
        ),
      );

      expect(find.text('Aula da A'), findsOneWidget);
      expect(find.text('Aula da B'), findsNothing);
      expect(find.text('Todas as turmas'), findsNothing);
      expect(repo.meetingQueries, everyElement([_turmaA]));
    });

    testWidgets('travada: a chamada grava só alunos e encontro da turma', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoPresencaTab(
            ministryId: _ministryId,
            lockedTurmaId: _turmaA,
          ),
        ),
      );

      await tester.tap(find.text('Aula da A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar todos presentes'));
      await tester.pumpAndSettle();

      expect(repo.marked, hasLength(2));
      expect(repo.marked.map((m) => m.meetingId), everyElement('e-a'));
      expect(repo.marked.map((m) => m.studentId).toSet(), {
        'id-Ana',
        'id-Bruno',
      });
    });

    testWidgets('travada: encontro novo vai para a turma, sem seletor', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoPresencaTab(
            ministryId: _ministryId,
            lockedTurmaId: _turmaB,
          ),
        ),
      );

      await tester.tap(find.text('Novo encontro'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(DropdownButtonFormField<String?>, 'Turma'),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do encontro'),
        'Aula 2',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repo.createdMeetings, hasLength(1));
      expect(repo.createdMeetings.single.turmaId, _turmaB);
    });

    testWidgets('travada em turma de outro ministério: fail-closed', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(
        tester,
        _host(
          repo,
          const BatismoPresencaTab(
            ministryId: _ministryId,
            lockedTurmaId: 'turma-x',
          ),
        ),
      );

      expect(find.byType(BaptismLockedTurmaUnavailable), findsOneWidget);
      expect(find.text('Aula da A'), findsNothing);
      expect(find.text('Novo encontro'), findsNothing);
      expect(repo.meetingQueries, isEmpty);
    });
  });
}
