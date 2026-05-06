import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/lancamento.dart';

class FinanceiroExports {
  static Future<void> exportLancamentosPdf(
    BuildContext context, {
    required List<Lancamento> lancamentos,
    DateTime? startDate,
    DateTime? endDate,
    TipoLancamento? tipo,
    StatusLancamento? status,
  }) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final titleParts = <String>['Relatório de Lançamentos'];
    if (tipo != null) titleParts.add(tipo.label);
    if (status != null) titleParts.add(status.label);
    final title = titleParts.join(' • ');

    String? periodLabel;
    if (startDate != null && endDate != null) {
      periodLabel = '${dateFmt.format(startDate)} - ${dateFmt.format(endDate)}';
    } else if (startDate != null) {
      periodLabel = 'A partir de ${dateFmt.format(startDate)}';
    } else if (endDate != null) {
      periodLabel = 'Até ${dateFmt.format(endDate)}';
    }

    final total = lancamentos.fold<double>(0.0, (sum, l) => sum + l.valor);
    final totalPago = lancamentos
        .where((l) => l.status == StatusLancamento.pago)
        .fold<double>(0.0, (sum, l) => sum + (l.valorPago ?? l.valor));

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return [
            pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (periodLabel != null) pw.SizedBox(height: 4),
            if (periodLabel != null) pw.Text('Período: $periodLabel'),
            pw.SizedBox(height: 8),
            pw.Text('Itens: ${lancamentos.length}'),
            pw.Text('Total: ${money.format(total)}'),
            pw.Text('Total pago: ${money.format(totalPago)}'),
            pw.SizedBox(height: 16),
            _buildLancamentosTable(lancamentos, dateFmt, money),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'relatorio_lancamentos.pdf',
    );
  }

  static Future<void> exportLancamentosCsv(
    BuildContext context, {
    required List<Lancamento> lancamentos,
    DateTime? startDate,
    DateTime? endDate,
    TipoLancamento? tipo,
    StatusLancamento? status,
  }) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final headers = [
      'vencimento',
      'descricao',
      'tipo',
      'categoria',
      'beneficiario',
      'conta',
      'valor',
      'status',
    ];

    String esc(String value) {
      final v = value.replaceAll('"', '""');
      return '"$v"';
    }

    final rows = <List<String>>[
      headers,
      ...lancamentos.map((l) {
        return [
          dateFmt.format(l.vencimento),
          (l.descricao ?? '').trim(),
          l.tipo.label,
          (l.categoriaNome ?? '').trim().isEmpty ? l.categoriaId : l.categoriaNome!,
          (l.beneficiarioNome ?? '-').trim().isEmpty ? '-' : l.beneficiarioNome!,
          (l.contaNome ?? '-').trim().isEmpty ? '-' : l.contaNome!,
          money.format(l.valor),
          l.status.label,
        ];
      }),
    ];

    final sb = StringBuffer();
    for (final row in rows) {
      sb.writeln(row.map(esc).join(';'));
    }
    final csv = sb.toString();

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV copiado para a área de transferência.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    await Share.share(
      csv,
      subject: 'relatorio_lancamentos.csv',
    );
  }

  static pw.Widget _buildLancamentosTable(
    List<Lancamento> lancamentos,
    DateFormat dateFmt,
    NumberFormat money,
  ) {
    final headers = <String>[
      'Venc.',
      'Descrição',
      'Tipo',
      'Categoria',
      'Beneficiário',
      'Conta',
      'Valor',
      'Status',
    ];

    final data = lancamentos.map((l) {
      return [
        dateFmt.format(l.vencimento),
        (l.descricao ?? '').trim(),
        l.tipo.label,
        (l.categoriaNome ?? '').trim().isEmpty ? l.categoriaId : l.categoriaNome!,
        (l.beneficiarioNome ?? '-').trim().isEmpty ? '-' : l.beneficiarioNome!,
        (l.contaNome ?? '-').trim().isEmpty ? '-' : l.contaNome!,
        money.format(l.valor),
        l.status.label,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(48),
        2: const pw.FixedColumnWidth(46),
        6: const pw.FixedColumnWidth(62),
        7: const pw.FixedColumnWidth(56),
      },
    );
  }
}
