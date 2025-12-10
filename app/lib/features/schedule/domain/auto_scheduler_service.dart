import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../events/domain/models/event.dart';
import '../../ministries/presentation/providers/ministries_provider.dart';
import '../../permissions/providers/permissions_providers.dart';

class AutoSchedulerService {
  /// Gera escalas para um evento específico, aplicando regras por tipo
  /// Comentários incluídos conforme solicitado
  Future<void> generateForEvent({
    required WidgetRef ref,
    required Event event,
    required List<String> ministryIds,
    required bool byFunction,
    bool overwriteExisting = false,
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);

    // Mapear comportamento por tipo
    final type = event.eventType ?? 'culto_normal';
    final globalSchedules = await ministriesRepo.getEventSchedules(event.id);
    final Set<String> globalAssignedMembers = {
      for (final s in globalSchedules) s.memberId
    };
    bool allowMultiMinistries = false;
    try {
      final roleRepo = ref.read(roleContextsRepositoryProvider);
      for (final mid in ministryIds) {
        final ctxs = await roleRepo.getContextsByMinistry(mid);
        for (final c in ctxs) {
          final gr = Map<String, dynamic>.from(c.metadata?['schedule_rules']?['general_rules'] ?? {});
          final v = gr['allow_multi_ministries_per_event'];
          final b = v is bool ? v : (v?.toString().toLowerCase() == 'true');
          if (b) { allowMultiMinistries = true; break; }
        }
        if (allowMultiMinistries) break;
      }
    } catch (_) {}

    if (type == 'reuniao_ministerio' || type == 'reuniao_externa') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries && globalAssignedMembers.contains(m.memberId)) continue;
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': event.isMandatory ? 'Presença obrigatória' : null,
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return;
    }

    if (type == 'lideranca_geral') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members.where((mm) => mm.role.value == 'leader' || mm.role.value == 'coordinator')) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries && globalAssignedMembers.contains(m.memberId)) continue;
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Liderança Geral',
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return;
    }

    if (type == 'mutirao') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries && globalAssignedMembers.contains(m.memberId)) continue;
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Mutirão/Limpeza',
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return;
    }

    // Culto Normal / Ceia / Ensaio / Vigília ou Evento Conjunto por função
    if (byFunction) {
      
      final catalog = await ministriesRepo.getFunctionsCatalog();
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

      for (final ministryId in ministryIds) {
        if (overwriteExisting) {
          await ministriesRepo.clearSchedulesForEventMinistry(event.id, ministryId);
        }
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);

        final Map<String, int> cfg = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = false;
        bool exclusiveVoiceRole = false;
        bool exclusiveOther = false;
        final Map<String, List<String>> assignedByFunction = {};
        final List<Map<String, dynamic>> blocks = [];
        final List<Map<String, String>> prohibitedCombos = [];
        final List<Map<String, String>> preferredCombos = [];
        final Map<String, dynamic> memberPriorities = {};
        final Map<String, dynamic> leadersByFunction = {};
        int? maxPerMonth;
        int? minDaysBetween;
        int? maxConsecutive;
        int? minExperienced;

          for (final c in contexts) {
            final meta = c.metadata ?? {};
          final eventReq = meta['event_function_requirements'];
          if (eventReq is Map) {
            final Map<String, dynamic> reqForType = Map<String, dynamic>.from(eventReq[event.eventType] ?? {});
            reqForType.forEach((k, v) {
              final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
              if (n > 0) cfg[norm(k.toString())] = n;
            });
          }
          if (cfg.isEmpty) {
            final req = meta['function_requirements'];
            if (req is Map) {
              req.forEach((k, v) {
                final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
                if (n > 0) cfg[norm(k.toString())] = n;
              });
            }
          }
          final catMap = Map<String, dynamic>.from(meta['function_category_by_function'] ?? {});
          catMap.forEach((k, v) => funcCategory[norm(k.toString())] = v.toString());
          final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
          exclusiveInstrument = (restrictions['instrument']?['exclusive'] as bool?) ?? exclusiveInstrument;
          exclusiveVoiceRole = (restrictions['voice_role']?['exclusive'] as bool?) ?? exclusiveVoiceRole;
          exclusiveOther = (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          exclusiveOther = (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          final assigned = Map<String, dynamic>.from(meta['assigned_functions'] ?? {});
          assigned.forEach((userId, funcs) {
            for (final f in List<dynamic>.from(funcs ?? const [])) {
              final name = norm(f.toString());
              assignedByFunction.putIfAbsent(name, () => []).add(userId.toString());
            }
          });
          final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
          final bl = List<dynamic>.from(rules['blocks'] ?? const []);
          for (final b in bl) {
            if (b is Map) blocks.add(Map<String, dynamic>.from(b));
          }
          final pc = List<dynamic>.from(rules['prohibited_combinations'] ?? const []);
          for (final p in pc) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty) prohibitedCombos.add({'a': a, 'b': b, 'a_func': af, 'b_func': bf});
            }
          }
          final pr = List<dynamic>.from(rules['preferred_combinations'] ?? const []);
          for (final p in pr) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty) preferredCombos.add({'a': a, 'b': b, 'a_func': af, 'b_func': bf});
            }
          }
          final mp = Map<String, dynamic>.from(rules['member_priorities'] ?? {});
          mp.forEach((k, v) => memberPriorities[k] = v);
          final lf = Map<String, dynamic>.from(rules['leaders_by_function'] ?? {});
          lf.forEach((k, v) => leadersByFunction[k] = v);
          final gr = Map<String, dynamic>.from(rules['general_rules'] ?? {});
          int? pInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
          maxPerMonth = pInt(gr['max_per_month']) ?? maxPerMonth;
          maxConsecutive = pInt(gr['max_consecutive']) ?? maxConsecutive;
          minDaysBetween = pInt(gr['min_days_between']) ?? minDaysBetween;
          minExperienced = pInt(gr['min_experienced']) ?? minExperienced;
        }

        // Completar candidatos por função com vínculos do banco (member_function)
        Map<String, List<String>> mfMap = {};
        try {
          mfMap = await ministriesRepo.getMemberFunctionsByMinistry(ministryId);
          for (final entry in mfMap.entries) {
            final uid = entry.key;
            for (final f in entry.value) {
              final fn = norm(f);
              assignedByFunction.putIfAbsent(fn, () => []);
              if (!assignedByFunction[fn]!.contains(uid)) {
                assignedByFunction[fn]!.add(uid);
              }
            }
          }
        } catch (_) {}

        // Mapa de categorias permitidas por usuário com base nas funções atribuídas
        final Map<String, Set<String>> allowedCategoriesByUser = {};
        assignedByFunction.forEach((func, uids) {
          final cat = funcCategory[func] ?? 'other';
          for (final uid in uids) {
            allowedCategoriesByUser.putIfAbsent(uid, () => <String>{});
            allowedCategoriesByUser[uid]!.add(cat);
          }
        });

        final Set<String> assignedMembers = {};
        final Set<String> assignedInstrumentMembers = {};
        final Set<String> assignedVoiceMembers = {};
        final Map<String, List<String>> assignedFunctionsEvent = {};
        final Map<String, dynamic> membersById = { for (final m in members) m.memberId : m };
        final Map<String, List<DateTime>> datesByUser = {};
        for (final s in existingSchedules) {
          if (s.eventStartDate != null) {
            datesByUser.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
          }
        }
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        final existingByFuncId = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => '${s.memberId}|${(s.functionId ?? '').toString()}')
            .toSet();
        assignedMembers.addAll(existingForEvent);
        final Set<String> exclusiveWithinCats = {};
        final Set<String> exclusiveAloneCats = {};
        {
          // Agregar exclusividades de todos os contexts
          final allContexts = contexts;
          for (final c in allContexts) {
            final meta = c.metadata ?? {};
            final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
            restrictions.forEach((k, v) {
              if (v is Map) {
                if ((v['exclusive'] as bool?) == true) exclusiveWithinCats.add(k.toString());
                if ((v['alone'] as bool?) == true) exclusiveAloneCats.add(k.toString());
              }
            });
          }
        }
        final Map<String, Set<String>> assignedCategoriesByUser = {};

        bool violatesMonth(String uid) {
          if (maxPerMonth == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          final m = event.startDate.month;
          final y = event.startDate.year;
          final count = list.where((d) => d.month == m && d.year == y).length;
          return count >= maxPerMonth;
        }
        bool violatesMinDays(String uid) {
          if (minDaysBetween == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          if (list.isEmpty) return false;
          list.sort((a, b) => a.compareTo(b));
          DateTime? last;
          for (final d in list) {
            if (d.isBefore(event.startDate)) {
              last = d;
            } else {
              break;
            }
          }
          if (last == null) return false;
          final diff = event.startDate.difference(last).inDays;
          return diff < minDaysBetween;
        }
        bool isExperienced(String uid) {
          final m = membersById[uid];
          if (m == null) return false;
          return m.role.value != 'member';
        }
          // partnersForFunc será construído dentro do loop por função
        int experiencedCount = 0;
        bool isBlocked(String uid) {
          DateTime d = event.startDate;
          for (final b in blocks) {
            final u = b['user_id']?.toString() ?? '';
            if (u != uid) continue;
            final type = b['type']?.toString() ?? 'total';
            final sd = DateTime.tryParse(b['start_date']?.toString() ?? '');
            final ed = DateTime.tryParse(b['end_date']?.toString() ?? '');
            if (type == 'evento') {
              if (sd != null && sd.year == d.year && sd.month == d.month && sd.day == d.day) return true;
            } else {
              if (sd != null && ed != null && !d.isBefore(sd) && !d.isAfter(ed)) return true;
              if (sd != null && ed == null && !d.isBefore(sd)) return true;
              if (sd == null && ed != null && !d.isAfter(ed)) return true;
            }
          }
          return false;
        }
        bool violatesProhibited(String uid, String currentFunc) {
          bool eq(String x, String y) => norm(x) == norm(y);
          for (final other in assignedMembers) {
            final funcsOther = List<String>.from(assignedFunctionsEvent[other] ?? const []);
            for (final p in prohibitedCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              if (uid == a && other == b) {
                final aOk = (af == '*' || eq(af, currentFunc));
                final bOk = funcsOther.any((f) => bf == '*' || eq(bf, f));
                if (aOk && bOk) return true;
              }
              if (uid == b && other == a) {
                final bOk = (bf == '*' || eq(bf, currentFunc));
                final aOk = funcsOther.any((f) => af == '*' || eq(af, f));
                if (aOk && bOk) return true;
              }
            }
          }
          return false;
        }
        int prioFor(String uid) {
          final row = memberPriorities[uid];
          if (row is Map) {
            final t = event.eventType?.toString() ?? 'general';
            final v = row[t] ?? row['general'];
            final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 3;
            return n;
          }
          return 3;
        }

        

        // Removido: reserva de candidatos únicos por função. Seguir apenas a ordem de categorias.

        final List<MapEntry<String,int>> orderedCfg = (){
          final order = <String>[];
          final metaOrder = contexts
              .map((c) => (c.metadata?['category_order'] as List?)?.map((e)=>e.toString()).toList() ?? const <String>[])
              .firstWhere((l) => l.isNotEmpty, orElse: () => const <String>[]);
          if (metaOrder.isNotEmpty) {
            order.addAll(metaOrder);
          } else {
            order.addAll(['voice_role','instrument','other']);
          }
          int catRank(String f){
            final cat = funcCategory[f] ?? 'other';
            final idx = order.indexOf(cat);
            return idx >= 0 ? idx : order.length;
          }
          final list = cfg.entries.toList();
          list.sort((a,b){
            final ra = catRank(a.key);
            final rb = catRank(b.key);
            if (ra != rb) return ra.compareTo(rb);
            return a.key.compareTo(b.key);
          });
          return list;
        }();

        for (final entry in orderedCfg) {
          final funcName = entry.key;
          final needed = entry.value;
          int count = 0;
          final cat = funcCategory[funcName] ?? 'other';
          final Map<String, List<DateTime>> datesByUserFunc = {};
          final String? fid = fidForFunc(funcName);
          for (final s in existingSchedules) {
            final matchById = fid != null && (s.functionId == fid);
            final matchByName = fid == null && (norm((s.functionName ?? '')) == norm(funcName));
            if (s.eventStartDate != null && (matchById || matchByName)) {
              datesByUserFunc.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
            }
          }
          int consecutiveFor(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            if (list.isEmpty) return 0;
            list.sort((a, b) => a.compareTo(b));
            // percorre de trás pra frente até antes do evento atual
            final prevs = list.where((d) => d.isBefore(event.startDate)).toList();
            if (prevs.isEmpty) return 0;
            int streak = 1;
            DateTime last = prevs.last;
            for (int i = prevs.length - 2; i >= 0; i--) {
              final d = prevs[i];
              final diff = last.difference(d).inDays.abs();
              if (diff <= 9) {
                streak++;
                last = d;
              } else {
                break;
              }
            }
            return streak;
          }

          final Map<String, List<String>> reservedByFunction = {};

          // Construir candidatos: apenas atribuídos + líder/subs (sem fallback por cargo)
          final assignedCandidates0 = List<String>.from(assignedByFunction[funcName] ?? const []);
          final leaderCfg = Map<String, dynamic>.from(leadersByFunction[funcName] ?? {});
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(leaderCfg['subs'] ?? const []).map((e) => e.toString()).toList();
          final seeds = <String>{...assignedCandidates0, if (leaderId != null) leaderId, ...subs};
          var assignedCandidates = seeds.where((uid) => !isBlocked(uid) && !violatesMonth(uid) && !violatesMinDays(uid)).toList();
          final maxC = maxConsecutive ?? 0;
          if (maxC > 0) {
            final allowed = assignedCandidates.where((uid) => consecutiveFor(uid) < maxC).toList();
            final overflow = assignedCandidates.where((uid) => consecutiveFor(uid) >= maxC).toList();
            assignedCandidates = [...allowed, ...overflow];
          }
          int scheduledCountMonth(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            final m = event.startDate.month;
            final y = event.startDate.year;
            return list.where((d) => d.month == m && d.year == y).length;
          }
          assignedCandidates.sort((a, b) {
            final pa = prioFor(a);
            final pb = prioFor(b);
            if ((minExperienced ?? 0) > experiencedCount) {
              final ea = isExperienced(a);
              final eb = isExperienced(b);
              if (ea != eb) return ea ? -1 : 1;
            }
            final cmp = pa.compareTo(pb);
            if (cmp != 0) return cmp;
            return scheduledCountMonth(a).compareTo(scheduledCountMonth(b));
          });
          final reserved = List<String>.from(reservedByFunction[funcName] ?? const <String>[])
              .where((uid) => assignedCandidates.contains(uid))
              .toList();
          for (int i = reserved.length - 1; i >= 0; i--) {
            final r = reserved[i];
            assignedCandidates.remove(r);
            assignedCandidates.insert(0, r);
          }
          if (leaderId != null && assignedCandidates.contains(leaderId)) {
            assignedCandidates.remove(leaderId);
            assignedCandidates.insert(0, leaderId);
          }
          for (int i = subs.length - 1; i >= 0; i--) {
            final sid = subs[i];
            if (assignedCandidates.contains(sid)) {
              assignedCandidates.remove(sid);
              assignedCandidates.insert(0, sid);
            }
          }
          int idxA = 0;
          while (count < needed && idxA < assignedCandidates.length) {
            final uid = assignedCandidates[idxA];
            if (!membersById.containsKey(uid)) { idxA++; continue; }
            // Não reservar candidatos únicos: seguir prioridade e regras.
            if (assignedMembers.contains(uid)) {
              final cats = assignedCategoriesByUser[uid] ?? <String>{};
              final allowedCats = allowedCategoriesByUser[uid] ?? const <String>{};
              if (allowedCats.length == 1) {
                final onlyCat = allowedCats.first;
                if (cats.contains(onlyCat) && cat != onlyCat) { idxA++; continue; }
              }
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) { idxA++; continue; }
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) { idxA++; continue; }
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) { idxA++; continue; }
              if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(uid)) { idxA++; continue; }
              if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(uid)) { idxA++; continue; }
              if (cat == 'other' && exclusiveOther) { idxA++; continue; }
            }
            if (isBlocked(uid)) { idxA++; continue; }
            if (violatesProhibited(uid, funcName)) { idxA++; continue; }
            if (violatesMonth(uid)) { idxA++; continue; }
            if (violatesMinDays(uid)) { idxA++; continue; }
            if (maxC > 0 && consecutiveFor(uid) >= maxC) { idxA++; continue; }
            
            final keyById = '$uid|${fid ?? ''}';
            if (existingByFuncId.contains(keyById)) { idxA++; continue; }
            await ministriesRepo.addSchedule({
              'event_id': event.id,
              'ministry_id': ministryId,
              'user_id': uid,
              'function_id': fid,
              'notes': funcName,
            });
            assignedMembers.add(uid);
            if (cat == 'instrument') assignedInstrumentMembers.add(uid);
            if (cat == 'voice_role') assignedVoiceMembers.add(uid);
            assignedCategoriesByUser.putIfAbsent(uid, () => <String>{}).add(cat);
            assignedFunctionsEvent.putIfAbsent(uid, () => []).add(funcName);
            datesByUserFunc.putIfAbsent(uid, () => []).add(event.startDate);
            if (isExperienced(uid)) experiencedCount++;
            idxA++;
            count++;

            // Após alocar uid em funcName, reservar preferências cruzadas para outras funções
            for (final p in preferredCombos) {
              final a = p['a']!; final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              bool eq(String x, String y) => norm(x) == norm(y);
              if (uid == a && (af == '*' || eq(af, funcName)) && bf != '*' && !eq(bf, funcName)) {
                reservedByFunction.putIfAbsent(bf, () => []).add(b);
                // Preferência do próprio usuário na função alvo, se possível
                reservedByFunction.putIfAbsent(bf, () => []).add(a);
              } else if (uid == b && (bf == '*' || eq(bf, funcName)) && af != '*' && !eq(af, funcName)) {
                reservedByFunction.putIfAbsent(af, () => []).add(a);
                reservedByFunction.putIfAbsent(af, () => []).add(b);
              }
            }
            if (count < needed) {
              for (final p in prohibitedCombos) {
                final a = p['a']?.toString();
                final b = p['b']?.toString();
                final af = (p['a_func'] ?? '*').toString();
                final bf = (p['b_func'] ?? '*').toString();
                bool eq(String x, String y) => norm(x) == norm(y);
                // Bloquear parceiro apenas se a restrição envolver a função atual
                if (uid == a && (af == '*' || eq(af, funcName)) && (bf == '*' || eq(bf, funcName))) {
                  assignedCandidates.removeWhere((x) => x == b);
                } else if (uid == b && (bf == '*' || eq(bf, funcName)) && (af == '*' || eq(af, funcName))) {
                  assignedCandidates.removeWhere((x) => x == a);
                }
              }
            }
          }

          if (count < needed && subs.isNotEmpty) {
            final List<String> subsTry = subs
                .where((sid) => membersById.containsKey(sid))
                .where((sid) => !isBlocked(sid))
                .where((sid) => !violatesMonth(sid))
                .where((sid) => !violatesMinDays(sid))
                .where((sid) => !(maxC > 0 && consecutiveFor(sid) >= maxC))
                .toList();
            for (final sid in subsTry) {
              if (count >= needed) break;
              if (assignedMembers.contains(sid)) continue;
              final cats = assignedCategoriesByUser[sid] ?? <String>{};
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) continue;
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) continue;
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) continue;
              if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(sid)) continue;
              if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(sid)) continue;
              if (cat == 'other' && exclusiveOther) continue;
              if (violatesProhibited(sid, funcName)) continue;
              final keyById = '$sid|${fid ?? ''}';
              if (existingByFuncId.contains(keyById)) continue;
              await ministriesRepo.addSchedule({
                'event_id': event.id,
                'ministry_id': ministryId,
                'user_id': sid,
                'function_id': fid,
                'notes': funcName,
              });
              assignedMembers.add(sid);
              if (cat == 'instrument') assignedInstrumentMembers.add(sid);
              if (cat == 'voice_role') assignedVoiceMembers.add(sid);
              assignedCategoriesByUser.putIfAbsent(sid, () => <String>{}).add(cat);
              assignedFunctionsEvent.putIfAbsent(sid, () => []).add(funcName);
              datesByUserFunc.putIfAbsent(sid, () => []).add(event.startDate);
              if (isExperienced(sid)) experiencedCount++;
              count++;
            }
          }

          
        }
      }
      return;
    }

    // Evento conjunto apenas presença
    for (final ministryId in ministryIds) {
      final members = await ministriesRepo.getMinistryMembers(ministryId);
      final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
      final rules = contexts.isNotEmpty ? Map<String, dynamic>.from(contexts.first.metadata?['schedule_rules'] ?? {}) : <String, dynamic>{};
      final maxPerMonth = rules['max_per_month'] as int?;
      final minDaysBetween = rules['min_days_between'] as int?;
      final Map<String, List<DateTime>> datesByUser = {};
      for (final s in existingSchedules) {
        if (s.eventStartDate != null) {
          datesByUser.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
        }
      }
      bool violatesMonth(String uid) {
        if (maxPerMonth == null) return false;
        final list = List<DateTime>.from(datesByUser[uid] ?? const []);
        final m = event.startDate.month;
        final y = event.startDate.year;
        final count = list.where((d) => d.month == m && d.year == y).length;
        return count >= maxPerMonth;
      }
      bool violatesMinDays(String uid) {
        if (minDaysBetween == null) return false;
        final list = List<DateTime>.from(datesByUser[uid] ?? const []);
        if (list.isEmpty) return false;
        list.sort((a, b) => a.compareTo(b));
        DateTime? last;
        for (final d in list) {
          if (d.isBefore(event.startDate)) {
            last = d;
          } else {
            break;
          }
        }
        if (last == null) return false;
        final diff = event.startDate.difference(last).inDays;
        return diff < minDaysBetween;
      }
      for (final m in members) {
        if (violatesMonth(m.memberId)) continue;
        if (violatesMinDays(m.memberId)) continue;
        if (globalAssignedMembers.contains(m.memberId)) continue;
        await ministriesRepo.addSchedule({
          'event_id': event.id,
          'ministry_id': ministryId,
          'user_id': m.memberId,
          'notes': 'Presença Geral',
        });
        globalAssignedMembers.add(m.memberId);
      }
    }
  }

  /// Gera uma proposta de escala sem persistir no banco
  /// Retorna uma lista de mapas: { 'event_id', 'ministry_id', 'user_id', 'notes' }
  Future<List<Map<String, String>>> generateProposalForEvent({
    required WidgetRef ref,
    required Event event,
    required List<String> ministryIds,
    required bool byFunction,
    bool overwriteExisting = false,
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);
    final proposals = <Map<String, String>>[];

    final type = event.eventType ?? 'culto_normal';
    final globalSchedules = await ministriesRepo.getEventSchedules(event.id);
    final Set<String> globalAssignedMembers = {
      for (final s in globalSchedules) s.memberId
    };

    if (type == 'reuniao_ministerio' || type == 'reuniao_externa') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          if (globalAssignedMembers.contains(m.memberId)) continue;
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': event.isMandatory ? 'Presença obrigatória' : '',
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return proposals;
    }

    if (type == 'lideranca_geral') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members.where((mm) => mm.role.value == 'leader' || mm.role.value == 'coordinator')) {
          if (globalAssignedMembers.contains(m.memberId)) continue;
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Liderança Geral',
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return proposals;
    }

    if (type == 'mutirao') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          if (globalAssignedMembers.contains(m.memberId)) continue;
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Mutirão/Limpeza',
          });
          globalAssignedMembers.add(m.memberId);
        }
      }
      return proposals;
    }

    if (byFunction) {
      final catalog = await ministriesRepo.getFunctionsCatalog();
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
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);

        final Map<String, int> cfg = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = false;
        bool exclusiveVoiceRole = false;
        bool exclusiveOther = false;
        bool allowMultiMinistries = false;
        final Map<String, List<String>> assignedByFunction = {};
        final List<Map<String, dynamic>> blocks = [];
        final List<Map<String, String>> prohibitedCombos = [];
        final List<Map<String, String>> preferredCombos = [];
        final Map<String, dynamic> memberPriorities = {};
        final Map<String, dynamic> leadersByFunction = {};
        int? maxPerMonth;
        int? minDaysBetween;
        int? maxConsecutive;

        for (final c in contexts) {
          final meta = c.metadata ?? {};
          final eventReq = meta['event_function_requirements'];
          if (eventReq is Map) {
            final Map<String, dynamic> reqForType = Map<String, dynamic>.from(eventReq[event.eventType] ?? {});
            reqForType.forEach((k, v) {
              final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
              if (n > 0) cfg[k.toString()] = n;
            });
          }
          if (cfg.isEmpty) {
            final req = meta['function_requirements'];
            if (req is Map) {
              req.forEach((k, v) {
                final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
                if (n > 0) cfg[k.toString()] = n;
              });
            }
          }
          final catMap = Map<String, dynamic>.from(meta['function_category_by_function'] ?? {});
          catMap.forEach((k, v) => funcCategory[k] = v.toString());
          final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
          exclusiveInstrument = (restrictions['instrument']?['exclusive'] as bool?) ?? exclusiveInstrument;
          exclusiveVoiceRole = (restrictions['voice_role']?['exclusive'] as bool?) ?? exclusiveVoiceRole;
          exclusiveOther = (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          final assigned = Map<String, dynamic>.from(meta['assigned_functions'] ?? {});
          assigned.forEach((userId, funcs) {
            for (final f in List<dynamic>.from(funcs ?? const [])) {
              final name = f.toString();
              assignedByFunction.putIfAbsent(name, () => []).add(userId.toString());
            }
          });
          final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
          final bl = List<dynamic>.from(rules['blocks'] ?? const []);
          for (final b in bl) {
            if (b is Map) blocks.add(Map<String, dynamic>.from(b));
          }
          final pc = List<dynamic>.from(rules['prohibited_combinations'] ?? const []);
          for (final p in pc) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty) prohibitedCombos.add({'a': a, 'b': b, 'a_func': af, 'b_func': bf});
            }
          }
          final pr = List<dynamic>.from(rules['preferred_combinations'] ?? const []);
          for (final p in pr) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty) preferredCombos.add({'a': a, 'b': b, 'a_func': af, 'b_func': bf});
            }
          }
          final mp = Map<String, dynamic>.from(rules['member_priorities'] ?? {});
          mp.forEach((k, v) => memberPriorities[k] = v);
          final lf = Map<String, dynamic>.from(rules['leaders_by_function'] ?? {});
          lf.forEach((k, v) => leadersByFunction[k] = v);
          final gr = Map<String, dynamic>.from(rules['general_rules'] ?? {});
          int? pInt2(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
          maxPerMonth = pInt2(gr['max_per_month']) ?? maxPerMonth;
          minDaysBetween = pInt2(gr['min_days_between']) ?? minDaysBetween;
          maxConsecutive = pInt2(gr['max_consecutive']) ?? maxConsecutive;
          final am = gr['allow_multi_ministries_per_event'];
          final amBool = am is bool ? am : (am?.toString().toLowerCase() == 'true');
          allowMultiMinistries = allowMultiMinistries || (amBool == true);
          final _ = gr['category_priority'];
        }

        // Mapa de categorias permitidas por usuário com base nas funções atribuídas (prévia)
        final Map<String, Set<String>> allowedCategoriesByUser = {};
        assignedByFunction.forEach((func, uids) {
          final cat = funcCategory[func] ?? 'other';
          for (final uid in uids) {
            allowedCategoriesByUser.putIfAbsent(uid, () => <String>{});
            allowedCategoriesByUser[uid]!.add(cat);
          }
        });

        // Completar candidatos por função com vínculos do banco (member_function)
        try {
          final mfMap = await ministriesRepo.getMemberFunctionsByMinistry(ministryId);
          for (final entry in mfMap.entries) {
            final uid = entry.key;
            for (final f in entry.value) {
              assignedByFunction.putIfAbsent(f, () => []);
              if (!assignedByFunction[f]!.contains(uid)) {
                assignedByFunction[f]!.add(uid);
              }
            }
          }
        } catch (_) {}

        final Set<String> assignedMembers = {};
        final Set<String> assignedInstrumentMembers = {};
        final Set<String> assignedVoiceMembers = {};
        final Map<String, List<String>> assignedFunctionsEvent = {};
        final Map<String, dynamic> membersById = { for (final m in members) m.memberId : m };
        final Map<String, List<DateTime>> datesByUser = {};
        for (final s in existingSchedules) {
          if (s.eventStartDate != null) {
            datesByUser.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
          }
        }
        // Agregar exclusividades por categoria a partir dos contexts
        final Set<String> exclusiveWithinCats = {};
        final Set<String> exclusiveAloneCats = {};
        for (final c in contexts) {
          final meta = c.metadata ?? {};
          final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
          restrictions.forEach((k, v) {
            if (v is Map) {
              if ((v['exclusive'] as bool?) == true) exclusiveWithinCats.add(k.toString());
              if ((v['alone'] as bool?) == true) exclusiveAloneCats.add(k.toString());
            }
          });
        }

        bool violatesMonth(String uid) {
          if (maxPerMonth == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          final m = event.startDate.month;
          final y = event.startDate.year;
          final count = list.where((d) => d.month == m && d.year == y).length;
          return count >= maxPerMonth;
        }
        bool violatesMinDays(String uid) {
          if (minDaysBetween == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          if (list.isEmpty) return false;
          list.sort((a, b) => a.compareTo(b));
          DateTime? last;
          for (final d in list) {
            if (d.isBefore(event.startDate)) {
              last = d;
            } else {
              break;
            }
          }
          if (last == null) return false;
          final diff = event.startDate.difference(last).inDays;
          return diff < minDaysBetween;
        }
        bool isBlocked(String uid) {
          DateTime d = event.startDate;
          for (final b in blocks) {
            final u = b['user_id']?.toString() ?? '';
            if (u != uid) continue;
            final type = b['type']?.toString() ?? 'total';
            final sd = DateTime.tryParse(b['start_date']?.toString() ?? '');
            final ed = DateTime.tryParse(b['end_date']?.toString() ?? '');
            if (type == 'evento') {
              if (sd != null && sd.year == d.year && sd.month == d.month && sd.day == d.day) return true;
            } else {
              if (sd != null && ed != null && !d.isBefore(sd) && !d.isAfter(ed)) return true;
              if (sd != null && ed == null && !d.isBefore(sd)) return true;
              if (sd == null && ed != null && !d.isAfter(ed)) return true;
            }
          }
          return false;
        }
        bool violatesProhibited(String uid, String currentFunc) {
          for (final other in assignedMembers) {
            final funcsOther = List<String>.from(assignedFunctionsEvent[other] ?? const []);
            for (final p in prohibitedCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              bool eq(String x, String y) => norm(x) == norm(y);
              if (uid == a && other == b) {
                final aOk = (af == '*' || eq(af, currentFunc));
                final bOk = funcsOther.any((f) => bf == '*' || eq(bf, f));
                if (aOk && bOk) return true;
              }
              if (uid == b && other == a) {
                final bOk = (bf == '*' || eq(bf, currentFunc));
                final aOk = funcsOther.any((f) => af == '*' || eq(af, f));
                if (aOk && bOk) return true;
              }
            }
          }
          return false;
        }
        int prioFor(String uid) {
          final row = memberPriorities[uid];
          if (row is Map) {
            final t = event.eventType?.toString() ?? 'general';
            final v = row[t] ?? row['general'];
            final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 3;
            return n;
          }
          return 3;
        }

        

        final Map<String, List<String>> candidatesByFunction = {};
        for (final entry in cfg.entries) {
          final f = entry.key;
          final assignedCandidates0 = List<String>.from(assignedByFunction[f] ?? const []);
          final leaderCfg0 = Map<String, dynamic>.from(leadersByFunction[f] ?? {});
          final leaderId0 = leaderCfg0['leader']?.toString();
          final subs0 = List<dynamic>.from(leaderCfg0['subs'] ?? const []).map((e) => e.toString()).toList();
          final seeds0 = <String>{...assignedCandidates0, if (leaderId0 != null) leaderId0, ...subs0};
          candidatesByFunction[f] = seeds0.toList();
        }

        final List<MapEntry<String,int>> orderedCfg = (){
          final order = <String>[];
          final metaOrder = contexts
              .map((c) => (c.metadata?['category_order'] as List?)?.map((e)=>e.toString()).toList() ?? const <String>[])
              .firstWhere((l) => l.isNotEmpty, orElse: () => const <String>[]);
          if (metaOrder.isNotEmpty) {
            order.addAll(metaOrder);
          } else {
            order.addAll(['voice_role','instrument','other']);
          }
          int catRank(String f){
            final cat = funcCategory[f] ?? 'other';
            final idx = order.indexOf(cat);
            return idx >= 0 ? idx : order.length;
          }
          final list = cfg.entries.toList();
          final Map<String, int> funcPri = {'ministrante': 1, 'back': 2};
          list.sort((a,b){
            final ra = catRank(a.key);
            final rb = catRank(b.key);
            if (ra != rb) return ra.compareTo(rb);
            final fa = funcPri[a.key] ?? 99;
            final fb = funcPri[b.key] ?? 99;
            if (fa != fb) return fa.compareTo(fb);
            return a.key.compareTo(b.key);
          });
          return list;
        }();

        final Map<String, List<String>> reservedByFunction = {};
        for (final entry in orderedCfg) {
          final funcName = entry.key;
          final needed = entry.value;
          int count = 0;
          final cat = funcCategory[funcName] ?? 'other';
          final String? fid = fidForFunc(funcName);
          final Map<String, List<DateTime>> datesByUserFunc = {};
          for (final s in existingSchedules) {
            final matchById = fid != null && (s.functionId == fid);
            final matchByName = fid == null && (norm((s.functionName ?? '')) == norm(funcName));
            if (s.eventStartDate != null && (matchById || matchByName)) {
              datesByUserFunc.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
            }
          }
          int consecutiveFor(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            if (list.isEmpty) return 0;
            list.sort((a, b) => a.compareTo(b));
            final prevs = list.where((d) => d.isBefore(event.startDate)).toList();
            if (prevs.isEmpty) return 0;
            int streak = 1;
            DateTime last = prevs.last;
            for (int i = prevs.length - 2; i >= 0; i--) {
              final d = prevs[i];
              final diff = last.difference(d).inDays.abs();
              if (diff <= 9) {
                streak++;
                last = d;
              } else {
                break;
              }
            }
            return streak;
          }

          final assignedCandidates0 = List<String>.from(assignedByFunction[funcName] ?? const []);
          final leaderCfg = Map<String, dynamic>.from(leadersByFunction[funcName] ?? {});
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(leaderCfg['subs'] ?? const []).map((e) => e.toString()).toList();
          final seeds = <String>{...assignedCandidates0, if (leaderId != null) leaderId, ...subs};
          var assignedCandidates = seeds.where((uid) => !isBlocked(uid) && !violatesMonth(uid) && !violatesMinDays(uid)).toList();
          final maxC = maxConsecutive ?? 0;
          if (maxC > 0) {
            final allowed = assignedCandidates.where((uid) => consecutiveFor(uid) < maxC).toList();
            final overflow = assignedCandidates.where((uid) => consecutiveFor(uid) >= maxC).toList();
            assignedCandidates = [...allowed, ...overflow];
          }
          assignedCandidates.sort((a, b) => prioFor(a).compareTo(prioFor(b)));
          final reserved = List<String>.from(reservedByFunction[funcName] ?? const <String>[]) 
              .where((uid) => assignedCandidates.contains(uid))
              .toList();
          for (int i = reserved.length - 1; i >= 0; i--) {
            final r = reserved[i];
            assignedCandidates.remove(r);
            assignedCandidates.insert(0, r);
          }
          if (leaderId != null && assignedCandidates.contains(leaderId)) {
            assignedCandidates.remove(leaderId);
            assignedCandidates.insert(0, leaderId);
          }
          for (int i = subs.length - 1; i >= 0; i--) {
            final sid = subs[i];
            if (assignedCandidates.contains(sid)) {
              assignedCandidates.remove(sid);
              assignedCandidates.insert(0, sid);
            }
          }
          int idxA = 0;
          final Map<String, Set<String>> assignedCategoriesByUser = {};
          while (count < needed && idxA < assignedCandidates.length) {
            final uid = assignedCandidates[idxA];
            if (!membersById.containsKey(uid)) { idxA++; continue; }
            if (assignedMembers.contains(uid)) {
              final cats = assignedCategoriesByUser[uid] ?? <String>{};
              final allowedCats = allowedCategoriesByUser[uid] ?? const <String>{};
              if (allowedCats.length == 1) {
                final onlyCat = allowedCats.first;
                if (cats.contains(onlyCat) && cat != onlyCat) { idxA++; continue; }
              }
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) { idxA++; continue; }
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) { idxA++; continue; }
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) { idxA++; continue; }
              if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(uid)) { idxA++; continue; }
              if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(uid)) { idxA++; continue; }
              if (cat == 'other' && exclusiveOther) { idxA++; continue; }
            }
            if (isBlocked(uid)) { idxA++; continue; }
            if (violatesProhibited(uid, funcName)) { idxA++; continue; }
            if (violatesMonth(uid)) { idxA++; continue; }
            if (violatesMinDays(uid)) { idxA++; continue; }
            if (maxC > 0 && consecutiveFor(uid) >= maxC) { idxA++; continue; }
            
            proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': uid, 'notes': funcName, 'function_id': fid ?? ''});
            assignedMembers.add(uid);
            if (cat == 'instrument') assignedInstrumentMembers.add(uid);
            if (cat == 'voice_role') assignedVoiceMembers.add(uid);
            assignedCategoriesByUser.putIfAbsent(uid, () => <String>{}).add(cat);
            assignedFunctionsEvent.putIfAbsent(uid, () => []).add(funcName);
            for (final p in preferredCombos) {
              final a = p['a']!; final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              bool eq(String x, String y) => norm(x) == norm(y);
              if (uid == a && (af == '*' || eq(af, funcName)) && bf != '*' && !eq(bf, funcName)) {
                reservedByFunction.putIfAbsent(bf, () => []).add(b);
                reservedByFunction.putIfAbsent(bf, () => []).add(a);
              } else if (uid == b && (bf == '*' || eq(bf, funcName)) && af != '*' && !eq(af, funcName)) {
                reservedByFunction.putIfAbsent(af, () => []).add(a);
                reservedByFunction.putIfAbsent(af, () => []).add(b);
              }
            }
            idxA++;
            count++;
          }

          if (count < needed && subs.isNotEmpty) {
            final List<String> subsTry = subs
                .where((sid) => membersById.containsKey(sid))
                .where((sid) => !isBlocked(sid))
                .where((sid) => !violatesMonth(sid))
                .where((sid) => !violatesMinDays(sid))
                .where((sid) => !(maxC > 0 && consecutiveFor(sid) >= maxC))
                .toList();
            for (final sid in subsTry) {
              if (count >= needed) break;
              if (assignedMembers.contains(sid)) continue;
              final cats = assignedCategoriesByUser[sid] ?? <String>{};
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) continue;
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) continue;
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) continue;
              if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(sid)) continue;
              if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(sid)) continue;
              if (cat == 'other' && exclusiveOther) continue;
              if (violatesProhibited(sid, funcName)) continue;
              
              await ministriesRepo.addSchedule({
                'event_id': event.id,
                'ministry_id': ministryId,
                'user_id': sid,
                'function_id': fid,
                'notes': funcName,
              });
            
              assignedMembers.add(sid);
              if (cat == 'instrument') assignedInstrumentMembers.add(sid);
              if (cat == 'voice_role') assignedVoiceMembers.add(sid);
              assignedCategoriesByUser.putIfAbsent(sid, () => <String>{}).add(cat);
              assignedFunctionsEvent.putIfAbsent(sid, () => []).add(funcName);
              datesByUserFunc.putIfAbsent(sid, () => []).add(event.startDate);
              count++;
            }
          }

          if (count < needed && subs.isNotEmpty) {
            final List<String> subsTry = subs
                .where((sid) => membersById.containsKey(sid))
                .where((sid) => !isBlocked(sid))
                .where((sid) => !violatesMonth(sid))
                .where((sid) => !violatesMinDays(sid))
                .where((sid) => !(maxC > 0 && consecutiveFor(sid) >= maxC))
                .toList();
            for (final sid in subsTry) {
              if (count >= needed) break;
              if (assignedMembers.contains(sid)) continue;
              final cats = assignedCategoriesByUser[sid] ?? <String>{};
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) continue;
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) continue;
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) continue;
              if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(sid)) continue;
              if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(sid)) continue;
              if (cat == 'other' && exclusiveOther) continue;
              if (isBlocked(sid)) continue;
              if (violatesProhibited(sid, funcName)) continue;
              if (violatesMonth(sid)) continue;
              if (violatesMinDays(sid)) continue;
              if (maxC > 0 && consecutiveFor(sid) >= maxC) continue;
              
              proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': sid, 'notes': funcName, 'function_id': fid ?? ''});
              assignedMembers.add(sid);
              if (cat == 'instrument') assignedInstrumentMembers.add(sid);
              if (cat == 'voice_role') assignedVoiceMembers.add(sid);
              assignedCategoriesByUser.putIfAbsent(sid, () => <String>{}).add(cat);
              assignedFunctionsEvent.putIfAbsent(sid, () => []).add(funcName);
              count++;
            }
          }

          
        }
      }
      return proposals;
    }

    bool allowMultiMinistries = false;
    try {
      final roleRepo = ref.read(roleContextsRepositoryProvider);
      for (final mid in ministryIds) {
        final ctxs = await roleRepo.getContextsByMinistry(mid);
        for (final c in ctxs) {
          final gr = Map<String, dynamic>.from(c.metadata?['schedule_rules']?['general_rules'] ?? {});
          final v = gr['allow_multi_ministries_per_event'];
          final b = v is bool ? v : (v?.toString().toLowerCase() == 'true');
          if (b) { allowMultiMinistries = true; break; }
        }
        if (allowMultiMinistries) break;
      }
    } catch (_) {}

    for (final ministryId in ministryIds) {
      final members = await ministriesRepo.getMinistryMembers(ministryId);
      final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
      final rules = contexts.isNotEmpty ? Map<String, dynamic>.from(contexts.first.metadata?['schedule_rules'] ?? {}) : <String, dynamic>{};
      final maxPerMonth = rules['max_per_month'] as int?;
      final minDaysBetween = rules['min_days_between'] as int?;
      final Map<String, List<DateTime>> datesByUser = {};
      for (final s in existingSchedules) {
        if (s.eventStartDate != null) {
          datesByUser.putIfAbsent(s.memberId, () => []).add(s.eventStartDate!);
        }
      }
      bool violatesMonth(String uid) {
        if (maxPerMonth == null) return false;
        final list = List<DateTime>.from(datesByUser[uid] ?? const []);
        final m = event.startDate.month;
        final y = event.startDate.year;
        final count = list.where((d) => d.month == m && d.year == y).length;
        return count >= maxPerMonth;
      }
      bool violatesMinDays(String uid) {
        if (minDaysBetween == null) return false;
        final list = List<DateTime>.from(datesByUser[uid] ?? const []);
        if (list.isEmpty) return false;
        list.sort((a, b) => a.compareTo(b));
        DateTime? last;
        for (final d in list) {
          if (d.isBefore(event.startDate)) {
            last = d;
          } else {
            break;
          }
        }
        if (last == null) return false;
        final diff = event.startDate.difference(last).inDays;
        return diff < minDaysBetween;
      }
      for (final m in members) {
        if (violatesMonth(m.memberId)) continue;
        if (violatesMinDays(m.memberId)) continue;
        if (globalAssignedMembers.contains(m.memberId)) continue;
        proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': m.memberId, 'notes': 'Presença Geral'});
        globalAssignedMembers.add(m.memberId);
      }
    }
    return proposals;
  }
}
