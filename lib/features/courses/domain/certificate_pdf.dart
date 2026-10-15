/// PDF do certificado do curso (E5).
///
/// Mesma régua dos outros PDFs do app: Helvetica embutida do pacote `pdf`,
/// que só desenha Latin-1, por isso todo texto passa por [pdfSafeText]
/// (sem emoji, sem travessão). A4 deitado, uma página.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../ministries/batismo/domain/baptism_pdf_renderer.dart'
    show pdfSafeText;
import 'models/course_quiz.dart';

Future<Uint8List> buildCertificatePdf(CertificateInfo info) async {
  final doc = pw.Document(title: 'Certificado - ${pdfSafeText(info.courseTitle)}');
  final d = info.issuedAt.toLocal();
  final date =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final accent = PdfColor.fromHex('#1E4FA3');

  pw.Widget text(
    String s, {
    double size = 14,
    bool bold = false,
    PdfColor? color,
  }) => pw.Text(
    pdfSafeText(s),
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: accent, width: 3),
        ),
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            text(info.churchName, size: 16, bold: true, color: accent),
            pw.SizedBox(height: 24),
            text('CERTIFICADO', size: 34, bold: true, color: accent),
            pw.SizedBox(height: 24),
            text('Certificamos que'),
            pw.SizedBox(height: 8),
            text(info.personName, size: 26, bold: true),
            pw.SizedBox(height: 8),
            text('concluiu o curso'),
            pw.SizedBox(height: 8),
            text(info.courseTitle, size: 22, bold: true),
            pw.SizedBox(height: 24),
            text('Emitido em $date'),
            pw.Spacer(),
            text(
              'Codigo ${info.code} - valide em papai.church360.com.br/certificado/${info.code}',
              size: 10,
              color: PdfColors.grey700,
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
