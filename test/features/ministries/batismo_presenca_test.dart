import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_attendance_roll.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_meeting.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_presenca_tab.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

BaptismStudent _student(String name, {String turmaId = 'turma-1'}) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    status: BaptismStudentStatus.ativo,
    source: BaptismStudentSource.manual,
    createdAt: DateTime(2026, 9, 21),
  );
}

BaptismMeeting _meeting(
  String id, {
  String turmaId = 'turma-1',
  String? title,
  DateTime? date,
  String? turmaName,
}) {
  return BaptismMeeting(
    id: id,
    tenantId: 't1',
    turmaId: turmaId,
    meetingDate: date ?? DateTime(2026, 9, 21),
    title: title ?? 'Encontro $id',
    createdAt: DateTime(2026, 9, 21),
    turmaName: turmaName,
  );
}

BaptismAttendance _attendance(
  String meetingId,
  String studentId,
  BaptismAttendanceStatus status,
) {
  return BaptismAttendance(
    id: '$meetingId-$studentId',
    tenantId: 't1',
    meetingId: meetingId,
    studentId: studentId,
    status: status,
    markedAt: DateTime(2026, 9, 21),
  );
}

BaptismTurma _turma(String id, String name) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 9, 1),
  );
}

Widget _host({
  required List<BaptismMeeting> meetings,
  required List<BaptismStudent> students,
  required List<BaptismAttendance> attendance,
  List<BaptismTurma> turmas = const [],
  bool canWrite = true,
}) {
  return ProviderScope(
    overrides: [
      baptismStudentsProvider(
        _ministryId,
      ).overrideWith((ref) async => students),
      baptismTurmasProvider(_ministryId).overrideWith((ref) async => turmas),
      baptismMeetingsProvider(
        _ministryId,
      ).overrideWith((ref) async => meetings),
      baptismAttendanceProvider(
        _ministryId,
      ).overrideWith((ref) async => attendance),
      ministryByIdProvider(_ministryId).overrideWith((ref) async => null),
      for (final action in BaptismWriteAction.values)
        baptismCanWriteProvider((
          ministryId: _ministryId,
          action: action,
        )).overrideWith((ref) async => canWrite),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: BatismoPresencaTab(ministryId: _ministryId)),
    ),
  );
}

/// A `ListView` não constrói o que fica fora da viewport, e a de teste é
/// 800x600. Sem `setSurfaceSize` os cards de baixo simplesmente não existem
/// na árvore e o teste falha por motivo errado.
Future<void> _pumpTab(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('BaptismMeeting', () {
    test('toWriteJson manda meeting_date como DATE, sem hora', () {
      final json = _meeting(
        'e1',
        title: '  Aula 1  ',
        // Hora tardia de propósito: se algo converter para instante, o dia
        // vira 22/09 e o teste denuncia.
        date: DateTime(2026, 9, 21, 23, 30),
      ).toWriteJson();

      expect(json['meeting_date'], '2026-09-21');
      expect(json['title'], 'Aula 1');
      expect(json['turma_id'], 'turma-1');
      expect(json['notes'], isNull);
      // id, tenant_id e created_at são do banco.
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('tenant_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });

    test('fromJson aceita as colunas reais e o embed da turma', () {
      final meeting = BaptismMeeting.fromJson({
        'id': 'e1',
        'tenant_id': 't1',
        'turma_id': 'turma-1',
        'meeting_date': '2026-09-21',
        'title': 'Aula 1',
        'notes': 'Sala 2',
        'created_at': '2026-09-21T10:00:00Z',
        'baptism_turma': {'name': 'Turma A'},
      });

      expect(meeting.title, 'Aula 1');
      expect(meeting.notes, 'Sala 2');
      expect(meeting.turmaName, 'Turma A');
      expect(meeting.day, DateTime(2026, 9, 21));
    });

    test('observação em branco vira null, não string vazia', () {
      final json = _meeting('e1').copyWith(notes: '   ').toWriteJson();
      expect(json['notes'], isNull);
    });
  });

  group('BaptismAttendanceStatus', () {
    test('código desconhecido não estoura', () {
      expect(
        BaptismAttendanceStatus.fromCode('inventado'),
        BaptismAttendanceStatus.presente,
      );
    });

    test('os três códigos espelham o CHECK do banco', () {
      expect(BaptismAttendanceStatus.values.map((s) => s.code).toList(), [
        'presente',
        'ausente',
        'justificado',
      ]);
    });
  });

  group('buildBaptismMeetingRolls', () {
    test('cada encontro só lista os alunos da turma dele', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [_meeting('e1', turmaId: 'turma-1')],
        students: [
          _student('Ana'),
          _student('Bruno', turmaId: 'turma-2'),
        ],
        attendance: const [],
      );

      expect(rolls.single.students.map((s) => s.fullName), ['Ana']);
    });

    test('aluno sem linha fica NÃO-MARCADO, não ausente', () {
      // É o critério de aceite do plano: alguém cadastrado depois da aula
      // não pode aparecer como faltoso numa aula anterior à matrícula.
      final rolls = buildBaptismMeetingRolls(
        meetings: [_meeting('e1')],
        students: [_student('Ana'), _student('Bruno')],
        attendance: [
          _attendance('e1', 'id-Ana', BaptismAttendanceStatus.presente),
        ],
      );

      final roll = rolls.single;
      expect(roll.present, 1);
      expect(roll.absent, 0);
      expect(roll.unmarked, 1);
      expect(roll.statusOf(_student('Bruno')), isNull);
    });

    test('encontro sem marcação nenhuma não conta como todos ausentes', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [_meeting('e1')],
        students: [_student('Ana'), _student('Bruno')],
        attendance: const [],
      );

      final roll = rolls.single;
      expect(roll.absent, 0);
      expect(roll.unmarked, 2);
      expect(roll.isUntouched, isTrue);
      expect(roll.isComplete, isFalse);
    });

    test('chamada completa só quando ninguém sobra sem marca', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [_meeting('e1')],
        students: [_student('Ana'), _student('Bruno')],
        attendance: [
          _attendance('e1', 'id-Ana', BaptismAttendanceStatus.presente),
          _attendance('e1', 'id-Bruno', BaptismAttendanceStatus.ausente),
        ],
      );

      final roll = rolls.single;
      expect(roll.isComplete, isTrue);
      expect(roll.unmarked, 0);
      expect(roll.present, 1);
      expect(roll.absent, 1);
    });

    test('turma vazia não é chamada completa', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [_meeting('e1', turmaId: 'turma-9')],
        students: [_student('Ana')],
        attendance: const [],
      );

      final roll = rolls.single;
      expect(roll.total, 0);
      expect(roll.isComplete, isFalse);
    });

    test('mais recente primeiro; empate de dia cai no título', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [
          _meeting('antigo', title: 'Aula 1', date: DateTime(2026, 9, 14)),
          // Dois no mesmo dia são permitidos pelo UNIQUE do banco.
          _meeting('noite', title: 'Noite', date: DateTime(2026, 9, 21)),
          _meeting('manha', title: 'Manhã', date: DateTime(2026, 9, 21)),
        ],
        students: const [],
        attendance: const [],
      );

      expect(rolls.map((r) => r.meeting.title).toList(), [
        'Manhã',
        'Noite',
        'Aula 1',
      ]);
    });

    test('marcação de outro encontro não vaza para este', () {
      final rolls = buildBaptismMeetingRolls(
        meetings: [
          _meeting('e1'),
          _meeting('e2', title: 'Aula 2'),
        ],
        students: [_student('Ana')],
        attendance: [
          _attendance('e2', 'id-Ana', BaptismAttendanceStatus.presente),
        ],
      );

      final e1 = rolls.firstWhere((r) => r.meeting.id == 'e1');
      final e2 = rolls.firstWhere((r) => r.meeting.id == 'e2');
      expect(e1.unmarked, 1);
      expect(e2.present, 1);
    });
  });

  group('BatismoPresencaTab', () {
    testWidgets('sem turma manda cadastrar turma antes', (tester) async {
      await _pumpTab(
        tester,
        _host(meetings: const [], students: const [], attendance: const []),
      );

      expect(find.text('Nenhuma turma cadastrada'), findsOneWidget);
      // Sem turma não dá nem para criar encontro.
      expect(find.text('Novo encontro'), findsNothing);
    });

    testWidgets('turma sem encontro mostra estado vazio próprio', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        _host(
          meetings: const [],
          students: [_student('Ana')],
          attendance: const [],
          turmas: [_turma('turma-1', 'Turma A')],
        ),
      );

      expect(find.text('Nenhum encontro registrado'), findsOneWidget);
      expect(find.text('Registrar o primeiro encontro'), findsOneWidget);
    });

    testWidgets('encontro em branco diz que a chamada não foi feita', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        _host(
          meetings: [_meeting('e1', title: 'Aula 1', turmaName: 'Turma A')],
          students: [_student('Ana'), _student('Bruno')],
          attendance: const [],
          turmas: [_turma('turma-1', 'Turma A')],
        ),
      );

      expect(find.text('Aula 1'), findsOneWidget);
      // O StatusBadge exibe o rótulo em maiúsculas — daí a busca assim.
      // "Chamada não feita", nunca "2 faltaram".
      expect(find.textContaining('CHAMADA NÃO FEITA'), findsOneWidget);
      expect(find.textContaining('FALTARAM'), findsNothing);
    });

    testWidgets('resumo separa presentes, faltas e quem ficou sem marca', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        _host(
          meetings: [_meeting('e1', title: 'Aula 1')],
          students: [_student('Ana'), _student('Bruno'), _student('Carla')],
          attendance: [
            _attendance('e1', 'id-Ana', BaptismAttendanceStatus.presente),
            _attendance('e1', 'id-Bruno', BaptismAttendanceStatus.ausente),
          ],
          turmas: [_turma('turma-1', 'Turma A')],
        ),
      );

      // O StatusBadge exibe o rótulo em maiúsculas.
      expect(find.textContaining('1 PRESENTES'), findsOneWidget);
      expect(find.textContaining('1 FALTARAM'), findsOneWidget);
      expect(find.textContaining('1 SEM MARCA'), findsOneWidget);
    });

    // A onda 8 da cascata visual repintou Checklist, Relatorios e WhatsApp
    // para GlassCard enquanto esta aba nascia do gabarito antigo. Este
    // teste trava o alinhamento: um card de vidro por encontro.
    testWidgets('cada encontro e um GlassCard, como as abas vizinhas', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        _host(
          meetings: [
            _meeting('e1', title: 'Aula 1'),
            _meeting('e2', title: 'Aula 2'),
          ],
          students: [_student('Ana')],
          attendance: const [],
          turmas: [_turma('turma-1', 'Turma A')],
        ),
      );

      expect(find.byType(GlassCard), findsNWidgets(2));
    });

    testWidgets('sem permissão de escrita não oferece criar encontro', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        _host(
          meetings: [_meeting('e1', title: 'Aula 1')],
          students: [_student('Ana')],
          attendance: const [],
          turmas: [_turma('turma-1', 'Turma A')],
          canWrite: false,
        ),
      );

      expect(find.text('Novo encontro'), findsNothing);
      // A chamada continua legível: só as ações somem.
      expect(find.text('Aula 1'), findsOneWidget);
    });

    testWidgets('abrir o encontro lista os alunos da turma', (tester) async {
      await _pumpTab(
        tester,
        _host(
          meetings: [_meeting('e1', title: 'Aula 1')],
          students: [
            _student('Ana'),
            _student('Bruno', turmaId: 'turma-2'),
          ],
          attendance: const [],
          turmas: [_turma('turma-1', 'Turma A'), _turma('turma-2', 'Turma B')],
        ),
      );

      await tester.tap(find.text('Aula 1'));
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
      // Bruno é da turma-2: não entra na chamada deste encontro.
      expect(find.text('Bruno'), findsNothing);
      expect(find.text('Marcar todos presentes'), findsOneWidget);
    });
  });
}
