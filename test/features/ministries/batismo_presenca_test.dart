import 'package:church360_app/features/ministries/batismo/domain/baptism_attendance_roll.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_meeting.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:flutter_test/flutter_test.dart';

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
  String? studyLessonId = 'aula-1',
}) {
  return BaptismMeeting(
    id: id,
    tenantId: 't1',
    turmaId: turmaId,
    meetingDate: date ?? DateTime(2026, 9, 21),
    title: title ?? 'Encontro $id',
    createdAt: DateTime(2026, 9, 21),
    studyLessonId: studyLessonId,
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
      // Etapa 5.3: o banco recusa encontro sem aula.
      expect(json['study_lesson_id'], 'aula-1');
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
        'study_lesson_id': 'aula-9',
        'baptism_turma': {'name': 'Turma A'},
      });

      expect(meeting.title, 'Aula 1');
      expect(meeting.studyLessonId, 'aula-9');
      expect(meeting.isAvulso, isFalse);
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
}
