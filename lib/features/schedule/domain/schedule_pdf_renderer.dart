import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Uint8List?> renderEventSchedulePdf(SupabaseClient supabase, String eventId) async {
  final raw = await supabase
      .from('ministry_schedule')
      .select('''
        event!fk_ministry_schedule_event (name,start_date),
        ministry!fk_ministry_schedule_ministry (name),
        user_account!fk_ministry_schedule_user (first_name,last_name,nickname),
        ministry_function:function_id (name,code)
      ''')
      .eq('event_id', eventId);
  final res = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (res.isEmpty) return null;
  final first = res.first;
  final ev = first['event'] as Map<String, dynamic>?;
  final eventName = (ev?['name'] ?? '').toString();
  final startStr = ev?['start_date']?.toString();
  final eventDate = startStr != null ? DateTime.parse(startStr) : null;
  final groupedUsers = <String, List<Map<String, String>>>{};
  final uniqueUserIds = <String>{};
  for (final row in res) {
    final func = row['ministry_function'] as Map<String, dynamic>?;
    final member = row['user_account'] as Map<String, dynamic>?;
    final fName = (func?['name'] ?? func?['code'] ?? '').toString();
    final nick = (member?['nickname'] ?? member?['apelido'] ?? '').toString().trim();
    final fn = (member?['first_name'] ?? '').toString();
    final ln = (member?['last_name'] ?? '').toString();
    final uName = nick.isNotEmpty ? nick : ('$fn $ln').trim();
    final uid = (member?['id'] ?? '').toString();
    uniqueUserIds.add(uid);
    groupedUsers.putIfAbsent(fName, () => []).add({'id': uid, 'name': uName});
  }

  final palette = <PdfColor>[
    PdfColors.red,
    PdfColors.blue,
    PdfColors.green,
    PdfColors.orange,
    PdfColors.purple,
    PdfColors.cyan,
    PdfColors.lime,
    PdfColors.pink,
    PdfColors.teal,
    PdfColors.amber,
    PdfColors.indigo,
    PdfColors.brown,
    PdfColors.deepOrange,
    PdfColors.lightBlue,
    PdfColors.deepPurple,
    PdfColors.lightGreen,
  ];
  int idxFor(String s) {
    int h = 0;
    for (final c in s.codeUnits) { h = (h * 31 + c) & 0x7fffffff; }
    return h % palette.length;
  }
  final used = <int>{};
  final colorForUser = <String, PdfColor>{};
  for (final uid in uniqueUserIds) {
    int i = idxFor(uid);
    int loops = 0;
    while (used.contains(i) && loops < palette.length) { i = (i + 1) % palette.length; loops++; }
    used.add(i);
    colorForUser[uid] = palette[i];
  }

  final funcs = groupedUsers.keys.toList()..sort();
  String dowAbbrevPt(DateTime d) {
    const map = {
      DateTime.monday: 'Seg',
      DateTime.tuesday: 'Ter',
      DateTime.wednesday: 'Qua',
      DateTime.thursday: 'Qui',
      DateTime.friday: 'Sex',
      DateTime.saturday: 'Sáb',
      DateTime.sunday: 'Dom',
    };
    return map[d.weekday] ?? '';
  }
  String labelForFunc(String f) {
    final lc = f.toLowerCase();
    if (lc == 'ministrante') return 'Ministrante';
    if (lc == 'tecnico de som' || lc == 'técnico de som') return 'Técnico de som';
    return f.toUpperCase();
  }
  double fontFor(String text, double width, {int maxLines = 1}) {
    final lines = text.split('\n');
    double best = 12.0;
    for (final line in lines) {
      final len = line.trim().isEmpty ? 1 : line.trim().length;
      final fs = width / (len * 0.6);
      best = math.min(best, fs);
    }
    if (best < 8.0) return 8.0;
    if (best > 12.0) return 12.0;
    return best;
  }

  pw.Widget chip(String uid, String name) {
    final col = colorForUser[uid] ?? PdfColors.grey;
    return pw.Container(
      margin: const pw.EdgeInsets.all(2),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(color: col, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        child: pw.Text(name, style: pw.TextStyle(color: PdfColors.white, fontSize: 9), maxLines: 1, overflow: pw.TextOverflow.clip),
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(pw.Page(build: (context) {
    final pageW = context.page.pageFormat.width;
    final dataInnerW = 60.0 - 8.0;
    final diaInnerW = 50.0 - 8.0;
    final remainingW = pageW - 60.0 - 50.0;
    final funcWidth = remainingW / (funcs.isEmpty ? 1 : funcs.length);
    final funcInnerW = funcWidth - 8.0;
    double headerFontSize = 12.0;
    headerFontSize = math.min(headerFontSize, fontFor('DATA', dataInnerW));
    headerFontSize = math.min(headerFontSize, fontFor('DIA', diaInnerW));
    for (final f in funcs) {
      headerFontSize = math.min(headerFontSize, fontFor(labelForFunc(f), funcInnerW, maxLines: 1));
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(eventName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (eventDate != null) pw.Text(DateFormat('yyyy').format(eventDate), style: pw.TextStyle(fontSize: 12)),
      ]),
      if (eventDate != null) pw.SizedBox(height: 6),
      if (eventDate != null)
        pw.Text('${dowAbbrevPt(eventDate)}, ${DateFormat('dd/MM').format(eventDate)} - ${DateFormat('HH:mm').format(eventDate)}'),
      pw.SizedBox(height: 12),
      pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FixedColumnWidth(60),
          1: const pw.FixedColumnWidth(50),
          for (int i = 0; i < funcs.length; i++) 2 + i: pw.FixedColumnWidth(funcWidth),
        },
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: PdfColors.black), children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text('DATA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize), maxLines: 1, textAlign: pw.TextAlign.center))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text('DIA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize), maxLines: 1, textAlign: pw.TextAlign.center))),
            for (final f in funcs)
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text(labelForFunc(f), style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize), maxLines: 1, textAlign: pw.TextAlign.center))),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.FittedBox(fit: pw.BoxFit.scaleDown, child: pw.Text(eventDate != null ? DateFormat('dd/MM').format(eventDate) : '', maxLines: 1, textAlign: pw.TextAlign.center)))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.FittedBox(fit: pw.BoxFit.scaleDown, child: pw.Text(eventDate != null ? dowAbbrevPt(eventDate) : '', maxLines: 1, textAlign: pw.TextAlign.center)))),
            for (final f in funcs)
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Wrap(spacing: 2, runSpacing: 2, children: [
                for (final u in groupedUsers[f] ?? const <Map<String, String>>[])
                  chip(u['id'] ?? '', u['name'] ?? ''),
              ])),
          ]),
        ],
      ),
    ]);
  }));
  final bytes = await doc.save();
  return Uint8List.fromList(bytes);
}
