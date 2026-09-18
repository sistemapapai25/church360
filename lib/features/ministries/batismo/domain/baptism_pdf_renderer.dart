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

import 'baptism_report_data.dart';
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
