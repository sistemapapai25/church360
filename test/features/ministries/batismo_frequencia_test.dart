import 'dart:async';

import 'package:church360_app/features/ministries/batismo/domain/baptism_attendance_report.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_attendance_roll.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_pdf_renderer.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_meeting.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
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
    createdAt: DateTime(2026, 9, 1),
  );
}

BaptismTurma _turma(String id, String name) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 10, 25),
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 8, 1),
  );
}

BaptismMeeting _meeting(
  String id, {
  String turmaId = 'turma-1',
  required DateTime day,
  String title = 'Encontro',
}) {
  return BaptismMeeting(
    id: id,
    tenantId: 't1',
    turmaId: turmaId,
    meetingDate: day,
    title: title,
    createdAt: DateTime(2026, 8, 1),
  );
}

BaptismMeetingRoll _roll(
  BaptismMeeting meeting,
  List<BaptismStudent> students,
  Map<String, BaptismAttendanceStatus> marks,
) {
  return BaptismMeetingRoll(
    meeting: meeting,
    students: students,
    statusByStudent: marks,
  );
}

const _presente = BaptismAttendanceStatus.presente;
const _ausente = BaptismAttendanceStatus.ausente;
const _justificado = BaptismAttendanceStatus.justificado;

void main() {
  group('BaptismStudentFrequency — as três regras do percentual', () {
    // As regras estão no topo de baptism_attendance_report.dart. Este grupo
    // é o que impede que alguém as mude sem querer: cada teste falha com o
    // número errado, não com uma exceção.
    final ana = _student('Ana');
    final bruno = _student('Bruno');

    BaptismTurmaAttendanceReport reportOf(
      Map<String, BaptismAttendanceStatus> m1,
      Map<String, BaptismAttendanceStatus> m2,
    ) {
      return BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(_meeting('e1', day: DateTime(2026, 8, 7)), [ana, bruno], m1),
          _roll(_meeting('e2', day: DateTime(2026, 8, 14)), [ana, bruno], m2),
        ],
      );
    }

    test('justificado conta como falta, e fica visível na coluna J', () {
      final report = reportOf(
        {ana.id: _presente, bruno.id: _presente},
        {ana.id: _justificado, bruno.id: _presente},
      );
      final linhaAna = report.lines.firstWhere((l) => l.student.id == ana.id);

      expect(linhaAna.justified, 1);
      expect(linhaAna.present, 1);
      expect(linhaAna.marked, 2);
      // 1 presença em 2 encontros marcados — a justificada pesa como falta.
      expect(linhaAna.rate, 0.5);
      // E o mesmo número relevado, que só o adendo do rodapé usa.
      expect(linhaAna.rateWithJustified, 1.0);
    });

    test('encontro não marcado fica fora do denominador', () {
      final report = reportOf(
        {ana.id: _presente, bruno.id: _presente},
        // O segundo encontro não teve chamada para a Ana.
        {bruno.id: _ausente},
      );
      final linhaAna = report.lines.firstWhere((l) => l.student.id == ana.id);

      expect(linhaAna.unmarked, 1);
      expect(linhaAna.marked, 1);
      // 100%, e não 50%: ninguém passou por ela no segundo encontro.
      expect(linhaAna.rate, 1.0);

      final linhaBruno = report.lines.firstWhere((l) => l.student.id == bruno.id);
      expect(linhaBruno.absent, 1);
      expect(linhaBruno.rate, 0.5);
    });

    test('aluno sem marcação nenhuma não tem percentual, e não tem zero', () {
      final report = reportOf(const {}, const {});
      final linhaAna = report.lines.firstWhere((l) => l.student.id == ana.id);

      expect(linhaAna.marked, 0);
      expect(linhaAna.rate, isNull);
      expect(linhaAna.unmarked, 2);
      expect(formatFrequency(linhaAna.rate), '—');
    });
  });

  group('BaptismTurmaAttendanceReport', () {
    final ana = _student('ana');
    final bruno = _student('Bruno');
    final zeca = _student('Zeca', turmaId: 'turma-2');

    test('pega só os encontros da turma pedida', () {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(_meeting('e1', day: DateTime(2026, 8, 7)), [ana, bruno], {
            ana.id: _presente,
          }),
          _roll(
            _meeting('e9', turmaId: 'turma-2', day: DateTime(2026, 8, 8)),
            [zeca],
            {zeca.id: _presente},
          ),
        ],
      );

      expect(report.meetingCount, 1);
      expect(report.studentCount, 2);
      expect(report.lines.map((l) => l.student.fullName), ['ana', 'Bruno']);
    });

    test('os encontros saem do mais antigo para o mais novo', () {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(_meeting('e3', day: DateTime(2026, 8, 21)), [ana], const {}),
          _roll(_meeting('e1', day: DateTime(2026, 8, 7)), [ana], const {}),
          _roll(_meeting('e2', day: DateTime(2026, 8, 14)), [ana], const {}),
        ],
      );

      expect(report.meetings.map((m) => m.id), ['e1', 'e2', 'e3']);
    });

    test('dois encontros no mesmo dia desempatam pelo título', () {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(
            _meeting('noite', day: DateTime(2026, 8, 7), title: 'Noite'),
            [ana],
            const {},
          ),
          _roll(
            _meeting('manha', day: DateTime(2026, 8, 7), title: 'Manhã'),
            [ana],
            const {},
          ),
        ],
      );

      expect(report.meetings.map((m) => m.id), ['manha', 'noite']);
    });

    test('totais da turma seguem a mesma régua da linha do aluno', () {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(_meeting('e1', day: DateTime(2026, 8, 7)), [ana, bruno], {
            ana.id: _presente,
            bruno.id: _justificado,
          }),
          _roll(_meeting('e2', day: DateTime(2026, 8, 14)), [ana, bruno], {
            ana.id: _ausente,
          }),
        ],
      );

      expect(report.totalPresent, 1);
      expect(report.totalJustified, 1);
      expect(report.totalAbsent, 1);
      expect(report.totalUnmarked, 1);
      expect(report.totalMarked, 3);
      expect(report.rate, closeTo(1 / 3, 0.0001));
      expect(report.rateWithJustified, closeTo(2 / 3, 0.0001));
      expect(report.hasJustified, isTrue);
    });

    test('turma sem encontro é vazia, e não é 0%', () {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        rolls: const [],
      );

      expect(report.isEmpty, isTrue);
      expect(report.meetingCount, 0);
      expect(report.rate, isNull);
      expect(report.hasJustified, isFalse);
    });
  });

  group('formatação da folha', () {
    test('formatFrequency arredonda para inteiro e trata o nulo', () {
      expect(formatFrequency(1.0), '100%');
      expect(formatFrequency(0.875), '88%');
      expect(formatFrequency(0), '0%');
      expect(formatFrequency(null), '—');
      expect(formatFrequency(null, fallback: 'n/d'), 'n/d');
    });

    test('a grade marca os quatro estados, inclusive o não-marcado', () {
      expect(frequencyCell(_presente), 'P');
      expect(frequencyCell(_ausente), 'F');
      expect(frequencyCell(_justificado), 'J');
      expect(frequencyCell(null), '·');
    });

    test('formatMeetingShortDate usa o dia do encontro, sem hora', () {
      final meeting = _meeting('e1', day: DateTime(2026, 9, 7, 20, 30));
      expect(formatMeetingShortDate(meeting), '07/09');
    });
  });

  group('PDF das folhas de presença', () {
    // Mesmo laço do grupo equivalente em batismo_relatorios_tab_test.dart: a
    // fonte base só desenha Latin-1, e o que passa disso não estoura — vira
    // um vão na folha e um aviso no console.
    Future<List<String>> fontWarnings(Future<void> Function() body) async {
      final logs = <String>[];
      await runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ),
      );
      return logs.where((l) => l.contains('Unable to find a font')).toList();
    }

    final ana = _student('Ana \u{1F64F} Conceição');
    final bruno = _student('João – filho');

    BaptismMeetingRoll sujo() => _roll(
          _meeting(
            'e1',
            day: DateTime(2026, 9, 18),
            title: 'Encontro — aula “inaugural”',
          ),
          [ana, bruno],
          {ana.id: _presente},
        );

    test('folha preenchida sai sem vão', () async {
      final avisos = await fontWarnings(() async {
        final bytes = await buildBaptismMeetingSheetPdf(
          sujo(),
          ministryName: 'Batismo nas Águas',
          generatedAt: DateTime(2026, 9, 24, 14, 30),
        );
        expect(bytes, isNotEmpty);
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });

    test('folha em branco sai sem vão', () async {
      final avisos = await fontWarnings(() async {
        final bytes = await buildBaptismMeetingSheetPdf(
          sujo(),
          ministryName: 'Batismo nas Águas',
          generatedAt: DateTime(2026, 9, 24, 14, 30),
          blank: true,
        );
        expect(bytes, isNotEmpty);
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });

    test('folha de frequência sai sem vão, com grade', () async {
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Turma — sexta'),
        ministryName: 'Batismo nas Águas',
        rolls: [
          _roll(_meeting('e1', day: DateTime(2026, 8, 7)), [ana, bruno], {
            ana.id: _presente,
            bruno.id: _justificado,
          }),
          _roll(_meeting('e2', day: DateTime(2026, 8, 14)), [ana, bruno], {
            ana.id: _ausente,
          }),
        ],
      );

      final avisos = await fontWarnings(() async {
        final bytes = await buildBaptismFrequencyPdf(
          report,
          generatedAt: DateTime(2026, 9, 24, 14, 30),
        );
        expect(bytes, isNotEmpty);
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });

    test('turma com muitos encontros imprime sem a grade, e não estoura',
        () async {
      // 20 encontros: acima do limite em que a grade cabe na folha.
      final rolls = [
        for (var i = 1; i <= 20; i++)
          _roll(
            _meeting('e$i', day: DateTime(2026, 5, 1).add(Duration(days: i * 7))),
            [ana],
            {ana.id: _presente},
          ),
      ];
      final report = BaptismTurmaAttendanceReport.build(
        turma: _turma('turma-1', 'Turma longa'),
        ministryName: 'Batismo nas Águas',
        rolls: rolls,
      );

      expect(report.meetingCount, 20);

      final avisos = await fontWarnings(() async {
        final bytes = await buildBaptismFrequencyPdf(
          report,
          generatedAt: DateTime(2026, 9, 24, 14, 30),
        );
        expect(bytes, isNotEmpty);
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });

    test('encontro sem aluno imprime o bloco de vazio, não uma folha em branco',
        () async {
      final avisos = await fontWarnings(() async {
        final bytes = await buildBaptismMeetingSheetPdf(
          _roll(
            _meeting('e1', day: DateTime(2026, 9, 18)),
            const [],
            const {},
          ),
          ministryName: 'Batismo nas Águas',
          generatedAt: DateTime(2026, 9, 24, 14, 30),
        );
        expect(bytes, isNotEmpty);
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });
  });
}
