/// Agregações de presença do Batismo — a Etapa E dos relatórios.
///
/// Camada pura, como `baptism_report_data.dart` e `baptism_attendance_roll.dart`:
/// recebe as chamadas já casadas (`BaptismMeetingRoll`) e devolve números.
/// Não fala com Supabase nem com tela, e é por isso que a regra de contagem
/// pode ser conferida num teste — um relatório que conta errado é pior do que
/// relatório nenhum, porque ninguém desconfia de um número impresso.
///
/// **As três regras que decidem o percentual** (fechadas com o usuário em
/// 24/09, e a razão de cada uma):
///
/// 1. **Justificado conta como falta.** Entra no denominador e fica fora do
///    numerador. O percentual responde "esteve na aula?", não "tinha motivo?".
///    Para a justificativa não sumir, ela tem coluna própria e é dita no
///    rodapé — ver [BaptismStudentFrequency.rateWithJustified], que é o mesmo
///    número relevado e existe só para o adendo.
/// 2. **O denominador é só o que foi marcado.** Encontro em que o aluno não
///    tem linha fica fora da conta dele. É a regra "não-marcado != ausente"
///    que o módulo já respeita desde a Etapa D: aluno matriculado depois da
///    3ª aula não pode ser acusado de ter faltado a ela, e chamada que
///    ninguém fez não é falta de ninguém.
/// 3. **Aluno sem nenhuma marcação não tem percentual** — [BaptismStudentFrequency.rate]
///    é `null`, e a folha imprime um travessão. Zero por cento diria que ele
///    faltou a tudo, o que é uma afirmação que o banco não sustenta.
library;

import 'baptism_attendance_roll.dart';
import 'baptism_report_data.dart';
import 'models/baptism_attendance.dart';
import 'models/baptism_meeting.dart';
import 'models/baptism_student.dart';
import 'models/baptism_turma.dart';

/// A frequência de um aluno na turma dele.
class BaptismStudentFrequency {
  final BaptismStudent student;

  /// O que foi marcado deste aluno, encontro a encontro. Encontro fora do
  /// mapa é não-marcado — nunca falta.
  final Map<String, BaptismAttendanceStatus> statusByMeeting;

  final int present;
  final int absent;
  final int justified;

  /// Encontros da turma em que este aluno não tem linha nenhuma.
  final int unmarked;

  const BaptismStudentFrequency({
    required this.student,
    required this.statusByMeeting,
    required this.present,
    required this.absent,
    required this.justified,
    required this.unmarked,
  });

  /// Encontros que contam para o percentual deste aluno.
  int get marked => present + absent + justified;

  /// Presenças ÷ encontros marcados, de 0 a 1. `null` quando não há nada
  /// marcado — ver regra 3 no topo do arquivo.
  double? get rate => marked == 0 ? null : present / marked;

  /// O mesmo percentual relevando as justificadas. Existe só para o adendo
  /// do rodapé; não é o número da coluna.
  double? get rateWithJustified =>
      marked == 0 ? null : (present + justified) / marked;

  BaptismAttendanceStatus? statusOf(BaptismMeeting meeting) =>
      statusByMeeting[meeting.id];
}

/// A frequência de uma turma inteira: os encontros, a linha de cada aluno e
/// os totais.
class BaptismTurmaAttendanceReport {
  final BaptismTurma turma;
  final String ministryName;

  /// Encontros da turma, **do mais antigo para o mais novo**.
  ///
  /// Ordem contrária à da aba Presença, que abre na última aula porque é
  /// nela que se marca. Aqui a folha é lida da esquerda para a direita, na
  /// ordem em que as aulas aconteceram.
  final List<BaptismMeeting> meetings;

  /// Uma linha por aluno, em ordem alfabética — a mesma do relatório da
  /// turma, para conferir nome a nome nas duas folhas.
  final List<BaptismStudentFrequency> lines;

  const BaptismTurmaAttendanceReport({
    required this.turma,
    required this.ministryName,
    required this.meetings,
    required this.lines,
  });

  /// Monta o relatório de [turma] a partir das chamadas do ministério.
  ///
  /// [rolls] são as de todos os encontros (o que
  /// `baptismMeetingRollsProvider` entrega); a filtragem por turma acontece
  /// aqui, num lugar só.
  factory BaptismTurmaAttendanceReport.build({
    required BaptismTurma turma,
    required String ministryName,
    required List<BaptismMeetingRoll> rolls,
  }) {
    final mine = rolls.where((r) => r.meeting.turmaId == turma.id).toList()
      ..sort(_byMeetingDayThenTitle);

    // Os alunos saem das próprias chamadas: buildBaptismMeetingRolls já
    // colocou em cada encontro os alunos da turma dele. Turma sem encontro
    // nenhum cai no mapa vazio, e a folha diz isso em vez de mentir zero.
    final students = <String, BaptismStudent>{};
    for (final roll in mine) {
      for (final s in roll.students) {
        students[s.id] = s;
      }
    }

    final ordered = students.values.toList()..sort(_byStudentName);

    final lines = <BaptismStudentFrequency>[];
    for (final student in ordered) {
      final statuses = <String, BaptismAttendanceStatus>{};
      var present = 0;
      var absent = 0;
      var justified = 0;
      var unmarked = 0;

      for (final roll in mine) {
        // Encontro de uma turma que o aluno não frequenta não deveria
        // aparecer aqui — mas se aparecer, não conta contra ele.
        if (!roll.students.any((s) => s.id == student.id)) continue;

        final status = roll.statusByStudent[student.id];
        if (status == null) {
          unmarked++;
          continue;
        }
        statuses[roll.meeting.id] = status;
        switch (status) {
          case BaptismAttendanceStatus.presente:
            present++;
          case BaptismAttendanceStatus.ausente:
            absent++;
          case BaptismAttendanceStatus.justificado:
            justified++;
        }
      }

      lines.add(
        BaptismStudentFrequency(
          student: student,
          statusByMeeting: statuses,
          present: present,
          absent: absent,
          justified: justified,
          unmarked: unmarked,
        ),
      );
    }

    return BaptismTurmaAttendanceReport(
      turma: turma,
      ministryName: ministryName,
      meetings: [for (final r in mine) r.meeting],
      lines: lines,
    );
  }

  int get meetingCount => meetings.length;

  int get studentCount => lines.length;

  bool get isEmpty => meetings.isEmpty || lines.isEmpty;

  int get totalPresent => lines.fold(0, (acc, l) => acc + l.present);
  int get totalAbsent => lines.fold(0, (acc, l) => acc + l.absent);
  int get totalJustified => lines.fold(0, (acc, l) => acc + l.justified);

  /// Quantas marcações faltam para a turma estar conferida por inteiro.
  ///
  /// É o número que explica um percentual alto numa turma que ninguém
  /// chamou: 100% de 1 encontro marcado entre 8 não é 100% de frequência.
  int get totalUnmarked => lines.fold(0, (acc, l) => acc + l.unmarked);

  int get totalMarked => totalPresent + totalAbsent + totalJustified;

  /// Frequência da turma: presenças ÷ marcações, pela mesma régua da linha
  /// do aluno (justificada conta como falta).
  double? get rate => totalMarked == 0 ? null : totalPresent / totalMarked;

  /// A mesma leitura relevando as justificadas — só para o adendo.
  double? get rateWithJustified =>
      totalMarked == 0 ? null : (totalPresent + totalJustified) / totalMarked;

  /// Há justificada em algum lugar? Sem nenhuma, o adendo do rodapé não
  /// precisa ser impresso: ele explicaria uma diferença que não existe.
  bool get hasJustified => totalJustified > 0;
}

/// `84%`, ou um travessão quando não há nada marcado.
///
/// Arredonda para inteiro: casa decimal em percentual de chamada dá falsa
/// precisão — 87,5% de 8 encontros é 7 presenças, e é isso que a coluna ao
/// lado já diz.
String formatFrequency(double? rate, {String fallback = '—'}) {
  if (rate == null) return fallback;
  return '${(rate * 100).round()}%';
}

/// Rótulo curto do encontro para o cabeçalho da grade: `18/09`.
String formatMeetingShortDate(BaptismMeeting meeting) {
  final d = meeting.day;
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm';
}

/// Como a grade marca cada estado. Uma letra, para caber na coluna estreita.
///
/// O ponto do não-marcado é intencional: uma célula em branco pareceria
/// falha de impressão, e um `0` pareceria falta.
String frequencyCell(BaptismAttendanceStatus? status) => switch (status) {
      BaptismAttendanceStatus.presente => 'P',
      BaptismAttendanceStatus.ausente => 'F',
      BaptismAttendanceStatus.justificado => 'J',
      null => '·',
    };

/// O subtítulo da folha de frequência, reaproveitando o formato de período
/// que o relatório da turma já usa.
String attendanceSubtitle(BaptismTurmaAttendanceReport report) {
  return [
    'Período: ${formatTurmaPeriod(report.turma)}',
    'Encontros: ${report.meetingCount}',
    'Alunos: ${report.studentCount}',
  ].join('   ·   ');
}

int _byStudentName(BaptismStudent a, BaptismStudent b) =>
    a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase());

/// Mais antigo primeiro; dois encontros no mesmo dia (manhã e noite são
/// permitidos pelo UNIQUE do banco) desempatam pelo título.
int _byMeetingDayThenTitle(BaptismMeetingRoll a, BaptismMeetingRoll b) {
  final byDate = a.meeting.day.compareTo(b.meeting.day);
  if (byDate != 0) return byDate;
  return a.meeting.title.toLowerCase().compareTo(b.meeting.title.toLowerCase());
}
