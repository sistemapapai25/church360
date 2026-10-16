/// Etiquetas do Infantil (K5, cartilha §8.4): uma folha A4 com duas vias por
/// criança presente — a da criança (nome, sala, alerta de alergia, "sem
/// foto") e a do responsável — com o mesmo código de retirada. A igreja não
/// tem impressora: o PDF é para mandar imprimir fora.
///
/// Helvetica do pacote `pdf` só desenha Latin-1: todo texto passa por
/// [pdfSafeText].
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../ministries/batismo/domain/baptism_pdf_renderer.dart'
    show pdfSafeText;
import 'models/kids_checkin.dart';

/// Código curto de retirada, igual nas duas vias.
String kidsPickupCode(KidsChildCard card) => (card.attendanceId ?? card.childId)
    .replaceAll('-', '')
    .substring(0, 4)
    .toUpperCase();

Future<Uint8List> buildKidsBadgesPdf(
  List<KidsChildCard> cards, {
  String? eventName,
}) async {
  final doc = pw.Document(title: 'Etiquetas do Infantil');
  final red = PdfColor.fromHex('#B3261E');

  pw.Widget text(
    String s, {
    double size = 11,
    bool bold = false,
    PdfColor? color,
  }) => pw.Text(
    pdfSafeText(s),
    maxLines: 2,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    ),
  );

  pw.Widget label(KidsChildCard c, {required bool parent}) => pw.Container(
    height: 100,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            text(
              parent ? 'VIA DO RESPONSAVEL' : 'INFANTIL',
              size: 8,
              color: PdfColors.grey700,
            ),
            text(kidsPickupCode(c), size: 16, bold: true),
          ],
        ),
        pw.SizedBox(height: 4),
        text(c.name, size: 15, bold: true),
        text(
          [
            if (c.roomName != null) 'Sala ${c.roomName}',
            if (c.age != null) '${c.age} anos',
          ].join(' - '),
        ),
        pw.Spacer(),
        if (parent)
          text('Apresente esta via para retirar a crianca.', size: 8)
        else ...[
          if (c.foodAlert)
            text(
              'ALERGIA: ${[c.allergies, c.intolerances].whereType<String>().where((s) => s.trim().isNotEmpty).join('; ')}',
              size: 9,
              bold: true,
              color: red,
            ),
          if (!c.imageConsent)
            text('SEM FOTO', size: 9, bold: true, color: red),
        ],
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: text(
          eventName ?? 'Infantil',
          size: 10,
          color: PdfColors.grey700,
        ),
      ),
      build: (_) => [
        for (final c in cards)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Expanded(child: label(c, parent: false)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: label(c, parent: true)),
              ],
            ),
          ),
      ],
    ),
  );
  return doc.save();
}
