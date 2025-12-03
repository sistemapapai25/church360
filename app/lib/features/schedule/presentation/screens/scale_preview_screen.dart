import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  bool _exclusiveInstrument = true;
  bool _exclusiveVoiceRole = true;
  final Map<String, List<String>> _missingByEvent = {};
  final Map<String, List<String>> _allowedByFunction = {}; // func -> userIds
  final Set<String> _exclusiveWithinCats = {};
  final Set<String> _exclusiveAloneCats = {};
  final Map<String, List<String>> _synonyms = const {
    'BACK': ['back', 'back vocal', 'back-vocal', 'backing', 'bv'],
    'GUITARRA': ['guitarra', 'guitar', 'gtr'],
    'VIOLAO': ['violao', 'violão'],
    'BAIXO': ['baixo', 'bass'],
    'BATERIA': ['bateria', 'drums', 'baterista'],
    'TECLADO': ['teclado', 'keyboard', 'keys', 'piano'],
    'SAX': ['sax', 'saxofone', 'saxophone'],
    'TECNICO DE SOM': ['tecnico de som', 'técnico de som', 'audio', 'som', 'mesa'],
    'MINISTRANTE': [
      'ministrante',
      'worship leader',
      'leader',
      'ministro',
      'ministra',
      'líder',
      'lider',
      'líder de louvor',
      'lider de louvor',
      'wl',
      'dirigente'
    ],
  };

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
    final Set<String> funcs = {};
    final Map<String, int> required = {};
    final Map<String, String> cat = {};
    bool exclInst = _exclusiveInstrument;
    bool exclVoice = _exclusiveVoiceRole;
    final Map<String, List<String>> allowed = {};
    for (final mid in ids) {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(mid);
      for (final c in contexts) {
        final meta = c.metadata ?? {};
        final catMap = Map<String, dynamic>.from(meta['function_category_by_function'] ?? {});
        funcs.addAll(catMap.keys.map((e) => e.toString()));
        for (final f in List<dynamic>.from(meta['functions'] ?? const [])) {
          funcs.add(f.toString());
        }
        catMap.forEach((k, v) => cat[k] = v.toString());
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
            if (n > 0) required[k.toString()] = n;
          });
        }
        if (required.isEmpty) {
          final req = meta['function_requirements'];
          if (req is Map) {
            req.forEach((k, v) {
              final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
              if (n > 0) required[k.toString()] = n;
            });
          }
        }
        final assigned = Map<String, dynamic>.from(meta['assigned_functions'] ?? {});
        assigned.forEach((userId, funcsList) {
          for (final f in List<dynamic>.from(funcsList ?? const [])) {
            final name = f.toString();
            allowed.putIfAbsent(name, () => []).add(userId.toString());
          }
        });
      }
    }
    // Fallback: se não há funções configuradas nos contextos, derive de cargos dos membros
    if (funcs.isEmpty) {
      final Set<String> fromCargo = {};
      for (final m in allMembers) {
        final String? cargo = (m.cargoName as String?);
        if (cargo != null && cargo.trim().isNotEmpty) {
          fromCargo.add(cargo.trim());
        }
      }
      if (fromCargo.isNotEmpty) {
        funcs.addAll(fromCargo);
      }
      // Se ainda não houver, usar conjunto padrão de funções do louvor
      if (funcs.isEmpty) {
        funcs.addAll(['BACK', 'BAIXO', 'BATERIA', 'GUITARRA', 'TECLADO', 'SAX', 'MINISTRANTE']);
      }
    }
    _functions
      ..clear()
      ..addAll(funcs.toList()..sort());
    _requiredByFunction
      ..clear()
      ..addAll({ for (final f in _functions) f : (required[f] ?? 1) });
    _funcCategory
      ..clear()
      ..addAll(cat);
    _exclusiveInstrument = exclInst;
    _exclusiveVoiceRole = exclVoice;
    // Completar permitidos por função com fallback por cargo
    _allowedByFunction
      ..clear()
      ..addAll({ for (final entry in allowed.entries) entry.key : entry.value.toSet().toList() });
    String norm(String? s) {
      var x = (s ?? '').trim().toLowerCase();
      x = x
          .replaceAll(RegExp(r'[áàãâä]'), 'a')
          .replaceAll(RegExp(r'[éêèë]'), 'e')
          .replaceAll(RegExp(r'[íîìï]'), 'i')
          .replaceAll(RegExp(r'[óôõòö]'), 'o')
          .replaceAll(RegExp(r'[úûùü]'), 'u')
          .replaceAll(RegExp(r'[ç]'), 'c')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      return x;
    }
    for (final f in _functions) {
      if ((_allowedByFunction[f] ?? const []).isEmpty) {
        final key = norm(f);
        final aliases = <String>{ key, ...(_synonyms[f.toUpperCase()] ?? const []).map(norm) };
        final byCargo = allMembers
            .where((m) {
              final cn = norm(m.cargoName);
              if (cn.isEmpty) return false;
              // casa se cargo contém algum alias ou alias contém cargo
              return aliases.any((a) => cn.contains(a) || a.contains(cn));
            })
            .map<String>((m) => m.memberId as String)
            .toList();
        if (byCargo.isNotEmpty) {
          _allowedByFunction[f] = byCargo;
        }
      }
    }
    for (final e in widget.events) {
      // Prefill com escala salva, se houver
      final existing = await repo.getEventSchedules(e.id);
      if (existing.isNotEmpty) {
        final List<Map<String, String>> assigns = [];
        for (final s in existing.where((it) => (it.memberId).isNotEmpty)) {
          assigns.add({
            'event_id': s.eventId,
            'ministry_id': s.ministryId,
            'user_id': s.memberId,
            'notes': s.notes ?? '',
          });
          if (s.notes != null && s.notes!.isNotEmpty && !_functions.contains(s.notes)) {
            _functions.add(s.notes!);
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
          }
          assigns.add(entry);
          i++;
        }
      }
      _assignmentsByEvent[e.id] = assigns;
    }
    // União de funções vindas de escala salva e propostas
    final Set<String> unionFuncs = {..._functions};
    for (final entries in _assignmentsByEvent.values) {
      for (final a in entries) {
        final f = a['notes'] ?? '';
        if (f.isNotEmpty) unionFuncs.add(f);
      }
    }
    _functions
      ..clear()
      ..addAll(unionFuncs.toList()..sort());
    _requiredByFunction.addAll({ for (final f in _functions) f : (_requiredByFunction[f] ?? 1) });

    _recomputeMissing();
    _autoCompleteMissing();
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

  void _autoCompleteMissing() {
    for (final e in widget.events) {
      final assigns = _assignmentsByEvent[e.id] ?? [];
      for (final f in _functions) {
        final need = _requiredByFunction[f] ?? 1;
        final current = assigns.where((a) => (a['notes'] ?? '') == f).toList();
        int have = current.where((a) => (a['user_id'] ?? '').isNotEmpty).length;
        final allowed = _allowedForEventFunction(e, f);
        int idx = 0;
        int pickIndex = 0;
        while (have < need && idx < current.length) {
          if ((current[idx]['user_id'] ?? '').isEmpty && allowed.isNotEmpty) {
            final uid = allowed[pickIndex % allowed.length];
            current[idx]['user_id'] = uid;
            have++;
            pickIndex++;
          }
          idx++;
        }
        final indices = <int>[];
        for (int i = 0; i < assigns.length; i++) {
          if ((assigns[i]['notes'] ?? '') == f) indices.add(i);
        }
        for (int j = 0; j < current.length && j < indices.length; j++) {
          assigns[indices[j]] = current[j];
        }
      }
      _assignmentsByEvent[e.id] = assigns;
    }
    _recomputeMissing();
    setState(() {});
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(ministriesRepositoryProvider);
      for (final e in widget.events) {
        final existing = await repo.getEventSchedules(e.id);
        for (final s in existing) {
          await repo.removeSchedule(s.id);
        }
      }
      for (final entry in _assignmentsByEvent.entries) {
        for (final a in entry.value.where((it) => ((it['user_id'] ?? '').isNotEmpty))) {
          await repo.addSchedule({
            'event_id': a['event_id'],
            'ministry_id': a['ministry_id'],
            'member_id': a['user_id'],
            if ((a['notes'] ?? '').isNotEmpty) 'notes': a['notes'],
          });
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
                      'Existem funções com pessoas faltando. Use Auto-completar ou ajuste manual.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _autoCompleteMissing,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Auto-completar'),
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

  List<String> _allowedForEventFunction(Event e, String func) {
    final raw = (_allowedByFunction[func] ?? const <String>[]);
    final base = raw.isNotEmpty ? raw : _memberNames.keys.toList();
    String canon(String name) {
      final s = (name).trim().toLowerCase();
      if (s.startsWith('inst')) return 'instrument';
      if (s == 'voice_role' || s.startsWith('voz') || s.startsWith('back')) return 'voice_role';
      if (s == 'other' || s.startsWith('outr')) return 'other';
      return name;
    }
    final cat = canon(_funcCategory[func] ?? 'other');
    String catOf(String? f) => canon(_funcCategory[f ?? ''] ?? 'other');
    Set<String> catsFor(String uid) {
      final assigns = _assignmentsByEvent[e.id] ?? const [];
      final cats = <String>{};
      for (final a in assigns) {
        if ((a['user_id'] ?? '') == uid) cats.add(catOf(a['notes']));
      }
      return cats;
    }
    return base.where((uid) {
      final cats = catsFor(uid);
      if (_exclusiveWithinCats.contains(cat) && cats.contains(cat)) return false;
      if (_exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) return false;
      if (cats.any((c) => _exclusiveAloneCats.contains(c) && c != cat)) return false;
      return true;
    }).where((uid) => _memberNames.containsKey(uid)).toSet().toList();
  }

  Widget _buildGrid(BuildContext context) {
    final header = [
      const DataColumn(label: Text('DATA')),
      const DataColumn(label: Text('DIA')),
      ..._functions.map((f) => DataColumn(label: Text(f.toUpperCase()))),
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
            var allowedLocal = _allowedForEventFunction(e, f).toSet().toList();
            if (allowedLocal.isEmpty) {
              allowedLocal = _memberNames.keys.toList();
            }
            final selectedUid = (current?['user_id'] ?? '').toString();
            if (selectedUid.isNotEmpty && !allowedLocal.contains(selectedUid)) {
              allowedLocal = [selectedUid, ...allowedLocal];
            }
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('${e.id}-$f-$j-${allowedLocal.length}'),
                  initialValue: (() {
                    final uid = current?['user_id'];
                    return (uid != null && allowedLocal.contains(uid)) ? uid : null;
                  })(),
                  items: allowedLocal
                      .toSet()
                      .map((uid) => DropdownMenuItem(value: uid, child: Text(_memberNames[uid]!)))
                      .toList(),
                  isExpanded: true,
                  onChanged: (uid) {
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
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
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
