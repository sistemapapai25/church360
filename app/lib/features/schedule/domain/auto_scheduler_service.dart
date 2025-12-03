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
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);

    // Mapear comportamento por tipo
    final type = event.eventType ?? 'culto_normal';

    if (type == 'reuniao_ministerio' || type == 'reuniao_externa') {
      // Regra: todos os membros ativos como presentes, sem função específica
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': event.isMandatory ? 'Presença obrigatória' : null,
          });
        }
      }
      return;
    }

    if (type == 'lideranca_geral') {
      // Regra: apenas líderes e coordenadores
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members.where((mm) => mm.role.name == 'leader' || mm.role.name == 'coordinator')) {
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Liderança Geral',
          });
        }
      }
      return;
    }

    if (type == 'mutirao') {
      // Regra: pode escalar qualquer pessoa do ministério selecionado
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          await ministriesRepo.addSchedule({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Mutirão/Limpeza',
          });
        }
      }
      return;
    }

    // Culto Normal / Ceia / Ensaio / Vigília ou Evento Conjunto por função
    if (byFunction) {
      String norm(String? s) => (s ?? '').trim().toLowerCase();

      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);

        final Map<String, int> cfg = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = true;
        bool exclusiveVoiceRole = true;
        bool exclusiveOther = true;
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
          maxPerMonth = (gr['max_per_month'] as int?) ?? maxPerMonth;
          maxConsecutive = (gr['max_consecutive'] as int?) ?? maxConsecutive;
          minDaysBetween = (gr['min_days_between'] as int?) ?? minDaysBetween;
          minExperienced = (gr['min_experienced'] as int?) ?? minExperienced;
        }

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
          return m.role.name != 'member';
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
          for (final other in assignedMembers) {
            final funcsOther = List<String>.from(assignedFunctionsEvent[other] ?? const []);
            for (final p in prohibitedCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              if (uid == a && other == b) {
                final aOk = (af == '*' || af == currentFunc);
                final bOk = funcsOther.any((f) => bf == '*' || bf == f);
                if (aOk && bOk) return true;
              }
              if (uid == b && other == a) {
                final bOk = (bf == '*' || bf == currentFunc);
                final aOk = funcsOther.any((f) => af == '*' || af == f);
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

        // Map de sinônimos para casamento de cargo e função
        final Map<String, List<String>> synonyms = const {
          'BACK': ['back', 'back vocal', 'back-vocal', 'backing', 'bv'],
          'GUITARRA': ['guitarra', 'guitar', 'gtr'],
          'VIOLAO': ['violao', 'violão'],
          'BAIXO': ['baixo', 'bass'],
          'BATERIA': ['bateria', 'drums', 'baterista'],
          'TECLADO': ['teclado', 'keyboard', 'keys', 'piano'],
          'SAX': ['sax', 'saxofone', 'saxophone'],
          'TECNICO DE SOM': ['tecnico de som', 'técnico de som', 'audio', 'som', 'mesa'],
          'MINISTRANTE': ['ministrante', 'worship leader', 'leader', 'ministro', 'ministra', 'líder', 'lider', 'líder de louvor', 'lider de louvor', 'wl', 'dirigente'],
        };

        for (final entry in cfg.entries) {
          final funcName = entry.key;
          final needed = entry.value;
          int count = 0;
          final cat = funcCategory[funcName] ?? 'other';
          final Map<String, List<DateTime>> datesByUserFunc = {};
          for (final s in existingSchedules) {
            if (s.eventStartDate != null && (s.notes?.toString() ?? '') == funcName) {
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

          final Map<String, List<String>> partnersForFunc = {};
          for (final p in preferredCombos) {
            final a = p['a']!; final b = p['b']!;
            final af = p['a_func'] ?? '*';
            final bf = p['b_func'] ?? '*';
            final appliesAB = (af == '*' || af == funcName) && (bf == '*' || bf == funcName);
            final appliesBA = (bf == '*' || bf == funcName) && (af == '*' || af == funcName);
            if (appliesAB) partnersForFunc.putIfAbsent(a, () => []).add(b);
            if (appliesBA) partnersForFunc.putIfAbsent(b, () => []).add(a);
            // Afinidade cruzada: se a_func == funcName e b_func != funcName, priorizar b em sua função
            if ((af == '*' || af == funcName) && !(bf == '*' || bf == funcName)) {
              final target = bf;
              final current = List<String>.from(assignedByFunction[target] ?? const []);
              if (!current.contains(b)) {
                assignedByFunction[target] = [b, ...current];
              }
            }
            if ((bf == '*' || bf == funcName) && !(af == '*' || af == funcName)) {
              final target = af;
              final current = List<String>.from(assignedByFunction[target] ?? const []);
              if (!current.contains(a)) {
                assignedByFunction[target] = [a, ...current];
              }
            }
          }

          // Construir candidatos: atribuídos + por cargo + líder/subs
          final String key = norm(funcName);
          final assignedCandidates0 = List<String>.from(assignedByFunction[funcName] ?? const []);
          final Set<String> alias = { key, ...(synonyms[funcName.toUpperCase()] ?? const []).map(norm) };
          final cargoCandidates0 = members
              .where((m) {
                final cn = norm(m.cargoName);
                if (cn.isEmpty) return false;
                return alias.any((a) => cn.contains(a) || a.contains(cn));
              })
              .map((m) => m.memberId)
              .toList();
          final leaderCfg = Map<String, dynamic>.from(leadersByFunction[funcName] ?? {});
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(leaderCfg['subs'] ?? const []).map((e) => e.toString()).toList();
          final seeds = <String>{...assignedCandidates0, ...cargoCandidates0, if (leaderId != null) leaderId, ...subs};
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
            if (assignedMembers.contains(uid)) {
              final cats = assignedCategoriesByUser[uid] ?? <String>{};
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
            await ministriesRepo.addSchedule({
              'event_id': event.id,
              'ministry_id': ministryId,
              'user_id': uid,
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

            if (count < needed) {
              for (final p in prohibitedCombos) {
                final partner = (p['a'] == uid) ? p['b'] : (p['b'] == uid ? p['a'] : null);
                if (partner == null) continue;
                assignedCandidates.removeWhere((x) => x == partner);
              }
              for (final p in prohibitedCombos) {
                final a = p['a']!; final b = p['b']!;
                if (uid == a || uid == b) {
                  final other = uid == a ? b : a;
                  if (assignedCandidates.contains(other)) assignedCandidates.remove(other);
                }
              }
              final prefs = partnersForFunc[uid] ?? const [];
              for (final p in prefs) {
                if (count >= needed) break;
                if (!assignedCandidates.contains(p)) continue;
                if (!membersById.containsKey(p)) continue;
                if (assignedMembers.contains(p)) continue;
                if (isBlocked(p)) continue;
                if (violatesMonth(p)) continue;
                if (violatesMinDays(p)) continue;
                if (maxC > 0 && consecutiveFor(p) >= maxC) continue;
                await ministriesRepo.addSchedule({
                  'event_id': event.id,
                  'ministry_id': ministryId,
                  'user_id': p,
                  'notes': funcName,
                });
                assignedMembers.add(p);
                if (cat == 'instrument') assignedInstrumentMembers.add(p);
                if (cat == 'voice_role') assignedVoiceMembers.add(p);
                assignedCategoriesByUser.putIfAbsent(p, () => <String>{}).add(cat);
                assignedFunctionsEvent.putIfAbsent(p, () => []).add(funcName);
                datesByUserFunc.putIfAbsent(p, () => []).add(event.startDate);
                if (isExperienced(p)) experiencedCount++;
                count++;
                assignedCandidates.removeWhere((x) => x == p);
              }
            }
          }

          // Fallback por cargoName se necessário
          if (count < needed) {
            final String key = norm(funcName);
            int idxCargo = 0;
            final Set<String> alias = { key, ...(synonyms[funcName.toUpperCase()] ?? const []).map(norm) };
            var candidatesWithCargo = members
                .where((m) {
                  final cn = norm(m.cargoName);
                  if (cn.isEmpty) return false;
                  return alias.any((a) => cn.contains(a) || a.contains(cn));
                })
                .where((m) => !isBlocked(m.memberId) && !violatesMonth(m.memberId) && !violatesMinDays(m.memberId))
                .toList();
            candidatesWithCargo.sort((a, b) => prioFor(a.memberId).compareTo(prioFor(b.memberId)));
            while (count < needed && idxCargo < candidatesWithCargo.length) {
              final m = candidatesWithCargo[idxCargo];
              final uid = m.memberId;
              if (assignedMembers.contains(uid)) {
                if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(uid)) { idxCargo++; continue; }
                if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(uid)) { idxCargo++; continue; }
                if (cat == 'other' && exclusiveOther) { idxCargo++; continue; }
              }
              if (violatesProhibited(uid, funcName)) { idxCargo++; continue; }
              if (violatesMonth(uid)) { idxCargo++; continue; }
              if (violatesMinDays(uid)) { idxCargo++; continue; }
              if (maxC > 0 && consecutiveFor(uid) >= maxC) { idxCargo++; continue; }
              await ministriesRepo.addSchedule({
                'event_id': event.id,
                'ministry_id': ministryId,
                'user_id': uid,
                'notes': funcName,
              });
              assignedMembers.add(uid);
              if (cat == 'instrument') assignedInstrumentMembers.add(uid);
              if (cat == 'voice_role') assignedVoiceMembers.add(uid);
              assignedFunctionsEvent.putIfAbsent(uid, () => []).add(funcName);
              datesByUserFunc.putIfAbsent(uid, () => []).add(event.startDate);
              if (isExperienced(uid)) experiencedCount++;
              idxCargo++;
              count++;
              if (count < needed) {
                final prefs = partnersForFunc[uid] ?? const [];
                for (final p in prefs) {
                  if (count >= needed) break;
                  if (!membersById.containsKey(p)) continue;
                  if (assignedMembers.contains(p)) continue;
                  if (isBlocked(p)) continue;
                  if (violatesMonth(p)) continue;
                  if (violatesMinDays(p)) continue;
                  if (maxC > 0 && consecutiveFor(p) >= maxC) continue;
                  await ministriesRepo.addSchedule({
                    'event_id': event.id,
                    'ministry_id': ministryId,
                    'user_id': p,
                    'notes': funcName,
                  });
                  assignedMembers.add(p);
                  if (cat == 'instrument') assignedInstrumentMembers.add(p);
                  if (cat == 'voice_role') assignedVoiceMembers.add(p);
                  assignedFunctionsEvent.putIfAbsent(p, () => []).add(funcName);
                  datesByUserFunc.putIfAbsent(p, () => []).add(event.startDate);
                  if (isExperienced(p)) experiencedCount++;
                  count++;
                }
              }
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
        await ministriesRepo.addSchedule({
          'event_id': event.id,
          'ministry_id': ministryId,
          'user_id': m.memberId,
          'notes': 'Presença Geral',
        });
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
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);
    final proposals = <Map<String, String>>[];

    final type = event.eventType ?? 'culto_normal';

    if (type == 'reuniao_ministerio' || type == 'reuniao_externa') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': event.isMandatory ? 'Presença obrigatória' : '',
          });
        }
      }
      return proposals;
    }

    if (type == 'lideranca_geral') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members.where((mm) => mm.role.name == 'leader' || mm.role.name == 'coordinator')) {
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Liderança Geral',
          });
        }
      }
      return proposals;
    }

    if (type == 'mutirao') {
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        for (final m in members) {
          proposals.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Mutirão/Limpeza',
          });
        }
      }
      return proposals;
    }

    if (byFunction) {
      String norm(String? s) => (s ?? '').trim().toLowerCase();
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(ministryId);

        final Map<String, int> cfg = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = true;
        bool exclusiveVoiceRole = true;
        bool exclusiveOther = true;
        final Map<String, List<String>> assignedByFunction = {};
        final List<Map<String, dynamic>> blocks = [];
        final List<Map<String, String>> prohibitedCombos = [];
        final List<Map<String, String>> preferredCombos = [];
        final Map<String, dynamic> memberPriorities = {};
        final Map<String, dynamic> leadersByFunction = {};
        int? maxPerMonth;
        int? minDaysBetween;

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
          maxPerMonth = (gr['max_per_month'] as int?) ?? maxPerMonth;
          minDaysBetween = (gr['min_days_between'] as int?) ?? minDaysBetween;
        }

        final Set<String> assignedMembers = {};
        final Set<String> assignedInstrumentMembers = {};
        final Set<String> assignedVoiceMembers = {};
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
            for (final p in prohibitedCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              if (uid == a && other == b) {
                final aOk = (af == '*' || af == currentFunc);
                final bOk = (bf == '*' || bf == currentFunc);
                if (aOk && bOk) return true;
              }
              if (uid == b && other == a) {
                final bOk = (bf == '*' || bf == currentFunc);
                final aOk = (af == '*' || af == currentFunc);
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

        // Map de sinônimos para casamento de cargo e função
        final Map<String, List<String>> synonyms = const {
          'BACK': ['back', 'back vocal', 'back-vocal', 'backing', 'bv'],
          'GUITARRA': ['guitarra', 'guitar', 'gtr'],
          'VIOLAO': ['violao', 'violão'],
          'BAIXO': ['baixo', 'bass'],
          'BATERIA': ['bateria', 'drums', 'baterista'],
          'TECLADO': ['teclado', 'keyboard', 'keys', 'piano'],
          'SAX': ['sax', 'saxofone', 'saxophone'],
          'TECNICO DE SOM': ['tecnico de som', 'técnico de som', 'audio', 'som', 'mesa'],
          'MINISTRANTE': ['ministrante', 'worship leader', 'leader', 'ministro', 'ministra', 'líder', 'lider', 'líder de louvor', 'lider de louvor', 'wl', 'dirigente'],
        };

        for (final entry in cfg.entries) {
          final funcName = entry.key;
          final needed = entry.value;
          int count = 0;
          final cat = funcCategory[funcName] ?? 'other';

          final Map<String, List<String>> partnersForFunc = {};
          for (final p in preferredCombos) {
            final a = p['a']!; final b = p['b']!;
            final af = p['a_func'] ?? '*';
            final bf = p['b_func'] ?? '*';
            final appliesAB = (af == '*' || af == funcName) && (bf == '*' || bf == funcName);
            final appliesBA = (bf == '*' || bf == funcName) && (af == '*' || af == funcName);
            if (appliesAB) partnersForFunc.putIfAbsent(a, () => []).add(b);
            if (appliesBA) partnersForFunc.putIfAbsent(b, () => []).add(a);
          }

          final assignedCandidates0 = List<String>.from(assignedByFunction[funcName] ?? const []);
          final Set<String> alias = { norm(funcName), ...(synonyms[funcName.toUpperCase()] ?? const []).map(norm) };
          final cargoCandidates0 = members
              .where((m) {
                final cn = norm(m.cargoName);
                if (cn.isEmpty) return false;
                return alias.any((a) => cn.contains(a) || a.contains(cn));
              })
              .map((m) => m.memberId)
              .toList();
          final leaderCfg = Map<String, dynamic>.from(leadersByFunction[funcName] ?? {});
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(leaderCfg['subs'] ?? const []).map((e) => e.toString()).toList();
          final seeds = <String>{...assignedCandidates0, ...cargoCandidates0, if (leaderId != null) leaderId, ...subs};
          var assignedCandidates = seeds.where((uid) => !isBlocked(uid) && !violatesMonth(uid) && !violatesMinDays(uid)).toList();
          assignedCandidates.sort((a, b) => prioFor(a).compareTo(prioFor(b)));
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
            proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': uid, 'notes': funcName});
            assignedMembers.add(uid);
            if (cat == 'instrument') assignedInstrumentMembers.add(uid);
            if (cat == 'voice_role') assignedVoiceMembers.add(uid);
            assignedCategoriesByUser.putIfAbsent(uid, () => <String>{}).add(cat);
            idxA++;
            count++;
          }

          if (count < needed) {
            final String key = norm(funcName);
            int idxCargo = 0;
            final Set<String> alias = { key, ...(synonyms[funcName.toUpperCase()] ?? const []).map(norm) };
            var candidatesWithCargo = members
                .where((m) {
                  final cn = norm(m.cargoName);
                  if (cn.isEmpty) return false;
                  return alias.any((a) => cn.contains(a) || a.contains(cn));
                })
                .where((m) => !isBlocked(m.memberId) && !violatesMonth(m.memberId) && !violatesMinDays(m.memberId))
                .toList();
            candidatesWithCargo.sort((a, b) => prioFor(a.memberId).compareTo(prioFor(b.memberId)));
            while (count < needed && idxCargo < candidatesWithCargo.length) {
              final m = candidatesWithCargo[idxCargo];
              final uid = m.memberId;
              if (assignedMembers.contains(uid)) {
                final cats = assignedCategoriesByUser[uid] ?? <String>{};
                if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) { idxCargo++; continue; }
                if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat)) { idxCargo++; continue; }
                if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) { idxCargo++; continue; }
                if (cat == 'instrument' && exclusiveInstrument && assignedInstrumentMembers.contains(uid)) { idxCargo++; continue; }
                if (cat == 'voice_role' && exclusiveVoiceRole && assignedVoiceMembers.contains(uid)) { idxCargo++; continue; }
                if (cat == 'other' && exclusiveOther) { idxCargo++; continue; }
              }
              if (violatesProhibited(uid, funcName)) { idxCargo++; continue; }
              if (violatesMonth(uid)) { idxCargo++; continue; }
              if (violatesMinDays(uid)) { idxCargo++; continue; }
              proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': uid, 'notes': funcName});
              assignedMembers.add(uid);
              if (cat == 'instrument') assignedInstrumentMembers.add(uid);
              if (cat == 'voice_role') assignedVoiceMembers.add(uid);
              assignedCategoriesByUser.putIfAbsent(uid, () => <String>{}).add(cat);
              idxCargo++;
              count++;
              if (count < needed) {
                final prefs = partnersForFunc[uid] ?? const [];
                for (final p in prefs) {
                  if (count >= needed) break;
                  if (!membersById.containsKey(p)) continue;
                  if (assignedMembers.contains(p)) continue;
                  if (isBlocked(p)) continue;
                  if (violatesMonth(p)) continue;
                  if (violatesMinDays(p)) continue;
                  proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': p, 'notes': funcName});
                  assignedMembers.add(p);
                  if (cat == 'instrument') assignedInstrumentMembers.add(p);
                  if (cat == 'voice_role') assignedVoiceMembers.add(p);
                  assignedCategoriesByUser.putIfAbsent(p, () => <String>{}).add(cat);
                  count++;
                }
              }
            }
          }
        }
      }
      return proposals;
    }

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
        proposals.add({'event_id': event.id, 'ministry_id': ministryId, 'user_id': m.memberId, 'notes': 'Presença Geral'});
      }
    }
    return proposals;
  }
}
