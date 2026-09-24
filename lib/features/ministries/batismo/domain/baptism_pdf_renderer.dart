/// Os PDFs da aba Relatórios.
///
/// Recebe os dados já agregados por [BaptismTurmaReport] /
/// [BaptismMinistryReport] e devolve bytes — não toca em provider, em
/// contexto nem em `Printing`. Quem decide se aquilo vai para a impressora
/// ou para o compartilhar é a tela.
///
/// Fonte: a Helvetica embutida do pacote `pdf`, a mesma dos outros dois
/// PDFs do app (escala e financeiro). Registrar uma fonte própria custaria um
/// asset novo sem ganho visível, e o preço de não registrar é real: as fontes
/// base só desenham **Latin-1** (até U+00FF). O que passa disso não estoura —
/// o pacote escreve um aviso no console e deixa um vão na folha. Por isso
/// todo texto que entra no PDF passa por [pdfSafeText].
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'baptism_attendance_report.dart';
import 'baptism_attendance_roll.dart';
import 'baptism_report_data.dart';
import 'models/baptism_attendance.dart';
import 'models/baptism_student.dart';

/// Texto que a Helvetica embutida consegue desenhar.
///
/// As fontes base do pacote `pdf` cobrem Latin-1 e nada mais. Caractere fora
/// disso não gera erro: vira um vão na folha, e quem imprimiu só descobre
/// olhando o papel. Como nome, e-mail e nome de turma sao digitados por
/// gente — e boa parte chega colada do WhatsApp, com travessao, aspas curvas
/// e emoji —, todo texto que entra no PDF passa por aqui.
///
/// O que tem equivalente vira o equivalente; o que nao tem vira `?`, para
/// que a falta apareca em vez de sumir.
String pdfSafeText(String input) {
  const swaps = <String, String>{
    '—': '-',
    '–': '-',
    '−': '-',
    '•': '·',
    '…': '...',
    '‘': "'",
    '’': "'",
    '‚': "'",
    '“': '"',
    '”': '"',
    '„': '"',
    '→': '->',
    ' ': ' ',
    '€': 'EUR',
    '™': '(TM)',
  };

  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final swap = swaps[ch];
    if (swap != null) {
      out.write(swap);
    } else if (rune == 0x0a || rune == 0x09 || (rune >= 0x20 && rune <= 0xff)) {
      out.write(ch);
    } else {
      out.write('?');
    }
  }
  return out.toString();
}

/// `pw.Text` que já sai saneado. Usar este, e não `pw.Text` direto.
pw.Widget _text(String data, {pw.TextStyle? style, pw.TextAlign? textAlign}) {
  return pw.Text(pdfSafeText(data), style: style, textAlign: textAlign);
}

/// Cabeçalho comum: nome do ministério, título do relatório e a data de
/// emissão. Relatório sem data de emissão não serve para conferir nada —
/// quem olha a folha não tem como saber se é de hoje ou de março.
pw.Widget _header({
  required String ministryName,
  required String title,
  required String subtitle,
  required DateTime generatedAt,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(
                  ministryName,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 2),
                _text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _text(
            'Emitido em ${_stamp(generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
      if (subtitle.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        _text(subtitle, style: const pw.TextStyle(fontSize: 10)),
      ],
      pw.SizedBox(height: 10),
      pw.Divider(height: 1, thickness: 0.8, color: PdfColors.grey400),
      pw.SizedBox(height: 12),
    ],
  );
}

pw.Widget _footer(pw.Context context) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: _text(
      'Página ${context.pageNumber} de ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ),
  );
}

/// Linha de contagem por situação, usada nos dois relatórios.
pw.Widget _tallyLine(BaptismStatusTally tally) {
  final parts = [
    'Total: ${tally.total}',
    for (final s in BaptismStudentStatus.values)
      '${s.label}: ${tally.forStatus(s)}',
  ];
  return _text(
    parts.join('   ·   '),
    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
  );
}

/// Bloco de "não há nada aqui", em vez de uma tabela vazia.
///
/// Turma sem aluno é o caso que o aceite desta aba cobra: o PDF precisa
/// dizer que está vazio, com o cabeçalho e a data no lugar. Folha em branco
/// parece erro de impressão, e erro de impressão manda a pessoa gerar de
/// novo.
pw.Widget _emptyBlock(String message) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Center(
      child: _text(
        message,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    ),
  );
}

/// Relatório da turma: a lista nominal com situação, contato e idade.
Future<Uint8List> buildBaptismTurmaPdf(
  BaptismTurmaReport report, {
  required DateTime generatedAt,
}) async {
  final turma = report.turma;
  final label = turma.eventTypeLabel;
  final subtitleParts = <String>[
    'Período: ${formatTurmaPeriod(turma)}',
    'Situação da turma: ${turma.status.label}',
    if (label != null && label.trim().isNotEmpty)
      'Categoria na agenda: ${label.trim()}',
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (context) => [
        _header(
          ministryName: report.ministryName,
          title: 'Turma ${turma.name}',
          subtitle: subtitleParts.join('   ·   '),
          generatedAt: generatedAt,
        ),
        _tallyLine(report.tally),
        pw.SizedBox(height: 12),
        if (report.isEmpty)
          _emptyBlock(
            'Nenhum aluno cadastrado nesta turma até a emissão deste '
            'relatório.',
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              '#',
              'Nome',
              'Situação',
              'Nascimento',
              'Idade',
              'WhatsApp',
              'E-mail',
            ],
            data: [
              for (var i = 0; i < report.students.length; i++)
                _studentRow(i + 1, report.students[i]),
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              2: const pw.FixedColumnWidth(54),
              3: const pw.FixedColumnWidth(58),
              4: const pw.FixedColumnWidth(34),
              5: const pw.FixedColumnWidth(84),
            },
          ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

List<String> _studentRow(int index, BaptismStudent student) {
  final age = student.age;
  return [
    '$index',
    student.fullName.trim(),
    student.status.label,
    formatReportDate(student.birthDate),
    age == null ? '—' : '$age',
    _orDash(student.phone),
    _orDash(student.email),
  ].map(pdfSafeText).toList();
}

/// Resumo do ministério: alunos por situação, alunos por turma e o total de
/// turmas.
Future<Uint8List> buildBaptismMinistryPdf(
  BaptismMinistryReport report, {
  required DateTime generatedAt,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (context) => [
        _header(
          ministryName: report.ministryName,
          title: 'Resumo do ministério',
          subtitle: '${report.turmaCount} '
              '${report.turmaCount == 1 ? 'turma' : 'turmas'} '
              '(${report.activeTurmaCount} '
              '${report.activeTurmaCount == 1 ? 'ativa' : 'ativas'})',
          generatedAt: generatedAt,
        ),
        _tallyLine(report.tally),
        pw.SizedBox(height: 14),
        _text(
          'Alunos por turma',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (report.lines.isEmpty)
          _emptyBlock(
            'Nenhuma turma cadastrada neste ministério até a emissão deste '
            'relatório.',
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Turma',
              'Período',
              'Situação',
              'Ativos',
              'Concluídos',
              'Desistentes',
              'Total',
            ],
            data: [
              for (final line in report.lines)
                [
                  line.turma.name.trim(),
                  formatTurmaPeriod(line.turma),
                  line.turma.status.label,
                  '${line.tally.ativo}',
                  '${line.tally.concluido}',
                  '${line.tally.desistente}',
                  '${line.tally.total}',
                ].map(pdfSafeText).toList(),
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
            columnWidths: {
              1: const pw.FixedColumnWidth(108),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(58),
              5: const pw.FixedColumnWidth(62),
              6: const pw.FixedColumnWidth(38),
            },
          ),
        if (report.orphanStudents > 0) ...[
          pw.SizedBox(height: 10),
          _text(
            '${report.orphanStudents} aluno(a)(s) em turma que não aparece '
            'nesta lista — a soma por turma não fecha com o total geral.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// ---------------------------------------------------------------------------
// Etapa E — as folhas de presença
// ---------------------------------------------------------------------------

/// Acima disso a grade de encontros não cabe nem em paisagem, e a folha sai
/// só com os totais. O limite é de largura de papel, não de regra: cada
/// coluna de encontro precisa de ~26pt para o `18/09` do cabeçalho caber.
const int _kMaxGridMeetings = 14;

/// A chamada de um encontro.
///
/// [blank] decide as duas saídas do mesmo card: `false` imprime o que já foi
/// marcado no app (para conferir e arquivar), `true` imprime a folha vazia
/// com quadradinhos e linha de assinatura (para levar à aula e preencher à
/// mão). É a mesma lista nominal nas duas — quem preencheu no papel digita
/// depois na mesma ordem, sem procurar nome.
Future<Uint8List> buildBaptismMeetingSheetPdf(
  BaptismMeetingRoll roll, {
  required String ministryName,
  required DateTime generatedAt,
  bool blank = false,
}) async {
  final meeting = roll.meeting;
  final subtitle = [
    'Encontro: ${formatReportDate(meeting.day)}',
    if ((meeting.turmaName ?? '').trim().isNotEmpty)
      'Turma: ${meeting.turmaName!.trim()}',
    'Alunos: ${roll.total}',
  ].join('   ·   ');

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (context) => [
        _header(
          ministryName: ministryName,
          title: blank
              ? 'Chamada — ${meeting.title}'
              : 'Presença — ${meeting.title}',
          subtitle: subtitle,
          generatedAt: generatedAt,
        ),
        if (!blank) ...[
          _rollTallyLine(roll),
          pw.SizedBox(height: 12),
        ],
        if (roll.students.isEmpty)
          _emptyBlock(
            'Nenhum aluno na turma deste encontro até a emissão desta folha.',
          )
        else if (blank)
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Nome', 'Presença', 'Assinatura'],
            data: [
              for (var i = 0; i < roll.students.length; i++)
                [
                  '${i + 1}',
                  pdfSafeText(roll.students[i].fullName.trim()),
                  '( ) Presente   ( ) Faltou   ( ) Justificado',
                  '',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 26,
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.center},
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              2: const pw.FixedColumnWidth(150),
              3: const pw.FixedColumnWidth(120),
            },
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Nome', 'Presença', 'Situação do aluno'],
            data: [
              for (var i = 0; i < roll.students.length; i++)
                [
                  '${i + 1}',
                  pdfSafeText(roll.students[i].fullName.trim()),
                  _attendanceLabel(roll.statusOf(roll.students[i])),
                  roll.students[i].status.label,
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.center},
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              2: const pw.FixedColumnWidth(96),
              3: const pw.FixedColumnWidth(96),
            },
          ),
        if (!blank && roll.unmarked > 0) ...[
          pw.SizedBox(height: 10),
          _note(
            '${roll.unmarked} aluno(a)(s) sem marcação neste encontro. '
            'Não-marcado não é falta: a chamada ainda não passou por essa '
            'pessoa.',
          ),
        ],
        if ((meeting.notes ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _note('Observações do encontro: ${meeting.notes!.trim()}'),
        ],
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

/// Frequência da turma: a grade aluno x encontro e o percentual de cada um.
///
/// Sai em **paisagem** porque a grade cresce para o lado a cada encontro. Com
/// mais de [_kMaxGridMeetings] encontros a grade é omitida e ficam só os
/// totais — melhor uma folha honesta sem grade do que uma grade ilegível.
Future<Uint8List> buildBaptismFrequencyPdf(
  BaptismTurmaAttendanceReport report, {
  required DateTime generatedAt,
}) async {
  final showGrid =
      report.meetingCount > 0 && report.meetingCount <= _kMaxGridMeetings;

  final headers = <String>[
    '#',
    'Nome',
    if (showGrid) for (final m in report.meetings) formatMeetingShortDate(m),
    'P',
    'J',
    'F',
    'Freq.',
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: _footer,
      build: (context) => [
        _header(
          ministryName: report.ministryName,
          title: 'Frequência — turma ${report.turma.name}',
          subtitle: attendanceSubtitle(report),
          generatedAt: generatedAt,
        ),
        if (report.isEmpty)
          _emptyBlock(
            report.meetingCount == 0
                ? 'Esta turma ainda não tem encontro registrado — não há '
                    'frequência a calcular.'
                : 'Nenhum aluno na turma até a emissão deste relatório.',
          )
        else ...[
          _text(
            'Frequência da turma: ${formatFrequency(report.rate)}   ·   '
            'Presenças: ${report.totalPresent}   ·   '
            'Justificadas: ${report.totalJustified}   ·   '
            'Faltas: ${report.totalAbsent}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: [
              for (var i = 0; i < report.lines.length; i++)
                _frequencyRow(i + 1, report.lines[i], report, showGrid),
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {1: pw.Alignment.centerLeft},
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(),
            },
          ),
          pw.SizedBox(height: 12),
          _note(
            'Freq. = presenças dividido pelos encontros em que o aluno foi '
            'marcado. Encontro sem marcação fica fora da conta dele — '
            'não-marcado não é falta.',
          ),
          if (report.hasJustified)
            _note(
              'Falta justificada entra na conta como falta e aparece na '
              'coluna J. Relevando as justificadas, a frequência da turma '
              'seria ${formatFrequency(report.rateWithJustified)}.',
            ),
          if (showGrid)
            _note('Na grade: P presente, F faltou, J justificado, · não marcado.')
          else if (report.meetingCount > _kMaxGridMeetings)
            _note(
              'A turma tem ${report.meetingCount} encontros — a grade por '
              'encontro não cabe na folha e só os totais foram impressos. A '
              'chamada de cada encontro sai na folha de presença.',
            ),
          if (report.totalUnmarked > 0)
            _note(
              '${report.totalUnmarked} marcação(ões) ainda não feita(s) nesta '
              'turma. Percentual alto com muita marcação faltando diz pouco: '
              'ele é calculado só sobre o que foi conferido.',
            ),
        ],
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

List<String> _frequencyRow(
  int index,
  BaptismStudentFrequency line,
  BaptismTurmaAttendanceReport report,
  bool showGrid,
) {
  return <String>[
    '$index',
    line.student.fullName.trim(),
    if (showGrid)
      for (final m in report.meetings) frequencyCell(line.statusOf(m)),
    '${line.present}',
    '${line.justified}',
    '${line.absent}',
    formatFrequency(line.rate),
  ].map(pdfSafeText).toList();
}

/// Contagem do encontro, com o não-marcado à vista.
///
/// O não-marcado é o número que impede a leitura errada da folha: sem ele,
/// um encontro com 2 presentes e 18 pessoas sem chamada pareceria um
/// encontro em que 18 faltaram.
pw.Widget _rollTallyLine(BaptismMeetingRoll roll) {
  final parts = [
    'Total: ${roll.total}',
    'Presentes: ${roll.present}',
    'Justificados: ${roll.justified}',
    'Faltas: ${roll.absent}',
    'Sem marcação: ${roll.unmarked}',
  ];
  return _text(
    parts.join('   ·   '),
    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
  );
}

String _attendanceLabel(BaptismAttendanceStatus? status) =>
    status?.label ?? 'Não marcado';

/// Observação de rodapé — o lugar onde a folha explica a própria conta.
pw.Widget _note(String message) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: _text(
      message,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  );
}

String _orDash(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? '—' : trimmed;
}

String _stamp(DateTime when) {
  final d = when.day.toString().padLeft(2, '0');
  final m = when.month.toString().padLeft(2, '0');
  final h = when.hour.toString().padLeft(2, '0');
  final min = when.minute.toString().padLeft(2, '0');
  return '$d/$m/${when.year} às $h:$min';
}
