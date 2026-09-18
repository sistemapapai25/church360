/// Agregações dos relatórios do Batismo.
///
/// Tudo aqui é puro: recebe listas já carregadas e não fala com o Supabase
/// nem com a tela. É o que permite conferir a contagem num teste — um
/// relatório que conta errado é pior do que relatório nenhum, porque
/// ninguém desconfia de um número impresso.
///
/// As datas continuam sendo `DATE` de ponta a ponta (nascimento do aluno,
/// início e fim da turma). Nada aqui converte fuso nem promove data a
/// instante: `DATE` escapa do contrato de hora-de-parede-como-UTC que vale
/// para `event`, e é justamente por isso que essas datas são confiáveis.
library;

import 'models/baptism_student.dart';
import 'models/baptism_turma.dart';

/// Quantos alunos em cada situação.
class BaptismStatusTally {
  final int ativo;
  final int concluido;
  final int desistente;

  const BaptismStatusTally({
    required this.ativo,
    required this.concluido,
    required this.desistente,
  });

  factory BaptismStatusTally.of(Iterable<BaptismStudent> students) {
    var ativo = 0;
    var concluido = 0;
    var desistente = 0;
    for (final s in students) {
      switch (s.status) {
        case BaptismStudentStatus.ativo:
          ativo++;
        case BaptismStudentStatus.concluido:
          concluido++;
        case BaptismStudentStatus.desistente:
          desistente++;
      }
    }
    return BaptismStatusTally(
      ativo: ativo,
      concluido: concluido,
      desistente: desistente,
    );
  }

  int get total => ativo + concluido + desistente;

  int forStatus(BaptismStudentStatus status) => switch (status) {
        BaptismStudentStatus.ativo => ativo,
        BaptismStudentStatus.concluido => concluido,
        BaptismStudentStatus.desistente => desistente,
      };
}

/// O relatório de uma turma: a lista nominal mais a contagem por situação.
class BaptismTurmaReport {
  final BaptismTurma turma;

  /// Nome do ministério, para o cabeçalho. Um relatório sem contexto vira
  /// papel solto em cima da mesa.
  final String ministryName;

  /// Alunos da turma, em ordem alfabética.
  ///
  /// Alfabética, e não "com telefone primeiro" como na aba WhatsApp: lá a
  /// ordem serve para agir, aqui serve para conferir nome a nome numa
  /// folha impressa.
  final List<BaptismStudent> students;

  final BaptismStatusTally tally;

  BaptismTurmaReport({
    required this.turma,
    required this.ministryName,
    required this.students,
  }) : tally = BaptismStatusTally.of(students);

  /// Monta o relatório de [turma] a partir da lista completa do ministério.
  factory BaptismTurmaReport.build({
    required BaptismTurma turma,
    required String ministryName,
    required List<BaptismStudent> allStudents,
  }) {
    final students = allStudents.where((s) => s.turmaId == turma.id).toList()
      ..sort(_byName);
    return BaptismTurmaReport(
      turma: turma,
      ministryName: ministryName,
      students: students,
    );
  }

  bool get isEmpty => students.isEmpty;
}

/// Uma linha do resumo do ministério — uma turma e seus números.
class BaptismTurmaLine {
  final BaptismTurma turma;
  final BaptismStatusTally tally;

  const BaptismTurmaLine({required this.turma, required this.tally});
}

/// O resumo do ministério: alunos por situação, alunos por turma e o total
/// de turmas.
class BaptismMinistryReport {
  final String ministryName;
  final List<BaptismTurmaLine> lines;
  final BaptismStatusTally tally;

  /// Alunos cuja turma não está na lista carregada.
  ///
  /// Não deveria acontecer — `turma_id` é `NOT NULL` e as duas consultas
  /// saem do mesmo ministério —, mas se acontecer o total por turma não
  /// fecharia com o total geral e ninguém saberia por quê. Contar aqui faz
  /// a diferença aparecer no lugar de sumir.
  final int orphanStudents;

  const BaptismMinistryReport({
    required this.ministryName,
    required this.lines,
    required this.tally,
    required this.orphanStudents,
  });

  factory BaptismMinistryReport.build({
    required String ministryName,
    required List<BaptismTurma> turmas,
    required List<BaptismStudent> allStudents,
  }) {
    final byTurma = <String, List<BaptismStudent>>{};
    for (final s in allStudents) {
      byTurma.putIfAbsent(s.turmaId, () => []).add(s);
    }

    final ordered = [...turmas]..sort(_byTurmaStartThenName);
    final lines = [
      for (final t in ordered)
        BaptismTurmaLine(
          turma: t,
          tally: BaptismStatusTally.of(byTurma[t.id] ?? const []),
        ),
    ];

    final knownIds = turmas.map((t) => t.id).toSet();
    final orphans =
        allStudents.where((s) => !knownIds.contains(s.turmaId)).length;

    return BaptismMinistryReport(
      ministryName: ministryName,
      lines: lines,
      tally: BaptismStatusTally.of(allStudents),
      orphanStudents: orphans,
    );
  }

  int get turmaCount => lines.length;

  int get activeTurmaCount =>
      lines.where((l) => l.turma.status == BaptismTurmaStatus.ativa).length;

  bool get isEmpty => lines.isEmpty && tally.total == 0;
}

int _byName(BaptismStudent a, BaptismStudent b) => a.fullName
    .trim()
    .toLowerCase()
    .compareTo(b.fullName.trim().toLowerCase());

/// Turma mais recente primeiro; sem data de início, pelo nome. Turma sem
/// janela vai para o fim — é a que precisa de conserto, não a que precisa
/// de destaque.
int _byTurmaStartThenName(BaptismTurma a, BaptismTurma b) {
  final sa = a.startDate;
  final sb = b.startDate;
  if (sa != null && sb != null) {
    final cmp = sb.compareTo(sa);
    if (cmp != 0) return cmp;
  } else if (sa != null) {
    return -1;
  } else if (sb != null) {
    return 1;
  }
  return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
}

/// Rótulo de data no formato do app (`dd/MM/yyyy`), ou [fallback].
String formatReportDate(DateTime? date, {String fallback = '—'}) {
  if (date == null) return fallback;
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

/// O período da turma, do jeito que a lista de turmas já mostra.
String formatTurmaPeriod(BaptismTurma turma, {String fallback = 'Sem período'}) {
  final start = turma.startDate;
  final end = turma.endDate;
  if (start == null && end == null) return fallback;
  if (start != null && end != null) {
    return '${formatReportDate(start)} a ${formatReportDate(end)}';
  }
  return start != null
      ? 'A partir de ${formatReportDate(start)}'
      : 'Até ${formatReportDate(end)}';
}
