import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/file_download.dart';
import 'dart:math' as math;

import '../../domain/auto_scheduler_service.dart';
import '../../../events/domain/models/event.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';

class ScalePreviewScreen extends ConsumerStatefulWidget {
  final String ministryId;
  final List<Event> events;
  final List<String> jointMinistryIds;
  final bool byFunction;

  const ScalePreviewScreen({
    super.key,
    required this.ministryId,
    required this.events,
    required this.jointMinistryIds,
    required this.byFunction,
  });

  @override
  ConsumerState<ScalePreviewScreen> createState() => _ScalePreviewScreenState();
}

class _ScalePreviewScreenState extends ConsumerState<ScalePreviewScreen> {
  bool _isSaving = false;
  final Map<String, List<Map<String, String>>> _assignmentsByEvent = {};
  final Map<String, String> _memberNames = {}; // userId -> name
  final List<String> _functions = [];
  final Map<String, int> _requiredByFunction = {};
  final Map<String, String> _funcCategory = {};
  final Map<String, String> _funcDisplay = {};
  bool _exclusiveInstrument = false;
  bool _exclusiveVoiceRole = false;
  final Map<String, List<String>> _missingByEvent = {};
  
  final Map<String, List<String>> _allowedByFunction = {}; // func -> userIds from assigned_functions
  final Map<String, List<String>> _linkedByFunction = {}; // func -> userIds from member_function
  final Map<String, List<String>> _leadersByFunctionCandidates = {}; // func -> userIds from leaders_by_function
  final Set<String> _exclusiveWithinCats = {};
  final Set<String> _exclusiveAloneCats = {};
  

  @override
  void initState() {
    super.initState();
    _buildProposals();
  }

  Future<void> _buildProposals() async {
    final service = AutoSchedulerService();
    final ids = widget.jointMinistryIds.isEmpty ? [widget.ministryId] : widget.jointMinistryIds;
    // Mapear nomes dos membros elegíveis (todos dos ministérios selecionados)
    final repo = ref.read(ministriesRepositoryProvider);
    final List<dynamic> allMembers = [];
    for (final mid in ids) {
      final members = await repo.getMinistryMembers(mid);
      for (final m in members) {
        _memberNames[m.memberId] = m.memberName;
      }
      allMembers.addAll(members);
    }
    // Coletar funções a partir dos contextos do cargo no ministério (união)
    String norm(String s) {
      final t = s.trim().toLowerCase();
      const repl = {
        'á':'a','à':'a','â':'a','ã':'a','ä':'a',
        'é':'e','ê':'e','ë':'e',
        'í':'i','ï':'i',
        'ó':'o','ô':'o','õ':'o','ö':'o',
        'ú':'u','ü':'u',
        'ç':'c'
      };
      final buf = StringBuffer();
      for (final ch in t.runes) {
        final c = String.fromCharCode(ch);
        buf.write(repl[c] ?? c);
      }
      return buf.toString();
    }
    final Set<String> funcs = {};
    final Map<String, int> required = {};
    final Map<String, String> cat = {};
    bool exclInst = _exclusiveInstrument;
    bool exclVoice = _exclusiveVoiceRole;
    final Map<String, List<String>> allowed = {};
    for (final mid in ids) {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(mid);
      debugPrint('ScalePreview: contexts for $mid: ${contexts.length}');
      for (final c in contexts) {
        final meta = c.metadata ?? {};
        final catMap = Map<String, dynamic>.from(meta['function_category_by_function'] ?? {});
        for (final k in catMap.keys.map((e) => e.toString())) {
          final canon = norm(k);
          funcs.add(canon);
          _funcDisplay.putIfAbsent(canon, () => k);
          cat[canon] = catMap[k].toString();
        }
        for (final f in List<dynamic>.from(meta['functions'] ?? const [])) {
          final name = f.toString();
          final canon = norm(name);
          funcs.add(canon);
          _funcDisplay.putIfAbsent(canon, () => name);
        }
        final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
        exclInst = (restrictions['instrument']?['exclusive'] as bool?) ?? exclInst;
        exclVoice = (restrictions['voice_role']?['exclusive'] as bool?) ?? exclVoice;
        restrictions.forEach((k, v) {
          if (v is Map) {
            if ((v['exclusive'] as bool?) == true) _exclusiveWithinCats.add(k.toString());
            if ((v['alone'] as bool?) == true) _exclusiveAloneCats.add(k.toString());
          }
        });
        final eventReq = meta['event_function_requirements'];
        if (eventReq is Map) {
          final Map<String, dynamic> reqForType = Map<String, dynamic>.from(eventReq[(widget.events.isNotEmpty ? widget.events.first.eventType : null)] ?? {});
          reqForType.forEach((k, v) {
            final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
            if (n > 0) required[norm(k.toString())] = n;
          });
        }
        if (required.isEmpty) {
          final req = meta['function_requirements'];
          if (req is Map) {
            req.forEach((k, v) {
              final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
              if (n > 0) required[norm(k.toString())] = n;
            });
          }
        }
      final assigned = Map<String, dynamic>.from(meta['assigned_functions'] ?? {});
      assigned.forEach((userId, funcsList) {
        for (final f in List<dynamic>.from(funcsList ?? const [])) {
          final name = f.toString();
          final canon = norm(name);
          _funcDisplay.putIfAbsent(canon, () => name);
          allowed.putIfAbsent(canon, () => []).add(userId.toString());
          _allowedByFunction.putIfAbsent(canon, () => []);
          if (!_allowedByFunction[canon]!.contains(userId.toString())) {
            _allowedByFunction[canon]!.add(userId.toString());
          }
        }
      });

      final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
      final lf = Map<String, dynamic>.from(rules['leaders_by_function'] ?? {});
      lf.forEach((funcName, cfg) {
        final canon = norm(funcName.toString());
        final leaderId = (cfg is Map) ? cfg['leader']?.toString() : null;
        final subs = (cfg is Map) ? List<dynamic>.from(cfg['subs'] ?? const []) : const [];
        debugPrint('ScalePreview: leaders_by_function func=$canon leader=${leaderId ?? ''} subs=${subs.length}');
        if (leaderId != null && leaderId.isNotEmpty) {
          allowed.putIfAbsent(canon, () => []);
          if (!allowed[canon]!.contains(leaderId)) allowed[canon]!.add(leaderId);
          _funcDisplay.putIfAbsent(canon, () => funcName.toString());
          _leadersByFunctionCandidates.putIfAbsent(canon, () => []);
          if (!_leadersByFunctionCandidates[canon]!.contains(leaderId)) {
            _leadersByFunctionCandidates[canon]!.add(leaderId);
          }
        }
        for (final s in subs.map((e)=>e.toString()).where((e)=>e.isNotEmpty)) {
          allowed.putIfAbsent(canon, () => []);
          if (!allowed[canon]!.contains(s)) allowed[canon]!.add(s);
          _funcDisplay.putIfAbsent(canon, () => funcName.toString());
          _leadersByFunctionCandidates.putIfAbsent(canon, () => []);
          if (!_leadersByFunctionCandidates[canon]!.contains(s)) {
            _leadersByFunctionCandidates[canon]!.add(s);
          }
        }
      });
      }
      // Completar funções e permitidos com vínculos do banco (member_function)
      try {
        final mfMap = await repo.getMemberFunctionsByMinistry(mid);
        for (final entry in mfMap.entries) {
          final uid = entry.key;
          for (final f in entry.value) {
            final canon = norm(f);
            funcs.add(canon);
            _funcDisplay.putIfAbsent(canon, () => f);
            allowed.putIfAbsent(canon, () => []);
            if (!allowed[canon]!.contains(uid)) allowed[canon]!.add(uid);
            _linkedByFunction.putIfAbsent(canon, () => []);
            if (!_linkedByFunction[canon]!.contains(uid)) {
              _linkedByFunction[canon]!.add(uid);
            }
          }
        }
      } catch (_) {}
    }
    final Set<String> candidateIds = {
      for (final entry in _leadersByFunctionCandidates.entries) ...entry.value,
    };
    debugPrint('ScalePreview: leaders candidates keys=${_leadersByFunctionCandidates.keys.toList()}');
    debugPrint('ScalePreview: leaders candidateIds count=${candidateIds.length}');
    final missingIds = candidateIds.where((uid) => !_memberNames.containsKey(uid)).toSet().toList();
    if (missingIds.isNotEmpty) {
      try {
        final names = await repo.getUserNamesByIds(missingIds);
        _memberNames.addAll(names);
      } catch (_) {}
    }
    // Ordenação por categorias
    List<String> catOrder = ['other'];
    try {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(widget.ministryId);
      final orderRaw = contexts
          .map((c) => List<dynamic>.from((c.metadata ?? {})['category_order'] ?? const []))
          .firstWhere((l) => l.isNotEmpty, orElse: () => const []);
      final seen = <String>{};
      final parsed = <String>[];
      for (final o in orderRaw.map((e)=>e.toString())) {
        final s = o.trim().toLowerCase();
        final k = (s.startsWith('inst')) ? 'instrument' : (s == 'voice_role' || s.startsWith('voz') || s.startsWith('back')) ? 'voice_role' : (s == 'other' || s.startsWith('outr')) ? 'other' : o;
        if (seen.add(k)) parsed.add(k);
      }
      if (parsed.isNotEmpty) catOrder = parsed;
    } catch (_) {}
    int rank(String f){
      final c = cat[f] ?? 'other';
      final idx = catOrder.indexOf(c);
      return idx >= 0 ? idx : catOrder.length;
    }
    final orderedFuncs = funcs.toList()
      ..sort((a,b){
        final ra = rank(a);
        final rb = rank(b);
        if (ra != rb) return ra.compareTo(rb);
        return a.compareTo(b);
      });
    _functions
      ..clear()
      ..addAll(orderedFuncs);
    debugPrint('ScalePreview: functions loaded count=${_functions.length} values=$_functions');
    
    _requiredByFunction
      ..clear()
      ..addAll({ for (final f in _functions) f : (required[f] ?? 1) });
    _funcCategory
      ..clear()
      ..addAll(cat);
    _exclusiveInstrument = exclInst;
    _exclusiveVoiceRole = exclVoice;
    // Permitidos estritamente por atribuições e vínculos
    _allowedByFunction
      ..clear()
      ..addAll({ for (final entry in allowed.entries) entry.key : entry.value.toSet().toList() });
    
    for (final e in widget.events) {
      // Prefill com escala salva, se houver
      final existing = await repo.getEventSchedules(e.id);
      if (existing.isNotEmpty) {
        final List<Map<String, String>> assigns = [];
        for (final s in existing.where((it) => (it.memberId).isNotEmpty)) {
          final canon = norm(s.notes ?? '');
          if (canon.isNotEmpty) _funcDisplay.putIfAbsent(canon, () => s.notes!);
          assigns.add({
            'event_id': s.eventId,
            'ministry_id': s.ministryId,
            'user_id': s.memberId,
            'notes': canon.isNotEmpty ? canon : '',
          });
          if (canon.isNotEmpty && !_functions.contains(canon)) {
            _functions.add(canon);
          }
        }
        _assignmentsByEvent[e.id] = assigns;
        continue;
      }
      final props = await service.generateProposalForEvent(
        ref: ref,
        event: e,
        ministryIds: ids,
        byFunction: widget.byFunction,
      );
      final List<Map<String, String>> assigns = [];
      final Map<String, List<Map<String, String>>> byFunc = {};
      for (final p in props) {
        final key = p['notes'] ?? 'other';
        byFunc.putIfAbsent(key, () => []).add(p);
      }
      for (final f in _functions) {
        final need = _requiredByFunction[f] ?? 1;
        final candidates = List<Map<String, String>>.from(byFunc[f] ?? const []);
        final allowedIds = List<String>.from(_leadersByFunctionCandidates[f] ?? const <String>[]);
        int i = 0;
        while (i < need) {
          Map<String, String> entry;
          if (i < candidates.length) {
            entry = candidates[i];
          } else {
            entry = {
              'event_id': e.id,
              'ministry_id': widget.ministryId,
              'user_id': '',
              'notes': f,
            };
            if (allowedIds.isNotEmpty) {
              final pick = allowedIds[i % allowedIds.length];
              entry['user_id'] = pick;
            }
          }
          assigns.add(entry);
          i++;
        }
      }
      _assignmentsByEvent[e.id] = assigns;
    }
    // Manter funções requeridas na ordem de categoria sem incluir extras
    _requiredByFunction.addAll({ for (final f in _functions) f : (_requiredByFunction[f] ?? 1) });

    _recomputeMissing();
    if (mounted) setState(() {});
  }

  void _recomputeMissing() {
    _missingByEvent.clear();
    for (final e in widget.events) {
      final assigns = _assignmentsByEvent[e.id] ?? const [];
      final Map<String, int> countByFunc = { for (final f in _functions) f : 0 };
      for (final a in assigns) {
        final f = a['notes'] ?? '';
        final uid = a['user_id'] ?? '';
        if (f.isNotEmpty && uid.isNotEmpty) {
          countByFunc[f] = (countByFunc[f] ?? 0) + 1;
        }
      }
      final missingFuncs = <String>[];
      for (final f in _functions) {
        final need = _requiredByFunction[f] ?? 1;
        final have = countByFunc[f] ?? 0;
        if (have < need) missingFuncs.add(f);
      }
      _missingByEvent[e.id] = missingFuncs;
    }
  }

  

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(ministriesRepositoryProvider);
      final catalog = await repo.getFunctionsCatalog();
      String norm(String s) {
        final t = s.trim().toLowerCase();
        const repl = {
          'á':'a','à':'a','â':'a','ã':'a','ä':'a',
          'é':'e','ê':'e','ë':'e',
          'í':'i','ï':'i',
          'ó':'o','ô':'o','õ':'o','ö':'o',
          'ú':'u','ü':'u',
          'ç':'c'
        };
        final buf = StringBuffer();
        for (final ch in t.runes) {
          final c = String.fromCharCode(ch);
          buf.write(repl[c] ?? c);
        }
        return buf.toString();
      }
      final Map<String, String> nameToId = {
        for (final e in catalog) (e['name'] ?? '').toString().trim(): (e['id'] ?? '').toString().trim()
      };
      final Map<String, String> normNameToId = {
        for (final e in catalog) norm((e['name'] ?? '').toString()): (e['id'] ?? '').toString().trim()
      };
      String? fidForFunc(String funcName) {
        final key = funcName.trim();
        return nameToId[key] ?? normNameToId[norm(key)];
      }
      for (final e in widget.events) {
        final existing = await repo.getEventSchedules(e.id);
        for (final s in existing) {
          await repo.removeSchedule(s.id);
        }
      }
      final Set<String> seen = {};
      for (final entry in _assignmentsByEvent.entries) {
        for (final a in entry.value.where((it) => ((it['user_id'] ?? '').isNotEmpty))) {
          final notes = (a['notes'] ?? '').toString();
          final fid = notes.isNotEmpty ? fidForFunc(notes) : null;
          final k = '${a['event_id']}|${a['ministry_id']}|${a['user_id']}|${fid ?? ''}';
          if (seen.add(k)) {
            final data = {
              'event_id': a['event_id'],
              'ministry_id': a['ministry_id'],
              'user_id': a['user_id'],
              if (fid != null && fid.isNotEmpty) 'function_id': fid,
              if (notes.isNotEmpty) 'notes': notes,
            };
            await repo.addSchedule(data);
          }
        }
      }
      for (final e in widget.events) {
        ref.invalidate(eventSchedulesProvider(e.id));
      }
      ref.invalidate(ministrySchedulesProvider(widget.ministryId));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-visualização da Escala'),
        actions: [
          OutlinedButton.icon(
            onPressed: _exportPeriodPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Exportar PDF (período)'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveAll,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Salvar Escala'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_missingByEvent.values.any((list) => list.isNotEmpty))
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Existem funções com pessoas faltando. Ajuste manual.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              minScale: 1,
              maxScale: 1,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildGrid(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPeriodPdf() async {
    if (widget.events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem eventos no período')));
      return;
    }
    final doc = pw.Document();
    // Coletar todos os usuários do período para cores consistentes
    final Set<String> periodUserIds = {
      for (final e in widget.events)
        ...[for (final a in (_assignmentsByEvent[e.id] ?? const [])) if ((a['user_id'] ?? '').isNotEmpty) a['user_id']!]
    };
    // Paleta de cores e mapeamento
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
    for (final uid in periodUserIds) {
      int i = idxFor(uid);
      int loops = 0;
      while (used.contains(i) && loops < palette.length) { i = (i + 1) % palette.length; loops++; }
      used.add(i);
      colorForUser[uid] = palette[i];
    }

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

    String labelForFunc(String canon) {
      final disp = _funcDisplay[canon] ?? canon;
      final lc = disp.toLowerCase();
      if (lc == 'ministrante') return 'Ministrante';
      if (lc == 'tecnico de som' || lc == 'técnico de som') return 'Técnico de som';
      return disp.toUpperCase();
    }

    // Consolidar em uma única página com uma tabela completa do período
    final funcs = _functions.toList();
    funcs.sort();

    pw.Widget chip(String uid, String name) {
      final col = colorForUser[uid] ?? PdfColors.grey;
      return pw.Container(
        margin: const pw.EdgeInsets.all(2),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(color: col, borderRadius: pw.BorderRadius.circular(3)),
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.Text(
            name,
            style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          final dataColW = 60.0;
          final diaColW = 50.0;
          final dataInnerW = dataColW - 8.0;
          final diaInnerW = diaColW - 8.0;

          double headerFontSize = 10.0;
          double fontFor(String text, double width, {int maxLines = 1}) {
            final lines = text.split('\n');
            double best = 12.0;
            for (final line in lines) {
              final len = line.trim().isEmpty ? 1 : line.trim().length;
              final fs = width / (len * 0.6);
              if (fs < best) best = fs;
            }
            if (best < 8.0) return 8.0;
            if (best > 12.0) return 12.0;
            return best;
          }

          // Fonte base calculada pelos campos fixos
          headerFontSize = fontFor('DATA', dataInnerW);
          headerFontSize = math.min(headerFontSize, fontFor('DIA', diaInnerW));
          // Ajuste conservador para funções (largura estimada)
          const funcInnerW = 100.0;
          for (final f in funcs) {
            headerFontSize = math.min(headerFontSize, fontFor(labelForFunc(f), funcInnerW, maxLines: 1));
          }

          final rows = <pw.TableRow>[];
          rows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.black),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text('DATA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize)))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text('DIA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize)))),
                for (final f in funcs)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        child: pw.Text(
                          labelForFunc(f),
                          style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize),
                          maxLines: 1,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          for (final e in widget.events) {
            final assigns = List<Map<String, String>>.from(_assignmentsByEvent[e.id] ?? const []);
            final byFunc = {for (final f in funcs) f: <Map<String, String>>[]};
            for (final a in assigns) {
              final uid = a['user_id'] ?? '';
              final f = a['notes'] ?? '';
              if (uid.isEmpty || f.isEmpty || !byFunc.containsKey(f)) continue;
              byFunc[f]!.add({'id': uid, 'name': _memberNames[uid] ?? uid});
            }
            rows.add(
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text(DateFormat('dd/MM').format(e.startDate), maxLines: 1, textAlign: pw.TextAlign.center))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.center, child: pw.Text(dowAbbrevPt(e.startDate), maxLines: 1, textAlign: pw.TextAlign.center))),
                  for (final f in funcs)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          for (final u in byFunc[f] ?? const <Map<String, String>>[])
                            chip(u['id'] ?? '', u['name'] ?? ''),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }

          return [
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FixedColumnWidth(dataColW),
                1: pw.FixedColumnWidth(diaColW),
                for (int i = 0; i < funcs.length; i++) 2 + i: const pw.FlexColumnWidth(1),
              },
              children: rows,
            ),
          ];
        },
      ),
    );
    try {
      final bytes = await doc.save();
      if (kIsWeb) {
        downloadFile('escala_periodo.pdf', bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF baixado')));
        }
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'escala_periodo.pdf').catchError((_) async {
          await Printing.layoutPdf(onLayout: (format) async => bytes);
          return true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF do período gerado')));
        }
      }
    } catch (err) {
      try {
        final bytes = await doc.save();
        await Printing.layoutPdf(onLayout: (format) async => bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visualização/Impressão do PDF aberta')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
        }
      }
    }
  }

  List<String> _allowedForEventFunction(Event e, String func) {
    final a = (_leadersByFunctionCandidates[func] ?? const <String>[]);
    final b = (_allowedByFunction[func] ?? const <String>[]);
    final c = (_linkedByFunction[func] ?? const <String>[]);
    final set = <String>{...a, ...b, ...c};
    return set.toList();
  }

  Widget _buildGrid(BuildContext context) {
    final header = [
      const DataColumn(label: Text('DATA')),
      const DataColumn(label: Text('DIA')),
      ..._functions.map((f) => DataColumn(label: Text((_funcDisplay[f] ?? f).toUpperCase()))),
    ];
    final rows = widget.events.map((e) {
      final assigns = _assignmentsByEvent[e.id] ?? const [];
      List<DataCell> cells = [
        DataCell(Text(DateFormat('dd/MM/yy').format(e.startDate))),
        DataCell(Text(DateFormat('EEE', 'pt_BR').format(e.startDate).toUpperCase())),
        ..._functions.map((f) {
          final need = _requiredByFunction[f] ?? 1;
          final indices = <int>[];
          for (int i = 0; i < assigns.length; i++) {
            if ((assigns[i]['notes'] ?? '') == f) indices.add(i);
          }
          final widgets = <Widget>[];
          for (int j = 0; j < need; j++) {
            final idx = j < indices.length ? indices[j] : -1;
            final current = idx >= 0 ? assigns[idx] : null;
            final allowedLocal = _allowedForEventFunction(e, f).toSet().toList();
            final allowedKey = allowedLocal.isEmpty ? 'empty' : allowedLocal.join('|').hashCode.toString();
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('${e.id}-$f-$j-$allowedKey'),
                  initialValue: (() {
                    final uid = current?['user_id'];
                    return (uid != null && allowedLocal.contains(uid)) ? uid : null;
                  })(),
                  items: allowedLocal
                      .toSet()
                      .map((uid) => DropdownMenuItem(value: uid, child: Text(_memberNames[uid] ?? uid)))
                      .toList(),
                  isExpanded: true,
                  onChanged: allowedLocal.isEmpty ? null : (uid) {
                    setState(() {
                      if (idx >= 0) {
                        assigns[idx]['user_id'] = uid ?? '';
                      } else if (uid != null) {
                        assigns.add({'event_id': e.id, 'ministry_id': widget.ministryId, 'user_id': uid, 'notes': f});
                      }
                      _assignmentsByEvent[e.id] = assigns;
                      _recomputeMissing();
                    });
                  },
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    hintText: allowedLocal.isEmpty ? 'Sem candidatos' : null,
                  ),
                ),
              ),
            ));
          }
          final missing = (_missingByEvent[e.id] ?? const []).contains(f);
          return DataCell(
            Container(
              decoration: missing
                  ? BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.error),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              padding: const EdgeInsets.all(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 220, minHeight: 56),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
                ),
              ),
            ),
          );
        }),
      ];
      return DataRow(cells: cells);
    }).toList();
    return DataTable(
      columns: header,
      rows: rows,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 160,
      columnSpacing: 20,
      horizontalMargin: 12,
    );
  }
}
