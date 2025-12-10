import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../events/domain/models/event.dart';

class ScheduleRulesPreferencesScreen extends ConsumerStatefulWidget {
  final String ministryId;

  const ScheduleRulesPreferencesScreen({super.key, required this.ministryId});

  @override
  ConsumerState<ScheduleRulesPreferencesScreen> createState() => _ScheduleRulesPreferencesScreenState();
}

class _ScheduleRulesPreferencesScreenState extends ConsumerState<ScheduleRulesPreferencesScreen> {
  bool _loading = true;
  Map<String, dynamic> _rules = {};
  List<dynamic> _members = [];
  Map<String, String> _memberNames = {};
  List<String> _functions = [];
  List<String> _eventTypes = [];
  List<Event> _events = [];
  Map<String, String> _eventTypeLabels = {};
  final Map<String, String> _functionCategory = {};
  final Map<String, List<String>> _membersByFunction = {};
  List<String> _availableCategories = [];
  final Map<String, bool> _exclusiveByGroup = {'instrument': false, 'voice_role': false};
  final Map<String, bool> _enabledGroups = {'instrument': false, 'voice_role': false, 'other': false};
  final Map<String, bool> _exclusiveByCategory = {};
  final Map<String, bool> _aloneByCategory = {};
  List<String> _categoryOrder = ['other'];
  final TextEditingController _newFunctionController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newFunctionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(ministriesRepositoryProvider);
      
      _members = await repo.getMinistryMembers(widget.ministryId);
      _memberNames = {for (final m in _members) m.memberId as String: m.memberName as String};
      // Vínculos de funções dos membros (member_function)
      Map<String, List<String>> memberFuncMap = {};
      try {
        memberFuncMap = await repo.getMemberFunctionsByMinistry(widget.ministryId);
      } catch (_) {}
      // Puxar tipos de eventos do catálogo
      try {
        final eventsRepo = ref.read(eventsRepositoryProvider);
        _events = await eventsRepo.getAllEvents();
        final catalog = await eventsRepo.getEventTypesCatalog();
        final catalogCodes = catalog.map((e) => e['code']!).toList();
        final labels = {for (final e in catalog) e['code']!: e['label']!};
        _eventTypeLabels = labels;
        _eventTypes = catalogCodes;
      } catch (_) {
        _eventTypes = [];
      }
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(widget.ministryId);
      Map<String, dynamic> metaUnion = {};
      if (contexts.isNotEmpty) {
        metaUnion = Map<String, dynamic>.from(contexts.first.metadata ?? {});
        for (int i = 1; i < contexts.length; i++) {
          final m = Map<String, dynamic>.from(contexts[i].metadata ?? {});
          final currentSR = Map<String, dynamic>.from(metaUnion['schedule_rules'] ?? {});
          final incomingSR = Map<String, dynamic>.from(m['schedule_rules'] ?? {});
          if (incomingSR.isNotEmpty) {
            // Unir listas
            List<dynamic> mergeList(String key) {
              final a = List<dynamic>.from(currentSR[key] ?? const []);
              final b = List<dynamic>.from(incomingSR[key] ?? const []);
              return [...a, ...b];
            }
            // Unir mapas (incoming sobrescreve onde houver)
            Map<String, dynamic> mergeMap(String key) {
              return {
                ...Map<String, dynamic>.from(currentSR[key] ?? {}),
                ...Map<String, dynamic>.from(incomingSR[key] ?? {}),
              };
            }
            final merged = {
              ...currentSR,
              'prohibited_combinations': mergeList('prohibited_combinations'),
              'preferred_combinations': mergeList('preferred_combinations'),
              'blocks': mergeList('blocks'),
              'member_priorities': mergeMap('member_priorities'),
              'leaders_by_function': mergeMap('leaders_by_function'),
              'general_rules': mergeMap('general_rules'),
            };
            metaUnion['schedule_rules'] = merged;
          }
          final funcs = List<dynamic>.from(m['functions'] ?? const []);
          _functions.addAll(funcs.map((e) => e.toString()));
          final catMap = Map<String, dynamic>.from(m['function_category_by_function'] ?? {});
          catMap.forEach((k, v) => _functionCategory[k] = v.toString());
          // Mesclar possíveis bloqueios fora de schedule_rules
          final blocksTop = List<dynamic>.from(m['blocks'] ?? const []);
          if (blocksTop.isNotEmpty) {
            final existing = List<dynamic>.from(metaUnion['schedule_rules']?['blocks'] ?? const []);
            metaUnion['schedule_rules'] = {
              ...Map<String, dynamic>.from(metaUnion['schedule_rules'] ?? {}),
              'blocks': [...existing, ...blocksTop],
            };
          }
          final avail = List<dynamic>.from(m['available_categories'] ?? const []);
          _availableCategories.addAll(avail.map((e) => e.toString()));
          final restr = Map<String, dynamic>.from(m['category_restrictions'] ?? {});
          _exclusiveByGroup['instrument'] = (restr['instrument']?['exclusive'] as bool?) ?? _exclusiveByGroup['instrument']!;
          _exclusiveByGroup['voice_role'] = (restr['voice_role']?['exclusive'] as bool?) ?? _exclusiveByGroup['voice_role']!;
          _enabledGroups['instrument'] = (restr['instrument']?['enabled'] as bool?) ?? _enabledGroups['instrument']!;
          _enabledGroups['voice_role'] = (restr['voice_role']?['enabled'] as bool?) ?? _enabledGroups['voice_role']!;
          _enabledGroups['other'] = (restr['other']?['enabled'] as bool?) ?? _enabledGroups['other']!;
          restr.forEach((k, v) {
            if (v is Map) {
              _exclusiveByCategory[k] = (v['exclusive'] as bool?) ?? (_exclusiveByCategory[k] ?? false);
              _aloneByCategory[k] = (v['alone'] as bool?) ?? (_aloneByCategory[k] ?? false);
            }
          });
        }
        final funcs0 = List<dynamic>.from(metaUnion['functions'] ?? const []);
        _functions.addAll(funcs0.map((e) => e.toString()));
        final catMap0 = Map<String, dynamic>.from(metaUnion['function_category_by_function'] ?? {});
        catMap0.forEach((k, v) => _functionCategory[k] = v.toString());
        final avail0 = List<dynamic>.from(metaUnion['available_categories'] ?? const []);
        _availableCategories.addAll(avail0.map((e) => e.toString()));
        final restr0 = Map<String, dynamic>.from(metaUnion['category_restrictions'] ?? {});
        _exclusiveByGroup['instrument'] = (restr0['instrument']?['exclusive'] as bool?) ?? _exclusiveByGroup['instrument']!;
        _exclusiveByGroup['voice_role'] = (restr0['voice_role']?['exclusive'] as bool?) ?? _exclusiveByGroup['voice_role']!;
        _enabledGroups['instrument'] = (restr0['instrument']?['enabled'] as bool?) ?? _enabledGroups['instrument']!;
        _enabledGroups['voice_role'] = (restr0['voice_role']?['enabled'] as bool?) ?? _enabledGroups['voice_role']!;
        _enabledGroups['other'] = (restr0['other']?['enabled'] as bool?) ?? _enabledGroups['other']!;
        restr0.forEach((k, v) {
          if (v is Map) {
            _exclusiveByCategory[k] = (v['exclusive'] as bool?) ?? (_exclusiveByCategory[k] ?? false);
            _aloneByCategory[k] = (v['alone'] as bool?) ?? (_aloneByCategory[k] ?? false);
          }
        });
      }
      if (contexts.isNotEmpty) {
        // Finalizar união já acumulada nos loops acima
        _functions = _functions.toSet().toList()..sort();
        _availableCategories = _availableCategories
            .where((c) => !_isReservedCategory(c))
            .map((e) => e.toString())
            .toSet()
            .toList()
              ..sort();
        final Map<String, String> seen = {};
        for (final c in _availableCategories) {
          final k = c.trim().toLowerCase();
          if (!seen.containsKey(k)) seen[k] = c;
        }
        _availableCategories = seen.values.toList()..sort();
        final mappedCats = _functionCategory.values.map((e) => e.toString()).toSet();
        for (final v in mappedCats) {
          if (_isReservedCategory(v)) continue;
          final lv = v.trim().toLowerCase();
          if (!_availableCategories.any((x) => x.trim().toLowerCase() == lv)) {
            _availableCategories.add(v);
          }
        }
        _availableCategories.sort();
        _exclusiveByGroup['instrument'] = _exclusiveByGroup['instrument'] ?? true;
        _exclusiveByGroup['voice_role'] = _exclusiveByGroup['voice_role'] ?? true;
        _enabledGroups['instrument'] = _enabledGroups['instrument'] ?? true;
        _enabledGroups['voice_role'] = _enabledGroups['voice_role'] ?? true;
        _enabledGroups['other'] = _enabledGroups['other'] ?? true;
        _rules = Map<String, dynamic>.from(metaUnion['schedule_rules'] ?? {});
        final orderRaw = List<dynamic>.from(metaUnion['category_order'] ?? const []);
        final seenOrder = <String>{};
        final parsed = <String>[];
        for (final o in orderRaw.map((e)=>e.toString())) {
          final k = _canonReserved(o).isNotEmpty ? _canonReserved(o) : o;
          if (k.isEmpty) continue;
          if (seenOrder.add(k)) parsed.add(k);
        }
        if (parsed.isNotEmpty) {
          _categoryOrder = parsed;
        } else {
          final base = [if (_enabledGroups['voice_role'] == true) 'voice_role', if (_enabledGroups['instrument'] == true) 'instrument'];
          _categoryOrder = [...base, ..._uniqueCategories(), 'other'];
        }
      } else {
        _exclusiveByGroup['instrument'] = true;
        _exclusiveByGroup['voice_role'] = true;
        _enabledGroups['instrument'] = _enabledGroups['instrument'] ?? true;
        _enabledGroups['voice_role'] = _enabledGroups['voice_role'] ?? true;
        _enabledGroups['other'] = _enabledGroups['other'] ?? true;
        _rules = {};
      }
      _membersByFunction.clear();
      // Vínculos do banco (member_function)
      memberFuncMap.forEach((uid, funcs) {
        for (final f in funcs) {
          _membersByFunction.putIfAbsent(f, () => []);
          if (!_membersByFunction[f]!.contains(uid)) {
            _membersByFunction[f]!.add(uid);
          }
        }
      });
      // Merge: complementar com assigned_functions dos contexts para funções faltantes
      for (final ctx in contexts) {
        final meta = Map<String, dynamic>.from(ctx.metadata ?? {});
        final assigned = Map<String, dynamic>.from(meta['assigned_functions'] ?? {});
        assigned.forEach((uid, fnList) {
          final funcs = List<dynamic>.from(fnList ?? const []);
          for (final f in funcs.map((e) => e.toString())) {
            _membersByFunction.putIfAbsent(f, () => []);
            if (!_membersByFunction[f]!.contains(uid.toString())) {
              _membersByFunction[f]!.add(uid.toString());
            }
          }
        });
      }
      // Sem fallback por cargoName
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(widget.ministryId);
      final hasBackIdx = _availableCategories.indexWhere((x) => x.trim().toLowerCase() == 'back');
      if (hasBackIdx >= 0) {
        final oldKey = _availableCategories[hasBackIdx];
        _availableCategories[hasBackIdx] = 'Voz';
        final moveExclusive = _exclusiveByCategory[oldKey];
        final moveAlone = _aloneByCategory[oldKey];
        if (moveExclusive != null) {
          _exclusiveByCategory.remove(oldKey);
          _exclusiveByCategory['Voz'] = moveExclusive;
        }
        if (moveAlone != null) {
          _aloneByCategory.remove(oldKey);
          _aloneByCategory['Voz'] = moveAlone;
        }
        _functionCategory.updateAll((k, v) {
          final lv = v.trim().toLowerCase();
          return lv == 'back' ? 'Voz' : v;
        });
      }
      // Sanitização: categorias únicas e mapeamento de sinônimos
      List<String> uniqueCats = _uniqueCategories();
      final Map<String, String> uniqueCaseMap = {
        for (final c in uniqueCats) c.trim().toLowerCase(): c
      };
      final Map<String, String> mappedFunctionCategory = {};
      _functionCategory.forEach((k, v) {
        final canon = _isReservedCategory(v) ? (
          (v.trim().toLowerCase().startsWith('inst')) ? 'instrument' :
          (v.trim().toLowerCase().startsWith('voz')) ? 'voice_role' : 'other'
        ) : v;
        if (canon == 'instrument' || canon == 'voice_role' || canon == 'other') {
          mappedFunctionCategory[k] = canon;
        } else {
          final lower = canon.trim().toLowerCase();
          mappedFunctionCategory[k] = uniqueCaseMap[lower] ?? canon;
        }
        if (!['instrument', 'voice_role', 'other'].contains(canon) &&
            !uniqueCats.any((x) => x.trim().toLowerCase() == canon.trim().toLowerCase())) {
          uniqueCats.add(canon);
          uniqueCaseMap[canon.trim().toLowerCase()] = canon;
        }
      });
      String catForFunc(String f) {
        final direct = mappedFunctionCategory[f];
        if (direct != null) {
          final c = _canonReserved(direct);
          return c.isNotEmpty ? c : direct;
        }
        for (final entry in mappedFunctionCategory.entries) {
          if (entry.key.trim().toLowerCase() == f.trim().toLowerCase()) {
            final c = _canonReserved(entry.value);
            return c.isNotEmpty ? c : entry.value;
          }
        }
        return '';
      }
      // Validação: todas as funções devem ter categoria vinculada e não aceitar 'Outra'
      final List<String> missingCats = _functions.where((f) {
        final v = catForFunc(f);
        if (v.isEmpty) return true;
        if (v == 'other') return true;
        return false;
      }).toList();
      if (missingCats.isNotEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Defina a categoria para: ${missingCats.join(', ')}')),
          );
        }
        return;
      }
      // Sanear filtros: garantir que categoria selecionada seja canônica/existente
      final rulesForSave = Map<String, dynamic>.from(_rules);
      final filters = Map<String, dynamic>.from(rulesForSave['filters'] ?? {});
      final selectedCat = filters['category']?.toString();
      if (selectedCat != null && selectedCat.isNotEmpty) {
        String mapped = selectedCat;
        if (_isReservedCategory(selectedCat)) {
          mapped = _canonReserved(selectedCat);
        } else {
          mapped = uniqueCaseMap[selectedCat.trim().toLowerCase()] ?? '';
        }
        filters['category'] = mapped;
        rulesForSave['filters'] = filters;
      }
      // Deduplicar e limpar listas de regras antes de salvar
      {
        final prohibited = List<dynamic>.from(rulesForSave['prohibited_combinations'] ?? const []);
        final seen = <String>{};
        final cleaned = <Map<String, String>>[];
        for (final e in prohibited) {
          if (e is Map) {
            final a = e['a']?.toString() ?? '';
            final b = e['b']?.toString() ?? '';
            final af0 = e['a_func']?.toString() ?? '';
            final bf0 = e['b_func']?.toString() ?? '';
            final af = af0.isEmpty ? '*' : af0;
            final bf = bf0.isEmpty ? '*' : bf0;
            if (a.isEmpty || b.isEmpty) continue;
            final left = '$a|$af';
            final right = '$b|$bf';
            final key = (left.compareTo(right) <= 0) ? '$left|$right' : '$right|$left';
            if (seen.add(key)) cleaned.add({'a': a, 'a_func': af, 'b': b, 'b_func': bf});
          }
        }
        rulesForSave['prohibited_combinations'] = cleaned;
      }
      {
        final preferred = List<dynamic>.from(rulesForSave['preferred_combinations'] ?? const []);
        final seen = <String>{};
        final cleaned = <Map<String, String>>[];
        for (final e in preferred) {
          if (e is Map) {
            final a = e['a']?.toString() ?? '';
            final b = e['b']?.toString() ?? '';
            final af0 = e['a_func']?.toString() ?? '';
            final bf0 = e['b_func']?.toString() ?? '';
            final af = af0.isEmpty ? '*' : af0;
            final bf = bf0.isEmpty ? '*' : bf0;
            if (a.isEmpty || b.isEmpty) continue;
            final left = '$a|$af';
            final right = '$b|$bf';
            final key = (left.compareTo(right) <= 0) ? '$left|$right' : '$right|$left';
            if (seen.add(key)) cleaned.add({'a': a, 'a_func': af, 'b': b, 'b_func': bf});
          }
        }
        rulesForSave['preferred_combinations'] = cleaned;
      }
      {
        final blocks = List<dynamic>.from(rulesForSave['blocks'] ?? const []);
        final seen = <String>{};
        final cleaned = <Map<String, dynamic>>[];
        for (final b in blocks) {
          if (b is Map) {
            final uid = b['user_id']?.toString() ?? '';
            final start = b['start_date']?.toString() ?? '';
            final end = b['end_date']?.toString() ?? '';
            final type = b['type']?.toString() ?? '';
            final reason = b['reason']?.toString() ?? '';
            final evType = b['event_type']?.toString() ?? '';
            final evId = b['event_id']?.toString() ?? '';
            if (uid.isEmpty && start.isEmpty && end.isEmpty && reason.isEmpty && type.isEmpty) continue;
            final key = '$uid|$start|$end|$type|$reason|$evType|$evId';
            if (seen.add(key)) {
              final out = <String, dynamic>{'user_id': uid};
              if (start.isNotEmpty) out['start_date'] = start;
              if (end.isNotEmpty) out['end_date'] = end;
              if (type.isNotEmpty) out['type'] = type;
              if (reason.isNotEmpty) out['reason'] = reason;
              if (evType.isNotEmpty) out['event_type'] = evType;
              if (evId.isNotEmpty) out['event_id'] = evId;
              cleaned.add(out);
            }
          }
        }
        rulesForSave['blocks'] = cleaned;
      }
      {
        final mp = Map<String, dynamic>.from(rulesForSave['member_priorities'] ?? {});
        mp.removeWhere((memberId, rowDyn) {
          final row = Map<String, dynamic>.from(rowDyn ?? {});
          final general = int.tryParse(row['general']?.toString() ?? '') ?? 3;
          final values = row.values
              .whereType<dynamic>()
              .map((v) => int.tryParse(v?.toString() ?? '') ?? 3)
              .toList();
          final allDefault = values.isEmpty || (values.every((v) => v == 3) && general == 3);
          return allDefault;
        });
        rulesForSave['member_priorities'] = mp;
      }
      {
        final leaders = Map<String, dynamic>.from(rulesForSave['leaders_by_function'] ?? {});
        leaders.updateAll((f, rowDyn) {
          final row = Map<String, dynamic>.from(rowDyn ?? {});
          final subs = List<String>.from(row['subs'] ?? const [])
              .where((e) => (e.toString()).isNotEmpty)
              .toSet()
              .toList();
          row['subs'] = subs;
          return row;
        });
        leaders.removeWhere((f, rowDyn) {
          final row = Map<String, dynamic>.from(rowDyn ?? {});
          final leader = (row['leader']?.toString() ?? '');
          final subs = List<String>.from(row['subs'] ?? const []);
          return leader.isEmpty && subs.isEmpty;
        });
        rulesForSave['leaders_by_function'] = leaders;
      }
      {
        final gr = Map<String, dynamic>.from(rulesForSave['general_rules'] ?? {});
        gr.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
        rulesForSave['general_rules'] = gr;
      }
      if (contexts.isNotEmpty) {
        final primaryId = contexts.first.id;
        for (final c in contexts) {
          final meta = Map<String, dynamic>.from(c.metadata ?? {});
          // Aplicar funções e categorias a todos os contexts
          meta['functions'] = _functions;
          final outMap = <String, String>{};
          for (final f in _functions) {
            final v = catForFunc(f);
            if (v.isNotEmpty) outMap[f] = v;
          }
          meta['function_category_by_function'] = outMap;
          meta['available_categories'] = uniqueCats;
          meta['category_order'] = _categoryOrder.map((c){
            final k = _canonReserved(c);
            return k.isNotEmpty ? k : c;
          }).toList();
          final Map<String, dynamic> restrOut = {
            'instrument': {
              'exclusive': _exclusiveByGroup['instrument'] ?? true,
              'enabled': _enabledGroups['instrument'] ?? true,
              'alone': (_aloneByCategory['instrument'] ?? false),
            },
            'voice_role': {
              'exclusive': _exclusiveByGroup['voice_role'] ?? true,
              'enabled': _enabledGroups['voice_role'] ?? true,
              'alone': (_aloneByCategory['voice_role'] ?? false),
            },
          };
          for (final c in _uniqueCategories()) {
            restrOut[c] = {
              'exclusive': _exclusiveByCategory[c] ?? false,
              'alone': _aloneByCategory[c] ?? false,
            };
          }
          meta['category_restrictions'] = restrOut;
          if (c.id == primaryId) {
            meta['schedule_rules'] = rulesForSave;
          } else {
            meta.remove('schedule_rules');
            meta.remove('blocks');
          }
          await ref.read(roleContextsRepositoryProvider).updateContext(contextId: c.id, metadata: meta);
        }
      }
      // Vínculos de função são gerenciados na tela de Ministério; não sobrescrever aqui
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Regras salvas')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, String>> get _prohibitedCombos {
    final list = List<dynamic>.from(_rules['prohibited_combinations'] ?? const []);
    return list.map((e) => {
      'a': e is Map ? e['a']?.toString() ?? '' : '',
      'a_func': e is Map ? (e['a_func']?.toString() ?? '*') : '*',
      'b': e is Map ? e['b']?.toString() ?? '' : '',
      'b_func': e is Map ? (e['b_func']?.toString() ?? '*') : '*',
    }).where((m) => (m['a']!.isNotEmpty && m['b']!.isNotEmpty)).toList();
  }

  List<Map<String, String>> get _preferredCombos {
    final list = List<dynamic>.from(_rules['preferred_combinations'] ?? const []);
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final e in list) {
      if (e is Map) {
        final a = e['a']?.toString() ?? '';
        final b = e['b']?.toString() ?? '';
        final af = (e['a_func']?.toString() ?? '*');
        final bf = (e['b_func']?.toString() ?? '*');
        if (a.isEmpty || b.isEmpty) continue;
        final left = '$a|$af';
        final right = '$b|$bf';
        final key = (left.compareTo(right) <= 0) ? '$left|$right' : '$right|$left';
        if (seen.add(key)) {
          result.add({'a': a, 'a_func': af, 'b': b, 'b_func': bf});
        }
      }
    }
    return result;
  }

  Map<String, dynamic> get _memberPriorities => Map<String, dynamic>.from(_rules['member_priorities'] ?? {});

  Map<String, dynamic> get _leadersByFunction => Map<String, dynamic>.from(_rules['leaders_by_function'] ?? {});

  Map<String, dynamic> get _generalRules => Map<String, dynamic>.from(_rules['general_rules'] ?? {});

  List<Map<String, dynamic>> get _blocks => List<dynamic>.from(_rules['blocks'] ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  bool _canAddPreferredCombo(String a, String af, String b, String bf) {
    if (a != b) return true;
    final rawA = _functionCategory[af] ?? 'other';
    final rawB = _functionCategory[bf] ?? 'other';
    final catA = (_canonReserved(rawA).isNotEmpty) ? _canonReserved(rawA) : rawA;
    final catB = (_canonReserved(rawB).isNotEmpty) ? _canonReserved(rawB) : rawB;
    if (catA == catB) {
      final exclusive = _exclusiveByCategory[catA] ?? (_exclusiveByGroup[catA] ?? false);
      if (exclusive) return false;
    }
    final aloneA = _aloneByCategory[catA] ?? false;
    final aloneB = _aloneByCategory[catB] ?? false;
    if (aloneA && catB != catA) return false;
    if (aloneB && catA != catB) return false;
    return true;
  }

  bool _canAddProhibitedCombo(String a, String af, String b, String bf) {
    return a.isNotEmpty && af.isNotEmpty && b.isNotEmpty && bf.isNotEmpty;
  }

  void _addProhibitedCombo() async {
    String? a;
    String? b;
    String? af;
    String? bf;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Combinação Proibida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(builder: (context) { final aSelected = (a ?? '').isNotEmpty; return Column(children: [
              DropdownButtonFormField<String>(
                initialValue: a,
                isExpanded: true,
                items: _memberDropdownItems(function: af ?? '', includeSelected: a, strict: true),
                onChanged: (v) => setLocal(() => a = v),
                decoration: const InputDecoration(labelText: 'Membro A', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: af,
                isExpanded: true,
                items: _functionDropdownItemsForUser(a),
                onChanged: aSelected ? (v) => setLocal(() => af = v) : null,
                decoration: const InputDecoration(labelText: 'Função do Membro A', border: OutlineInputBorder()),
              ),
              ]);} ),
              const SizedBox(height: 12),
              Builder(builder: (context) { final bSelected = (b ?? '').isNotEmpty; return Column(children: [
              DropdownButtonFormField<String>(
                initialValue: b,
                isExpanded: true,
                items: _memberDropdownItems(function: bf ?? '', includeSelected: b, strict: true),
                onChanged: (v) => setLocal(() => b = v),
                decoration: const InputDecoration(labelText: 'Membro B', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: bf,
                isExpanded: true,
                items: _functionDropdownItemsForUser(b),
                onChanged: bSelected ? (v) => setLocal(() => bf = v) : null,
                decoration: const InputDecoration(labelText: 'Função do Membro B', border: OutlineInputBorder()),
              ),
              ]);} ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: (a != null && b != null && af != null && bf != null && _canAddProhibitedCombo(a!, af!, b!, bf!))
                  ? () {
                      final list = List<dynamic>.from(_rules['prohibited_combinations'] ?? const []);
                      list.add({'a': a, 'a_func': af, 'b': b, 'b_func': bf});
                      setState(() => _rules['prohibited_combinations'] = list);
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPreferredCombo() async {
    String? a;
    String? b;
    String? af;
    String? bf;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Combinação Preferida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: a,
                isExpanded: true,
                items: _memberDropdownItems(function: af ?? '', includeSelected: a, strict: false),
                onChanged: (v) => setLocal(() => a = v),
                decoration: const InputDecoration(labelText: 'Membro A', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: af,
                isExpanded: true,
                items: _functionDropdownItemsForUser(a),
                onChanged: (v) => setLocal(() => af = v),
                decoration: const InputDecoration(labelText: 'Função do Membro A', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: b,
                isExpanded: true,
                items: _memberDropdownItems(function: bf ?? '', includeSelected: b, strict: false),
                onChanged: (v) => setLocal(() => b = v),
                decoration: const InputDecoration(labelText: 'Membro B', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: bf,
                isExpanded: true,
                items: _functionDropdownItemsForUser(b),
                onChanged: (v) => setLocal(() => bf = v),
                decoration: const InputDecoration(labelText: 'Função do Membro B', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: (a != null && b != null && af != null && bf != null && _canAddPreferredCombo(a!, af!, b!, bf!))
                  ? () {
                  
                      final list = List<dynamic>.from(_rules['preferred_combinations'] ?? const []);
                      final selA = a!; final selB = b!;
                      final selAf = af!; final selBf = bf!;
                      final left = '$selA|$selAf';
                      final right = '$selB|$selBf';
                      final keySel = (left.compareTo(right) <= 0) ? '$left|$right' : '$right|$left';
                      final exists = list.any((e) {
                        if (e is Map) {
                          final ea = e['a']?.toString() ?? '';
                          final eb = e['b']?.toString() ?? '';
                          final eaf = e['a_func']?.toString() ?? '';
                          final ebf = e['b_func']?.toString() ?? '';
                          final leftE = '$ea|$eaf';
                          final rightE = '$eb|$ebf';
                          final key = (leftE.compareTo(rightE) <= 0) ? '$leftE|$rightE' : '$rightE|$leftE';
                          return key == keySel;
                        }
                        return false;
                      });
                      if (!exists) {
                        list.add({'a': selA, 'a_func': selAf, 'b': selB, 'b_func': selBf});
                        setState(() => _rules['preferred_combinations'] = list);
                      }
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _red() => const Color(0xFFEF4444);
  Color _green() => const Color(0xFF10B981);
  Color _purple() => const Color(0xFF7C3AED);

  String _displayDate(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final d = DateTime.parse(s);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return s;
    }
  }

  String _isoFromDisplay(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    try {
      final d = DateFormat('dd/MM/yyyy').parseStrict(t);
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      try {
        final d = DateTime.parse(t);
        return DateFormat('yyyy-MM-dd').format(d);
      } catch (_) {
        return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Regras & Preferências')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regras & Preferências'),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.rule),
            label: const Text('Aplicar estas regras na próxima geração de escala'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWide ? _buildGridLayout() : _buildAccordionLayout(),
        ),
      ),
    );
  }

  Widget _buildCard({required Color color, required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _buildGridLayout() {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final half = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(width: half, child: _buildProhibitedCard()),
          SizedBox(width: half, child: _buildPreferredCard()),
          SizedBox(width: constraints.maxWidth, child: _buildPrioritiesCard()),
          SizedBox(width: half, child: _buildLeadersCard()),
          SizedBox(
            width: half,
            child: Column(children: [
              _buildGeneralRulesCard(),
              const SizedBox(height: spacing),
              _buildCategoryPriorityCard(),
              const SizedBox(height: spacing),
              _buildCategoriesCard(),
              const SizedBox(height: spacing),
              _buildFunctionCategoryCard(),
            ]),
          ),
          SizedBox(width: constraints.maxWidth, child: _buildBlocksCard()),
        ],
      );
    });
  }

  Widget _buildAccordionLayout() {
    return Column(children: [
      _buildProhibitedCard(),
      _buildPreferredCard(),
      _buildPrioritiesCard(),
      _buildLeadersCard(),
      _buildGeneralRulesCard(),
      _buildCategoryPriorityCard(),
      _buildCategoriesCard(),
      _buildFunctionCategoryCard(),
      _buildBlocksCard(),
    ]);
  }

  Widget _buildProhibitedCard() {
    return _buildCard(
      color: _red(),
      title: 'Combinações Proibidas',
      child: Column(children: [
        SizedBox(
          height: 240,
          child: _prohibitedCombos.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _red().withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.info_outline, size: 16), SizedBox(width: 6), Text('Nenhuma combinação definida')]),
                )
              : ListView(
                  children: _prohibitedCombos.map((c) {
                    final aName = _memberNames[c['a']] ?? c['a']!;
                    final bName = _memberNames[c['b']] ?? c['b']!;
                    final af = c['a_func'] ?? '';
                    final bf = c['b_func'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(border: Border.all(color: _red()), borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(Icons.block, color: _red()),
                        title: Text('$aName ($af) e $bName ($bf)'),
                        subtitle: const Text('Nunca juntos conforme função'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            final list = List<dynamic>.from(_rules['prohibited_combinations'] ?? const []);
                            final ca = c['a'] ?? '';
                            final cb = c['b'] ?? '';
                            final caf = c['a_func'] ?? '';
                            final cbf = c['b_func'] ?? '';
                            final leftSel = '$ca|$caf';
                            final rightSel = '$cb|$cbf';
                            final keySel = (leftSel.compareTo(rightSel) <= 0) ? '$leftSel|$rightSel' : '$rightSel|$leftSel';
                            final filtered = list.where((e) {
                              if (e is Map) {
                                final ea = e['a']?.toString() ?? '';
                                final eb = e['b']?.toString() ?? '';
                                final eaf0 = e['a_func']?.toString() ?? '';
                                final ebf0 = e['b_func']?.toString() ?? '';
                                final eaf = eaf0.isEmpty ? '*' : eaf0;
                                final ebf = ebf0.isEmpty ? '*' : ebf0;
                                final leftE = '$ea|$eaf';
                                final rightE = '$eb|$ebf';
                                final key = (leftE.compareTo(rightE) <= 0) ? '$leftE|$rightE' : '$rightE|$leftE';
                                return key != keySel;
                              }
                              return true;
                            }).toList();
                            setState(() => _rules['prohibited_combinations'] = filtered);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FloatingActionButton.small(
            heroTag: 'add-prohibited-combo',
            onPressed: _addProhibitedCombo,
            backgroundColor: _red(),
            child: const Icon(Icons.add),
          ),
        ),
      ]),
    );
  }

  Widget _buildPreferredCard() {
    return _buildCard(
      color: _green(),
      title: 'Combinações Preferidas (Afinidade)',
      child: Column(children: [
        SizedBox(
          height: 240,
          child: _preferredCombos.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _green().withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.info_outline, size: 16), SizedBox(width: 6), Text('Nenhuma afinidade definida')]),
                )
              : ListView(
                  children: _preferredCombos.map((c) {
                    final aName = _memberNames[c['a']] ?? c['a']!;
                    final bName = _memberNames[c['b']] ?? c['b']!;
                    final af = c['a_func'] ?? '';
                    final bf = c['b_func'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(border: Border.all(color: _green()), borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(Icons.favorite, color: _green()),
                        title: Text('$aName ($af) e $bName ($bf)'),
                        subtitle: const Text('Priorizar juntos conforme função'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            final list = List<dynamic>.from(_rules['preferred_combinations'] ?? const []);
                            final ca = c['a'] ?? '';
                            final cb = c['b'] ?? '';
                            final caf = c['a_func'] ?? '';
                            final cbf = c['b_func'] ?? '';
                            final leftSel = '$ca|$caf';
                            final rightSel = '$cb|$cbf';
                            final keySel = (leftSel.compareTo(rightSel) <= 0) ? '$leftSel|$rightSel' : '$rightSel|$leftSel';
                            final filtered = list.where((e) {
                              if (e is Map) {
                                final ea = e['a']?.toString() ?? '';
                                final eb = e['b']?.toString() ?? '';
                                final eaf0 = e['a_func']?.toString() ?? '';
                                final ebf0 = e['b_func']?.toString() ?? '';
                                final eaf = eaf0.isEmpty ? '*' : eaf0;
                                final ebf = ebf0.isEmpty ? '*' : ebf0;
                                final leftE = '$ea|$eaf';
                                final rightE = '$eb|$ebf';
                                final key = (leftE.compareTo(rightE) <= 0) ? '$leftE|$rightE' : '$rightE|$leftE';
                                return key != keySel;
                              }
                              return true;
                            }).toList();
                            setState(() => _rules['preferred_combinations'] = filtered);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FloatingActionButton.small(
            heroTag: 'add-preferred-combo',
            onPressed: _addPreferredCombo,
            backgroundColor: _green(),
            child: const Icon(Icons.add),
          ),
        ),
      ]),
    );
  }

  Widget _buildPrioritiesCard() {
    final eventTypes = _eventTypes;
    return _buildCard(
      color: _purple(),
      title: 'Prioridade por Membro e Tipo de Evento',
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Membro')),
              const DataColumn(label: Text('Geral')),
              ...eventTypes.map((t) => DataColumn(label: Text(_labelForEvent(t)))),
            ],
            rows: _members.map((m) {
              final pid = m.memberId as String;
              final row = Map<String, dynamic>.from(_memberPriorities[pid] ?? {});
              int general = int.tryParse(row['general']?.toString() ?? '') ?? 3;
              List<DataCell> cells = [
                DataCell(Text(m.memberName)),
                DataCell(_priorityCell(pid, 'general', general)),
                ...eventTypes.map((t) {
                  final v = int.tryParse(row[t]?.toString() ?? '') ?? 3;
                  return DataCell(_priorityCell(pid, t, v));
                }),
              ];
              return DataRow(cells: cells);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  String _labelForEvent(String type) {
    final l = _eventTypeLabels[type];
    if (l != null && l.isNotEmpty) return l;
    switch (type) {
      case 'culto_normal':
        return 'Culto Normal / Ceia';
      case 'ceia':
        return 'Ceia';
      case 'vigilia':
        return 'Vigília ou Culto Especial';
      case 'ensaio':
        return 'Ensaio';
      case 'reuniao_ministerio':
        return 'Reunião do Ministério (interna)';
      case 'reuniao_externa':
        return 'Reunião Externa / Célula';
      case 'evento_conjunto':
        return 'Evento Conjunto';
      case 'lideranca_geral':
        return 'Liderança Geral';
      case 'mutirao':
        return 'Limpeza / Mutirão';
      default:
        final cleaned = type.replaceAll('_', ' ');
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  Widget _priorityCell(String memberId, String key, int v) {
    return DropdownButton<int>(
      value: v,
      items: const [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
      onChanged: (nv) {
        final map = Map<String, dynamic>.from(_rules['member_priorities'] ?? {});
        final row = Map<String, dynamic>.from(map[memberId] ?? {});
        row[key] = nv ?? v;
        map[memberId] = row;
        setState(() => _rules['member_priorities'] = map);
      },
    );
  }

  Widget _buildLeadersCard() {
    return _buildCard(
      color: _purple(),
      title: 'Líderes e Suplentes por Função',
      child: Column(children: [
        ..._functions.map((f) {
          final cfg = Map<String, dynamic>.from(_leadersByFunction[f] ?? {});
          String? leader = cfg['leader']?.toString();
          List<String> subs = List<dynamic>.from(cfg['subs'] ?? const []).map((e) => e.toString()).toList();
          final allowed = _allowedIdsForFunction(f).toSet();
          final leaderInit = (leader != null && allowed.contains(leader)) ? leader : null;
          final sub1Init = (subs.isNotEmpty && allowed.contains(subs[0])) ? subs[0] : null;
          final sub2Init = (subs.length > 1 && allowed.contains(subs[1])) ? subs[1] : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final itemWidth = maxW >= 760 ? 240.0 : (maxW - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
                        SizedBox(
                          width: itemWidth,
                        child: DropdownButtonFormField<String>(
                            initialValue: leaderInit,
                            isExpanded: true,
                            items: _memberDropdownItems(function: f, includeSelected: leaderInit, strict: true),
                            onChanged: (v) {
                              final map = Map<String, dynamic>.from(_rules['leaders_by_function'] ?? {});
                              final row = Map<String, dynamic>.from(map[f] ?? {});
                              row['leader'] = v;
                              map[f] = row;
                              setState(() => _rules['leaders_by_function'] = map);
                            },
                            decoration: const InputDecoration(labelText: 'Líder', border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DropdownButtonFormField<String>(
                            initialValue: sub1Init,
                            isExpanded: true,
                            items: _memberDropdownItems(function: f, includeSelected: sub1Init, strict: true),
                            onChanged: (v) {
                              final map = Map<String, dynamic>.from(_rules['leaders_by_function'] ?? {});
                              final row = Map<String, dynamic>.from(map[f] ?? {});
                              final list = List<String>.from(row['subs'] ?? const []);
                              if (list.isEmpty) list.add('');
                              list[0] = v ?? '';
                              row['subs'] = list.where((e) => e.isNotEmpty).toList();
                              map[f] = row;
                              setState(() => _rules['leaders_by_function'] = map);
                            },
                            decoration: const InputDecoration(labelText: 'Suplente 1', border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DropdownButtonFormField<String>(
                            initialValue: sub2Init,
                            isExpanded: true,
                            items: _memberDropdownItems(function: f, includeSelected: sub2Init, strict: true),
                            onChanged: (v) {
                              final map = Map<String, dynamic>.from(_rules['leaders_by_function'] ?? {});
                              final row = Map<String, dynamic>.from(map[f] ?? {});
                              final list = List<String>.from(row['subs'] ?? const []);
                              while (list.length < 2) { list.add(''); }
                              list[1] = v ?? '';
                              row['subs'] = list.where((e) => e.isNotEmpty).toList();
                              map[f] = row;
                              setState(() => _rules['leaders_by_function'] = map);
                            },
                            decoration: const InputDecoration(labelText: 'Suplente 2', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildGeneralRulesCard() {
    int maxPerMonth = int.tryParse(_generalRules['max_per_month']?.toString() ?? '') ?? 6;
    int maxConsecutive = int.tryParse(_generalRules['max_consecutive']?.toString() ?? '') ?? 2;
    int minDaysBetween = int.tryParse(_generalRules['min_days_between']?.toString() ?? '') ?? 3;
    int minExperienced = int.tryParse(_generalRules['min_experienced']?.toString() ?? '') ?? 1;

    return _buildCard(
      color: _purple(),
      title: 'Regras Gerais do Ministério',
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 240, child: _numberField('Máximo de cultos/mês', maxPerMonth, (v) => _setGeneral('max_per_month', v))),
          SizedBox(width: 240, child: _numberField('Máx. cultos seguidos', maxConsecutive, (v) => _setGeneral('max_consecutive', v))),
          SizedBox(width: 240, child: _numberField('Dias mínimos entre cultos', minDaysBetween, (v) => _setGeneral('min_days_between', v))),
          SizedBox(width: 240, child: _numberField('Pessoas experientes mín.', minExperienced, (v) => _setGeneral('min_experienced', v))),
        ]),
      ]),
    );
  }

  void _setGeneral(String key, int value) {
    final map = Map<String, dynamic>.from(_rules['general_rules'] ?? {});
    map[key] = value;
    setState(() => _rules['general_rules'] = map);
  }

  Widget _numberField(String label, int value, void Function(int) onChanged) {
    final controller = TextEditingController(text: value.toString());
    return TextField(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
      controller: controller,
    );
  }

  Widget _buildBlocksCard() {
    return _buildCard(
      color: _red(),
      title: 'Bloqueios e Exceções',
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('Membro')),
              DataColumn(label: Text('Início')),
              DataColumn(label: Text('Fim')),
              DataColumn(label: Text('Motivo')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Detalhe')),
              DataColumn(label: Text('Ações')),
            ],
            rows: List.generate(_blocks.length, (i) {
              final b = _blocks[i];
              final userId = b['user_id']?.toString() ?? '';
              return DataRow(cells: [
                DataCell(SizedBox(
                  width: 200,
                  child: DropdownButton<String>(
                    value: userId.isEmpty ? null : userId,
                    isExpanded: true,
                    items: _memberDropdownItems(),
                    onChanged: (v) {
                      final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                      if (i >= 0 && i < list.length) {
                        list[i]['user_id'] = v ?? '';
                        setState(() => _rules['blocks'] = list);
                      }
                    },
                  ),
                )),
                DataCell(SizedBox(
                  width: 160,
                  child: TextFormField(
                    key: ValueKey(b['start_date']?.toString() ?? ''),
                    initialValue: _displayDate(b['start_date']?.toString()),
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                          if (i >= 0 && i < list.length) {
                            DateTime? init;
                            final cur = list[i]['start_date']?.toString();
                            if (cur != null && cur.isNotEmpty) {
                              try { init = DateTime.parse(cur); } catch (_) {}
                            }
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: init ?? DateTime.now(),
                              firstDate: DateTime(2000, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked != null) {
                              list[i]['start_date'] = DateFormat('yyyy-MM-dd').format(picked);
                              setState(() => _rules['blocks'] = list);
                            }
                          }
                        },
                      ),
                    ),
                    onChanged: (v) {
                      final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                      if (i >= 0 && i < list.length) {
                        final iso = _isoFromDisplay(v);
                        list[i]['start_date'] = iso.isNotEmpty ? iso : v;
                        setState(() => _rules['blocks'] = list);
                      }
                    },
                  ),
                )),
                DataCell(SizedBox(
                  width: 160,
                  child: TextFormField(
                    key: ValueKey(b['end_date']?.toString() ?? ''),
                    initialValue: _displayDate(b['end_date']?.toString()),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                          if (i >= 0 && i < list.length) {
                            DateTime? init;
                            final cur = list[i]['end_date']?.toString();
                            if (cur != null && cur.isNotEmpty) {
                              try { init = DateTime.parse(cur); } catch (_) {}
                            }
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: init ?? DateTime.now(),
                              firstDate: DateTime(2000, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked != null) {
                              list[i]['end_date'] = DateFormat('yyyy-MM-dd').format(picked);
                              setState(() => _rules['blocks'] = list);
                            }
                          }
                        },
                      ),
                    ),
                    onChanged: (v) {
                      final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                      if (i >= 0 && i < list.length) {
                        final iso = _isoFromDisplay(v);
                        list[i]['end_date'] = iso.isNotEmpty ? iso : v;
                        setState(() => _rules['blocks'] = list);
                      }
                    },
                  ),
                )),
                DataCell(SizedBox(
                  width: 220,
                  child: TextFormField(
                    initialValue: b['reason']?.toString() ?? '',
                    maxLines: 1,
                    textAlign: TextAlign.left,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) {
                      final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                      if (i >= 0 && i < list.length) {
                        list[i]['reason'] = v;
                      }
                    },
                  ),
                )),
                DataCell(SizedBox(
                  width: 180,
                  child: DropdownButton<String>(
                    value: b['type']?.toString(),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'total', child: Text('Bloqueio total')),
                      DropdownMenuItem(value: 'event_type', child: Text('Por tipo de evento')),
                      DropdownMenuItem(value: 'event', child: Text('Por evento específico')),
                    ],
                    onChanged: (v) {
                      final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                      if (i >= 0 && i < list.length) {
                        list[i]['type'] = v ?? 'total';
                        setState(() => _rules['blocks'] = list);
                      }
                    },
                  ),
                )),
                DataCell(Builder(builder: (context) {
                  final type = b['type']?.toString();
                  if (type == 'event_type') {
                    return DropdownButton<String>(
                      value: (b['event_type']?.toString().isNotEmpty == true) ? b['event_type']?.toString() : null,
                      isExpanded: true,
                      items: _eventTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                      onChanged: (v) {
                        final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                        if (i >= 0 && i < list.length) {
                          list[i]['event_type'] = v ?? '';
                          setState(() => _rules['blocks'] = list);
                        }
                      },
                    );
                  } else if (type == 'event') {
                    return DropdownButton<String>(
                      value: (b['event_id']?.toString().isNotEmpty == true) ? b['event_id']?.toString() : null,
                      isExpanded: true,
                      items: _events
                          .map((e) => DropdownMenuItem<String>(
                                value: e.id,
                                child: Text("${e.name} - ${DateFormat('dd/MM/yyyy').format(e.startDate)}"),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                        if (i >= 0 && i < list.length) {
                          list[i]['event_id'] = v ?? '';
                          setState(() => _rules['blocks'] = list);
                        }
                      },
                    );
                  }
                  return const SizedBox.shrink();
                })),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final list = List<Map<String, dynamic>>.from(_rules['blocks'] ?? const []);
                    if (i >= 0 && i < list.length) {
                      list.removeAt(i);
                      setState(() => _rules['blocks'] = list);
                    }
                  },
                )),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FloatingActionButton.small(
            onPressed: () {
              final list = List<Map<String, dynamic>>.from(_blocks);
              list.add({'user_id': '', 'start_date': '', 'end_date': '', 'reason': '', 'type': 'total', 'event_type': '', 'event_id': ''});
              setState(() => _rules['blocks'] = list);
            },
            backgroundColor: _red(),
            child: const Icon(Icons.add),
          ),
        ),
      ]),
    );
  }

  

  List<DropdownMenuItem<String>> _memberDropdownItems({String? function, String? includeSelected, bool strict = true}) {
    List<dynamic> base = [];
    if (function != null && function.isNotEmpty && function.trim() != '*') {
      final ids = Set<String>.from(_membersByFunction[function] ?? const []);
      if (!strict && includeSelected != null && includeSelected.isNotEmpty && !ids.contains(includeSelected)) {
        ids.add(includeSelected);
      }
      base = List<dynamic>.from(_members).where((m) => ids.contains(m.memberId as String)).toList();
    } else {
      final linked = _membersByFunction.values.expand((e) => e).toSet();
      base = List<dynamic>.from(_members).where((m) => linked.contains(m.memberId as String)).toList();
    }
    if (!strict && base.isEmpty) {
      base = List<dynamic>.from(_members);
    }
    base.sort((a, b) => (a.memberName as String).compareTo(b.memberName as String));
    return base
        .map((m) => DropdownMenuItem<String>(value: m.memberId as String, child: Text(m.memberName as String)))
        .toList();
  }

  List<String> _allowedIdsForFunction(String f) {
    return List<String>.from(_membersByFunction[f] ?? const []);
  }

  List<DropdownMenuItem<String>> _functionDropdownItemsForUser(String? userId) {
    final out = <String>{};
    if (userId != null && userId.isNotEmpty) {
      _membersByFunction.forEach((fname, uids) {
        if (uids.contains(userId)) out.add(fname);
      });
    }
    final items = _functions.where((f) => out.contains(f)).toList();
    return items.map((f) => DropdownMenuItem<String>(value: f, child: Text(f))).toList();
  }

  

  bool _isReservedCategory(String? c) {
    if (c == null) return false;
    final s = c.trim().toLowerCase();
    return s == 'instrument' || s == 'voice_role' || s == 'technical' || s == 'other' || s == 'instrumento' || s == 'voz' || s == 'back' || s.startsWith('tec') || s == 'outra' || s == 'outro';
  }

  String _canonReserved(String name) {
    final s = name.trim().toLowerCase();
    if (s.startsWith('inst')) return 'instrument';
    if (s == 'voice_role' || s.startsWith('voz') || s.startsWith('back')) return 'voice_role';
    if (s == 'technical' || s.startsWith('tec')) return 'technical';
    if (s == 'other' || s.startsWith('outr')) return 'other';
    return '';
  }

  List<String> _uniqueCategories() {
    final Map<String, String> map = {};
    for (final c in _availableCategories) {
      final k = c.trim().toLowerCase();
      if (!_isReservedCategory(c) && !map.containsKey(k)) map[k] = c;
    }
    return map.values.toList();
  }

  String _reservedLabel(String key) {
    switch (key) {
      case 'instrument':
        return 'Instrumento';
      case 'voice_role':
        return 'Canto';
      case 'technical':
        return 'Técnico';
      case 'other':
      default:
        return 'Outra';
    }
  }

  Widget _buildFunctionCategoryCard() {
    return _buildCard(
      color: _purple(),
      title: 'Funções',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_functions.isEmpty)
          const Text('Nenhuma função cadastrada para este ministério')
        else
          Column(
            children: _functions.map((f) {
              String canon(String s) {
                final t = s.trim().toLowerCase();
                if (t.startsWith('inst')) return 'instrument';
                if (t == 'voice_role' || t.startsWith('voz') || t.startsWith('back')) return 'voice_role';
                if (t == 'technical' || t.startsWith('tec')) return 'technical';
                if (t == 'other' || t.startsWith('outr')) return 'other';
                return s;
              }
              final currentCat = _functionCategory[f] ?? 'other';
              final selectedCanon = canon(currentCat);
              final String? selected = (selectedCanon == 'other') ? null : selectedCanon;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(f)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: [
                        if (_enabledGroups['instrument'] == true || selected == 'instrument')
                          const DropdownMenuItem(value: 'instrument', child: Text('Instrumento')),
                        if (_enabledGroups['voice_role'] == true || selected == 'voice_role')
                          const DropdownMenuItem(value: 'voice_role', child: Text('Back')),
                        ..._uniqueCategories().map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
                      ],
                      onChanged: (v) {
                        setState(() {
                          if (v != null) {
                            final vCanon = canon(v);
                            _functionCategory[f] = (vCanon == 'other') ? v : vCanon;
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _functions.remove(f);
                        _functionCategory.remove(f);
                      });
                    },
                  ),
                ]),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _newFunctionController,
              decoration: const InputDecoration(labelText: 'Nova função', border: OutlineInputBorder()),
              onSubmitted: (name) {
                final v = name.trim();
                if (v.isEmpty) return;
                setState(() {
                  if (!_functions.contains(v)) {
                    _functions.add(v);
                    _functionCategory.putIfAbsent(v, () => 'other');
                  }
                  _newFunctionController.clear();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              final v = _newFunctionController.text.trim();
              if (v.isEmpty) return;
              setState(() {
                if (!_functions.contains(v)) {
                  _functions.add(v);
                  _functionCategory.putIfAbsent(v, () => 'other');
                }
                _newFunctionController.clear();
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        ]),
      ]),
    );
  }

  

  Widget _buildCategoriesCard() {
    final chipColor = _purple().withValues(alpha: 0.08);
    return _buildCard(
      color: _purple(),
      title: 'Categorias',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Categorias exclusivas por ministério', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // grupos base
            for (final base in const ['instrument', 'voice_role'])
              if (_enabledGroups[base] == true)
                InputChip(
                  label: Text(_reservedLabel(base)),
                  selectedColor: chipColor,
                  onDeleted: () {
                    setState(() {
                      _enabledGroups[base] = false;
                      _exclusiveByGroup[base] = false;
                      _aloneByCategory[base] = false;
                      _exclusiveByCategory.remove(base);
                      _functionCategory.removeWhere((k, v) {
                        final vc = _canonReserved(v);
                        return vc == base || v == base;
                      });
                    });
                  },
                ),
            // categorias dinâmicas
            ..._uniqueCategories().map((c) => InputChip(
                  label: Text(c),
                  selectedColor: chipColor,
                  onDeleted: () {
                    setState(() {
                      _availableCategories.removeWhere((x) => x == c);
                      _functionCategory.removeWhere((k, v) => v == c);
                    });
                  },
                )),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Regras por categoria', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...[
              if (_enabledGroups['instrument'] == true) 'instrument',
              if (_enabledGroups['voice_role'] == true) 'voice_role',
              ..._uniqueCategories(),
            ].map((cat) {
              final isReserved = _isReservedCategory(cat);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isReserved ? _reservedLabel(cat) : cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: (_exclusiveByCategory[cat] ?? (_exclusiveByGroup[cat] ?? false)),
                        title: const Text('Exclusiva dentro da categoria'),
                        subtitle: const Text('Não permitir duas funções desta mesma categoria para a mesma pessoa'),
                        onChanged: (v) {
                          setState(() {
                            if (isReserved) {
                              _exclusiveByGroup[cat] = v;
                            }
                            _exclusiveByCategory[cat] = v;
                          });
                        },
                      ),
                      SwitchListTile(
                        value: (_aloneByCategory[cat] ?? false),
                        title: const Text('Não combinar com outras categorias'),
                        subtitle: const Text('Se marcada, a pessoa só pode ter funções desta categoria no evento'),
                        onChanged: (v) {
                          setState(() {
                            _aloneByCategory[cat] = v;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _newCategoryController,
              decoration: const InputDecoration(labelText: 'Nome da categoria', border: OutlineInputBorder()),
              onSubmitted: (name) {
                final v = name.trim();
                if (v.isEmpty) return;
                if (_isReservedCategory(v)) {
                  final key = _canonReserved(v);
                  if (key.isNotEmpty) {
                    setState(() {
                      _enabledGroups[key] = true;
                      _newCategoryController.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_reservedLabel(key)} reativada para este ministério')),
                    );
                    return;
                  }
                }
                setState(() {
                  if (!_availableCategories.any((x) => x.trim().toLowerCase() == v.toLowerCase())) {
                    _availableCategories.add(v);
                  }
                  _newCategoryController.clear();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              final v = _newCategoryController.text.trim();
              if (v.isEmpty) return;
              if (_isReservedCategory(v)) {
                final key = _canonReserved(v);
                if (key.isNotEmpty) {
                  setState(() {
                    _enabledGroups[key] = true;
                    _newCategoryController.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_reservedLabel(key)} reativada para este ministério')),
                  );
                  return;
                }
              }
              setState(() {
                if (!_availableCategories.any((x) => x.trim().toLowerCase() == v.toLowerCase())) {
                  _availableCategories.add(v);
                }
                _newCategoryController.clear();
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        ]),
      ]),
    );
  }
  Widget _buildCategoryPriorityCard() {
    final items = _categoryOrder;
    return _buildCard(
      color: _purple(),
      title: 'Ordem de Prioridade de Categorias',
      child: Column(children: [
        SizedBox(
          height: 220,
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _categoryOrder.removeAt(oldIndex);
                _categoryOrder.insert(newIndex, item);
              });
            },
            children: [
              for (int i = 0; i < items.length; i++)
                ListTile(
                  key: ValueKey('cat-${items[i]}'),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator),
                  ),
                  title: Text(_isReservedCategory(items[i]) ? _reservedLabel(items[i]) : items[i]),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
