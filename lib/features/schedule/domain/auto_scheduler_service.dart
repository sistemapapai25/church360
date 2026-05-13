import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../events/domain/models/event.dart';
import '../../ministries/presentation/providers/ministries_provider.dart';
import '../../permissions/providers/permissions_providers.dart';

class AutoSchedulerService {
  /// Gera escalas para um evento específico, aplicando regras por tipo.
  /// Retorna um [EventScheduleReport] descrevendo o resultado por função/ramo
  /// para que a tela possa exibir status (OK / PARCIAL / VAZIO) e motivos.
  ///
  /// Flags de relaxamento (opt-in pela tela). Apenas regras de frequência
  /// podem ser relaxadas — função autorizada, bloqueio, prohibited e
  /// allow_multi_ministries_per_event permanecem duras.
  Future<EventScheduleReport> generateForEvent({
    required WidgetRef ref,
    required Event event,
    required List<String> ministryIds,
    required bool byFunction,
    bool overwriteExisting = false,
    bool throwIfEmpty = false,
    bool relaxMinDays = false,
    bool relaxMaxConsecutive = false,
    bool relaxMaxPerMonth = false,
    bool fairDistribution = false,
    // Lote 5 — quando true (default), líder/suplente entram como BOOST no
    // score (líder +2, suplente +1) por cima da prioridade-por-tipo do membro,
    // em vez de sobrescrever cegamente o topo da lista. Kill-switch interno
    // pra reverter ao comportamento antigo sem deploy se algo der errado.
    bool useLeaderBoostScore = true,
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);

    // Fix #1+#3: relatório por evento.
    final reportSlots = <ScheduleSlotResult>[];
    String? reportGeneralNote;
    EventScheduleReport buildReport() => EventScheduleReport(
          eventId: event.id,
          eventName: event.name,
          eventDate: event.startDate,
          slots: List.unmodifiable(reportSlots),
          generalNote: reportGeneralNote,
        );

    // Mapear comportamento por tipo
    // Fix #15: tratar string vazia / whitespace como ausência de tipo
    // (default = culto_normal). Evita cair no ramo errado quando event_type
    // veio do banco como `''` em vez de `null`.
    final rawType = event.eventType?.trim();
    final type = (rawType == null || rawType.isEmpty) ? 'culto_normal' : rawType;
    final globalSchedules = await ministriesRepo.getEventSchedules(event.id);
    final Set<String> globalAssignedMembers = {
      for (final s in globalSchedules) s.memberId,
    };
    bool allowMultiMinistries = false;
    try {
      final roleRepo = ref.read(roleContextsRepositoryProvider);
      for (final mid in ministryIds) {
        final ctxs = await roleRepo.getContextsByMinistry(mid);
        for (final c in ctxs) {
          final gr = Map<String, dynamic>.from(
            c.metadata?['schedule_rules']?['general_rules'] ?? {},
          );
          final v = gr['allow_multi_ministries_per_event'];
          final b = v is bool ? v : (v?.toString().toLowerCase() == 'true');
          if (b) {
            allowMultiMinistries = true;
            break;
          }
        }
        if (allowMultiMinistries) break;
      }
    } catch (_) {}

    if (type == 'reuniao_ministerio' || type == 'reuniao_externa') {
      int insertedHere = 0;
      // Lote 4: batch insert no ramo de reunião (1 round-trip por evento).
      final List<Map<String, dynamic>> presencaBatch = [];
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(
          ministryId,
        );
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries &&
              globalAssignedMembers.contains(m.memberId))
            continue;
          presencaBatch.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': event.isMandatory ? 'Presença obrigatória' : null,
          });
          globalAssignedMembers.add(m.memberId);
          insertedHere++;
        }
      }
      if (presencaBatch.isNotEmpty) {
        await ministriesRepo.addSchedulesBatch(presencaBatch);
      }
      reportGeneralNote =
          'Reunião: presença registrada para $insertedHere membro(s).';
      return buildReport();
    }

    if (type == 'lideranca_geral') {
      int insertedHere = 0;
      // Lote 4: batch insert no ramo de Liderança Geral.
      final List<Map<String, dynamic>> liderancaBatch = [];
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(
          ministryId,
        );
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members.where(
          (mm) => mm.role.value == 'leader' || mm.role.value == 'coordinator',
        )) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries &&
              globalAssignedMembers.contains(m.memberId))
            continue;
          liderancaBatch.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Liderança Geral',
          });
          globalAssignedMembers.add(m.memberId);
          insertedHere++;
        }
      }
      if (liderancaBatch.isNotEmpty) {
        await ministriesRepo.addSchedulesBatch(liderancaBatch);
      }
      reportGeneralNote =
          'Liderança Geral: $insertedHere líder(es)/coordenador(es) escalados.';
      return buildReport();
    }

    if (type == 'mutirao') {
      int insertedHere = 0;
      // Lote 4: batch insert no ramo de Mutirão.
      final List<Map<String, dynamic>> mutiraoBatch = [];
      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(
          ministryId,
        );
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        for (final m in members) {
          if (existingForEvent.contains(m.memberId)) continue;
          if (!allowMultiMinistries &&
              globalAssignedMembers.contains(m.memberId))
            continue;
          mutiraoBatch.add({
            'event_id': event.id,
            'ministry_id': ministryId,
            'user_id': m.memberId,
            'notes': 'Mutirão/Limpeza',
          });
          globalAssignedMembers.add(m.memberId);
          insertedHere++;
        }
      }
      if (mutiraoBatch.isNotEmpty) {
        await ministriesRepo.addSchedulesBatch(mutiraoBatch);
      }
      reportGeneralNote =
          'Mutirão: $insertedHere membro(s) escalado(s).';
      return buildReport();
    }

    // Culto Normal / Ceia / Ensaio / Vigília ou Evento Conjunto por função
    if (byFunction) {
      final catalog = await ministriesRepo.getFunctionsCatalog();
      String norm(String s) {
        final t = s.trim().toLowerCase();
        const repl = {
          'á': 'a',
          'à': 'a',
          'â': 'a',
          'ã': 'a',
          'ä': 'a',
          'é': 'e',
          'ê': 'e',
          'ë': 'e',
          'í': 'i',
          'ï': 'i',
          'ó': 'o',
          'ô': 'o',
          'õ': 'o',
          'ö': 'o',
          'ú': 'u',
          'ü': 'u',
          'ç': 'c',
        };
        final buf = StringBuffer();
        for (final ch in t.runes) {
          final c = String.fromCharCode(ch);
          buf.write(repl[c] ?? c);
        }
        return buf
            .toString()
            .replaceAll(RegExp(r'[_-]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
      int dayDiff(DateTime a, DateTime b) =>
          dayKey(a).difference(dayKey(b)).inDays;
      final Map<String, String> nameToId = {
        for (final e in catalog)
          (e['name'] ?? '').toString().trim(): (e['id'] ?? '')
              .toString()
              .trim(),
      };
      final Map<String, String> normNameToId = {
        for (final e in catalog)
          norm((e['name'] ?? '').toString()): (e['id'] ?? '').toString().trim(),
      };
      String? fidForFunc(String funcName) {
        final key = funcName.trim();
        return nameToId[key] ?? normNameToId[norm(key)];
      }

      int inserted = 0;
      final diag = <String>[];
      // Lote 3 (#14): acumular inserções por ministério e fazer 1 batch ao
      // final. Mantém o estado em memória (assignedMembers, datesByUser…)
      // sincronizado por candidato, mas trocando N round-trips por 1.
      final List<Map<String, dynamic>> pendingInserts = [];
      for (final ministryId in ministryIds) {
        if (overwriteExisting) {
          await ministriesRepo.clearSchedulesForEventMinistry(
            event.id,
            ministryId,
          );
        }
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref
            .read(roleContextsRepositoryProvider)
            .getContextsByMinistry(ministryId);
        final existingSchedules = await ministriesRepo.getMinistrySchedules(
          ministryId,
        );

        final Map<String, int> cfg = {};
        final Set<String> funcsFromMeta = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = false;
        bool exclusiveVoiceRole = false;
        bool exclusiveOther = false;
        final Map<String, List<String>> assignedByFunction = {};
        final Map<String, List<String>> assignedByFunctionFromMeta = {};
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
          for (final f in List<dynamic>.from(meta['functions'] ?? const [])) {
            final canon = norm(f.toString());
            if (canon.isNotEmpty) funcsFromMeta.add(canon);
          }
          final eventReq = meta['event_function_requirements'];
          if (eventReq is Map) {
            final Map<String, dynamic> reqForType = Map<String, dynamic>.from(
              eventReq[type] ?? {},
            );
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
          final catMap = Map<String, dynamic>.from(
            meta['function_category_by_function'] ?? {},
          );
          catMap.forEach(
            (k, v) => funcCategory[norm(k.toString())] = v.toString(),
          );
          final restrictions = Map<String, dynamic>.from(
            meta['category_restrictions'] ?? {},
          );
          exclusiveInstrument =
              (restrictions['instrument']?['exclusive'] as bool?) ??
              exclusiveInstrument;
          exclusiveVoiceRole =
              (restrictions['voice_role']?['exclusive'] as bool?) ??
              exclusiveVoiceRole;
          exclusiveOther =
              (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          exclusiveOther =
              (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          final assigned = Map<String, dynamic>.from(
            meta['assigned_functions'] ?? {},
          );
          assigned.forEach((userId, funcs) {
            for (final f in List<dynamic>.from(funcs ?? const [])) {
              final name = norm(f.toString());
              assignedByFunctionFromMeta.putIfAbsent(name, () => []);
              final uid = userId.toString();
              if (!assignedByFunctionFromMeta[name]!.contains(uid)) {
                assignedByFunctionFromMeta[name]!.add(uid);
              }
            }
          });
          final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
          final bl = List<dynamic>.from(rules['blocks'] ?? const []);
          for (final b in bl) {
            if (b is Map) blocks.add(Map<String, dynamic>.from(b));
          }
          final pc = List<dynamic>.from(
            rules['prohibited_combinations'] ?? const [],
          );
          for (final p in pc) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty)
                prohibitedCombos.add({
                  'a': a,
                  'b': b,
                  'a_func': af,
                  'b_func': bf,
                });
            }
          }
          final pr = List<dynamic>.from(
            rules['preferred_combinations'] ?? const [],
          );
          for (final p in pr) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty)
                preferredCombos.add({
                  'a': a,
                  'b': b,
                  'a_func': af,
                  'b_func': bf,
                });
            }
          }
          final mp = Map<String, dynamic>.from(
            rules['member_priorities'] ?? {},
          );
          mp.forEach((k, v) => memberPriorities[k] = v);
          final lf = Map<String, dynamic>.from(
            rules['leaders_by_function'] ?? {},
          );
          lf.forEach((k, v) => leadersByFunction[norm(k.toString())] = v);
          final gr = Map<String, dynamic>.from(rules['general_rules'] ?? {});
          int? pInt(dynamic v) =>
              v is int ? v : int.tryParse(v?.toString() ?? '');
          maxPerMonth = pInt(gr['max_per_month']) ?? maxPerMonth;
          maxConsecutive = pInt(gr['max_consecutive']) ?? maxConsecutive;
          minDaysBetween = pInt(gr['min_days_between']) ?? minDaysBetween;
          minExperienced = pInt(gr['min_experienced']) ?? minExperienced;
        }

        if (cfg.isEmpty) {
          final fallback = <String>{
            ...funcsFromMeta,
            ...funcCategory.keys,
            ...leadersByFunction.keys,
            ...assignedByFunctionFromMeta.keys,
          };
          for (final f in fallback) {
            if (f.isNotEmpty) cfg[f] = 1;
          }
        }

        // Completar candidatos por função com vínculos do banco (member_function)
        Map<String, List<String>> mfMap = {};
        try {
          mfMap = await ministriesRepo.getMemberFunctionsByMinistry(ministryId);
        } catch (_) {}

        // Candidatos por função:
        // - `member_function` é fonte de verdade *por usuário* quando existir (evita puxar quem foi desvinculado).
        // - Para usuários sem vínculo em `member_function`, usamos `assigned_functions` do metadata como fallback.
        assignedByFunction.clear();
        final Map<String, Set<String>> linkedCanonByUser = {};
        if (mfMap.isNotEmpty) {
          for (final entry in mfMap.entries) {
            final uid = entry.key;
            for (final f in entry.value) {
              final fn = norm(f);
              if (fn.isEmpty) continue;
              linkedCanonByUser.putIfAbsent(uid, () => <String>{}).add(fn);
              assignedByFunction.putIfAbsent(fn, () => []);
              if (!assignedByFunction[fn]!.contains(uid)) {
                assignedByFunction[fn]!.add(uid);
              }
            }
          }
        }
        if (mfMap.isEmpty) {
          assignedByFunction.addAll({
            for (final entry in assignedByFunctionFromMeta.entries)
              entry.key: entry.value.toSet().toList(),
          });
        } else {
          final linkedUsers = linkedCanonByUser.keys.toSet();
          for (final entry in assignedByFunctionFromMeta.entries) {
            final fn = entry.key;
            for (final uid in entry.value) {
              if (uid.isEmpty) continue;
              if (linkedUsers.contains(uid)) {
                // Se o usuário tem vínculos no banco, o metadata não pode "reintroduzir" funções.
                final linked = linkedCanonByUser[uid] ?? const <String>{};
                if (!linked.contains(fn)) continue;
              }
              assignedByFunction.putIfAbsent(fn, () => []);
              if (!assignedByFunction[fn]!.contains(uid)) {
                assignedByFunction[fn]!.add(uid);
              }
            }
          }
        }
        assignedByFunction.removeWhere((_, v) => v.isEmpty);

        final diagLine =
            'ministry=$ministryId ctx=${contexts.length} type=$type cfg=${cfg.length} metaFuncs=${funcsFromMeta.length} funcCat=${funcCategory.length} leaders=${leadersByFunction.length} mfUsers=${mfMap.length} assignedByFunc=${assignedByFunction.length} maxC=${maxConsecutive ?? '-'} minDays=${minDaysBetween ?? '-'} maxPerMonth=${maxPerMonth ?? '-'}';
        diag.add(diagLine);
        debugPrint('AutoScheduler.generateForEvent(byFunction): $diagLine');

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
        final Map<String, Set<String>> assignedCategoriesByUser = {};
        final Map<String, dynamic> membersById = {
          for (final m in members) m.memberId: m,
        };
        final Map<String, Set<String>> seenEventIdsByUser = {};
        final Map<String, List<DateTime>> datesByUser = {};
        for (final s in existingSchedules) {
          if (s.eventStartDate != null) {
            seenEventIdsByUser.putIfAbsent(s.memberId, () => <String>{});
            if (seenEventIdsByUser[s.memberId]!.add(s.eventId)) {
              datesByUser
                  .putIfAbsent(s.memberId, () => [])
                  .add(s.eventStartDate!);
            }
          }
        }
        final existingForEvent = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => s.memberId)
            .toSet();
        // Fix #8: quando `functionId` for null/vazio, normalizar a chave
        // pelo NOME canônico da função. Antes a chave virava `uid|` para
        // qualquer função fora do catálogo, colidindo entre funções
        // diferentes e fazendo o gerador pular candidatos válidos.
        String funcKey(String? fidArg, String? nameArg) {
          if (fidArg != null && fidArg.isNotEmpty) return 'id:$fidArg';
          return 'name:${norm(nameArg ?? '')}';
        }
        final existingByFuncId = existingSchedules
            .where((s) => s.eventId == event.id)
            .map((s) => '${s.memberId}|${funcKey(s.functionId, s.functionName)}')
            .toSet();
        assignedMembers.addAll(existingForEvent);
        final Set<String> exclusiveWithinCats = {};
        final Set<String> exclusiveAloneCats = {};
        {
          // Agregar exclusividades de todos os contexts
          final allContexts = contexts;
          for (final c in allContexts) {
            final meta = c.metadata ?? {};
            final restrictions = Map<String, dynamic>.from(
              meta['category_restrictions'] ?? {},
            );
            restrictions.forEach((k, v) {
              if (v is Map) {
                if ((v['exclusive'] as bool?) == true)
                  exclusiveWithinCats.add(k.toString());
                if ((v['alone'] as bool?) == true)
                  exclusiveAloneCats.add(k.toString());
              }
            });
          }
        }

        // Princípio 1 (relaxamento opt-in): versões `*Strict` ignoram flags
        // de relaxamento; as versões "aplicadas" respeitam os flags da
        // chamada. Isso permite registrar no relatório quando alguém foi
        // escalado contornando uma regra de frequência.
        bool violatesMonthStrict(String uid) {
          if (maxPerMonth == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          final m = event.startDate.month;
          final y = event.startDate.year;
          final count = list.where((d) => d.month == m && d.year == y).length;
          return count >= maxPerMonth;
        }

        bool violatesMonth(String uid) =>
            relaxMaxPerMonth ? false : violatesMonthStrict(uid);

        // Lote 4 / B1: bidirecional. Checa TODAS as datas do membro — passadas
        // E futuras — dentro da janela `min_days_between`. Antes ignorava
        // datas futuras, então pré-existência manual em D+3 não bloqueava
        // escalar o membro em D quando min_days=7.
        bool violatesMinDaysStrict(String uid) {
          if (minDaysBetween == null) return false;
          final list = datesByUser[uid] ?? const <DateTime>[];
          if (list.isEmpty) return false;
          for (final d in list) {
            if (dayDiff(event.startDate, d).abs() < minDaysBetween) return true;
          }
          return false;
        }

        bool violatesMinDays(String uid) =>
            relaxMinDays ? false : violatesMinDaysStrict(uid);

        int consecutiveGlobalFor(String uid) {
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          if (list.isEmpty) return 0;
          list.sort((a, b) => a.compareTo(b));
          final prevs = list.where((d) => d.isBefore(event.startDate)).toList();
          if (prevs.isEmpty) return 0;
          // Se o último serviço não for "consecutivo" ao evento atual, zera o streak.
          // Isso evita bloquear para sempre quando `max_consecutive` é baixo (ex.: 1).
          final diffToCurrent = dayDiff(event.startDate, prevs.last).abs();
          if (diffToCurrent > 9) return 0;
          int streak = 1;
          DateTime last = prevs.last;
          for (int i = prevs.length - 2; i >= 0; i--) {
            final d = prevs[i];
            final diff = dayDiff(last, d).abs();
            if (diff <= 9) {
              streak++;
              last = d;
            } else {
              break;
            }
          }
          return streak;
        }

        bool violatesConsecutiveStrict(String uid) {
          final mc = maxConsecutive ?? 0;
          if (mc <= 0) return false;
          return consecutiveGlobalFor(uid) >= mc;
        }

        bool violatesConsecutive(String uid) =>
            relaxMaxConsecutive ? false : violatesConsecutiveStrict(uid);

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
              if (sd != null &&
                  sd.year == d.year &&
                  sd.month == d.month &&
                  sd.day == d.day)
                return true;
            } else {
              if (sd != null && ed != null && !d.isBefore(sd) && !d.isAfter(ed))
                return true;
              if (sd != null && ed == null && !d.isBefore(sd)) return true;
              if (sd == null && ed != null && !d.isAfter(ed)) return true;
            }
          }
          return false;
        }

        bool violatesProhibited(String uid, String currentFunc) {
          bool eq(String x, String y) => norm(x) == norm(y);
          for (final other in assignedMembers) {
            final funcsOther = List<String>.from(
              assignedFunctionsEvent[other] ?? const [],
            );
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

        final List<MapEntry<String, int>> orderedCfg = () {
          final order = <String>[];
          final metaOrder = contexts
              .map(
                (c) =>
                    (c.metadata?['category_order'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const <String>[],
              )
              .firstWhere((l) => l.isNotEmpty, orElse: () => const <String>[]);
          if (metaOrder.isNotEmpty) {
            order.addAll(metaOrder);
          } else {
            order.addAll(['voice_role', 'instrument', 'other']);
          }
          int catRank(String f) {
            final cat = funcCategory[f] ?? 'other';
            final idx = order.indexOf(cat);
            return idx >= 0 ? idx : order.length;
          }

          final list = cfg.entries.toList();
          list.sort((a, b) {
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
            final matchByName =
                fid == null && (norm((s.functionName ?? '')) == norm(funcName));
            if (s.eventStartDate != null && (matchById || matchByName)) {
              datesByUserFunc
                  .putIfAbsent(s.memberId, () => [])
                  .add(s.eventStartDate!);
            }
          }
          int consecutiveFor(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            if (list.isEmpty) return 0;
            list.sort((a, b) => a.compareTo(b));
            // percorre de trás pra frente até antes do evento atual
            final prevs = list
                .where((d) => d.isBefore(event.startDate))
                .toList();
            if (prevs.isEmpty) return 0;
            int streak = 1;
            DateTime last = prevs.last;
            for (int i = prevs.length - 2; i >= 0; i--) {
              final d = prevs[i];
              final diff = dayDiff(last, d).abs();
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
          final assignedCandidates0 = List<String>.from(
            assignedByFunction[funcName] ?? const [],
          );
          final leaderCfg = Map<String, dynamic>.from(
            leadersByFunction[funcName] ?? {},
          );
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(
            leaderCfg['subs'] ?? const [],
          ).map((e) => e.toString()).toList();
          final seeds = <String>{
            ...assignedCandidates0,
            if (leaderId != null) leaderId,
            ...subs,
          };
          var assignedCandidates = seeds
              .where(
                (uid) =>
                    !isBlocked(uid) &&
                    !violatesMonth(uid) &&
                    !violatesMinDays(uid),
              )
              .toList();
          final maxC = maxConsecutive ?? 0;
          if (maxC > 0) {
            final allowed = assignedCandidates
                .where((uid) => consecutiveGlobalFor(uid) < maxC)
                .toList();
            final overflow = assignedCandidates
                .where((uid) => consecutiveGlobalFor(uid) >= maxC)
                .toList();
            assignedCandidates = [...allowed, ...overflow];
          }
          int scheduledCountMonth(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            final m = event.startDate.month;
            final y = event.startDate.year;
            return list.where((d) => d.month == m && d.year == y).length;
          }

          // Princípio 2 (distribuição justa): quando `fairDistribution=true`,
          // ordena prioritariamente por contagem total de escalações já feitas
          // (menos escalado primeiro) e usa a prioridade do membro apenas
          // como desempate. Evita que os candidatos prio-5 sejam drenados
          // pelos primeiros eventos do range.
          int scheduledCountTotal(String uid) =>
              (datesByUser[uid] ?? const []).length;
          // Lote 5: score = prioFor(uid, eventType) + boost(líder=+2,
          // suplente=+1). Quando useLeaderBoostScore=false, boost zera e o
          // bloco legado mais abaixo empurra líder/subs pro topo da lista.
          int boostFor(String uid) {
            if (!useLeaderBoostScore) return 0;
            if (leaderId != null &&
                leaderId.isNotEmpty &&
                uid == leaderId) {
              return 2;
            }
            if (subs.contains(uid)) return 1;
            return 0;
          }
          int scoreFor(String uid) => prioFor(uid) + boostFor(uid);
          assignedCandidates.sort((a, b) {
            if ((minExperienced ?? 0) > experiencedCount) {
              final ea = isExperienced(a);
              final eb = isExperienced(b);
              if (ea != eb) return ea ? -1 : 1;
            }
            final sa = scoreFor(a);
            final sb = scoreFor(b);
            if (fairDistribution) {
              final ca = scheduledCountTotal(a);
              final cb = scheduledCountTotal(b);
              if (ca != cb) return ca.compareTo(cb); // menos usado primeiro
              return sb.compareTo(sa); // empate → score DESC
            }
            // Score: prioridade-por-tipo (1-5) + boost de líder/suplente.
            final cmp = sb.compareTo(sa);
            if (cmp != 0) return cmp;
            return scheduledCountMonth(a).compareTo(scheduledCountMonth(b));
          });
          final reserved = List<String>.from(
            reservedByFunction[funcName] ?? const <String>[],
          ).where((uid) => assignedCandidates.contains(uid)).toList();
          for (int i = reserved.length - 1; i >= 0; i--) {
            final r = reserved[i];
            assignedCandidates.remove(r);
            assignedCandidates.insert(0, r);
          }
          if (!useLeaderBoostScore) {
            // Comportamento legado: empurra líder/subs pro topo da lista
            // independente da prioridade. Mantido como fallback do
            // kill-switch.
            var insertPos = 0;
            if (leaderId != null &&
                leaderId.isNotEmpty &&
                assignedCandidates.contains(leaderId)) {
              assignedCandidates.remove(leaderId);
              assignedCandidates.insert(insertPos, leaderId);
              insertPos++;
            }
            for (final sid in subs) {
              if (sid.isEmpty) continue;
              if (leaderId != null && sid == leaderId) continue;
              if (assignedCandidates.contains(sid)) {
                assignedCandidates.remove(sid);
                assignedCandidates.insert(insertPos, sid);
                insertPos++;
              }
            }
          }
          // Princípio 1: registrar quais regras foram efetivamente relaxadas
          // para preencher esta função (vai pro relatório como aviso).
          final Set<String> slotRelaxedRules = {};
          int idxA = 0;
          while (count < needed && idxA < assignedCandidates.length) {
            final uid = assignedCandidates[idxA];
            if (!membersById.containsKey(uid)) {
              idxA++;
              continue;
            }
            // Não reservar candidatos únicos: seguir prioridade e regras.
            if (assignedMembers.contains(uid)) {
              final cats = assignedCategoriesByUser[uid] ?? <String>{};
              final allowedCats =
                  allowedCategoriesByUser[uid] ?? const <String>{};
              if (allowedCats.length == 1) {
                final onlyCat = allowedCats.first;
                if (cats.contains(onlyCat) && cat != onlyCat) {
                  idxA++;
                  continue;
                }
              }
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) {
                idxA++;
                continue;
              }
              if (exclusiveAloneCats.contains(cat) &&
                  cats.any((c) => c != cat)) {
                idxA++;
                continue;
              }
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) {
                idxA++;
                continue;
              }
              if (cat == 'instrument' &&
                  exclusiveInstrument &&
                  assignedInstrumentMembers.contains(uid)) {
                idxA++;
                continue;
              }
              if (cat == 'voice_role' &&
                  exclusiveVoiceRole &&
                  assignedVoiceMembers.contains(uid)) {
                idxA++;
                continue;
              }
              if (cat == 'other' && exclusiveOther) {
                idxA++;
                continue;
              }
            }
            if (isBlocked(uid)) {
              idxA++;
              continue;
            }
            if (violatesProhibited(uid, funcName)) {
              idxA++;
              continue;
            }
            if (violatesMonth(uid)) {
              idxA++;
              continue;
            }
            if (violatesMinDays(uid)) {
              idxA++;
              continue;
            }
            if (violatesConsecutive(uid)) {
              idxA++;
              continue;
            }
            // Fix #11: regra dura — quando allow_multi_ministries_per_event
            // = false, ninguém pode aparecer em 2 ministérios no mesmo evento.
            // Esta regra não pode ser relaxada.
            if (!allowMultiMinistries && globalAssignedMembers.contains(uid)) {
              idxA++;
              continue;
            }

            final keyById = '$uid|${funcKey(fid, funcName)}';
            if (existingByFuncId.contains(keyById)) {
              idxA++;
              continue;
            }
            // Princípio 1: registrar quais regras de frequência foram
            // contornadas para escalar este candidato.
            if (relaxMinDays && violatesMinDaysStrict(uid)) {
              slotRelaxedRules.add('min_days_between');
            }
            if (relaxMaxConsecutive && violatesConsecutiveStrict(uid)) {
              slotRelaxedRules.add('max_consecutive');
            }
            if (relaxMaxPerMonth && violatesMonthStrict(uid)) {
              slotRelaxedRules.add('max_per_month');
            }
            pendingInserts.add({
              'event_id': event.id,
              'ministry_id': ministryId,
              'user_id': uid,
              'function_id': fid,
              'notes': funcName,
            });
            inserted++;
            assignedMembers.add(uid);
            globalAssignedMembers.add(uid); // Fix #11
            if (cat == 'instrument') assignedInstrumentMembers.add(uid);
            if (cat == 'voice_role') assignedVoiceMembers.add(uid);
            assignedCategoriesByUser
                .putIfAbsent(uid, () => <String>{})
                .add(cat);
            assignedFunctionsEvent.putIfAbsent(uid, () => []).add(funcName);
            datesByUserFunc.putIfAbsent(uid, () => []).add(event.startDate);
            seenEventIdsByUser.putIfAbsent(uid, () => <String>{});
            if (seenEventIdsByUser[uid]!.add(event.id)) {
              datesByUser.putIfAbsent(uid, () => []).add(event.startDate);
            }
            if (isExperienced(uid)) experiencedCount++;
            idxA++;
            count++;

            // Após alocar uid em funcName, reservar preferências cruzadas para outras funções
            for (final p in preferredCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              bool eq(String x, String y) => norm(x) == norm(y);
              if (uid == a &&
                  (af == '*' || eq(af, funcName)) &&
                  bf != '*' &&
                  !eq(bf, funcName)) {
                reservedByFunction.putIfAbsent(bf, () => []).add(b);
                // Preferência do próprio usuário na função alvo, se possível
                reservedByFunction.putIfAbsent(bf, () => []).add(a);
              } else if (uid == b &&
                  (bf == '*' || eq(bf, funcName)) &&
                  af != '*' &&
                  !eq(af, funcName)) {
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
                if (uid == a &&
                    (af == '*' || eq(af, funcName)) &&
                    (bf == '*' || eq(bf, funcName))) {
                  assignedCandidates.removeWhere((x) => x == b);
                } else if (uid == b &&
                    (bf == '*' || eq(bf, funcName)) &&
                    (af == '*' || eq(af, funcName))) {
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
                .where((sid) => !violatesConsecutive(sid))
                .toList();
            for (final sid in subsTry) {
              if (count >= needed) break;
              if (assignedMembers.contains(sid)) continue;
              final cats = assignedCategoriesByUser[sid] ?? <String>{};
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat))
                continue;
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat))
                continue;
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat))
                continue;
              if (cat == 'instrument' &&
                  exclusiveInstrument &&
                  assignedInstrumentMembers.contains(sid))
                continue;
              if (cat == 'voice_role' &&
                  exclusiveVoiceRole &&
                  assignedVoiceMembers.contains(sid))
                continue;
              if (cat == 'other' && exclusiveOther) continue;
              if (violatesProhibited(sid, funcName)) continue;
              // Fix #11: regra dura multi-ministério (não relaxável).
              if (!allowMultiMinistries && globalAssignedMembers.contains(sid))
                continue;
              final keyById = '$sid|${funcKey(fid, funcName)}';
              if (existingByFuncId.contains(keyById)) continue;
              // Princípio 1: registrar regras relaxadas para o substituto.
              if (relaxMinDays && violatesMinDaysStrict(sid)) {
                slotRelaxedRules.add('min_days_between');
              }
              if (relaxMaxConsecutive && violatesConsecutiveStrict(sid)) {
                slotRelaxedRules.add('max_consecutive');
              }
              if (relaxMaxPerMonth && violatesMonthStrict(sid)) {
                slotRelaxedRules.add('max_per_month');
              }
              pendingInserts.add({
                'event_id': event.id,
                'ministry_id': ministryId,
                'user_id': sid,
                'function_id': fid,
                'notes': funcName,
              });
              inserted++;
              assignedMembers.add(sid);
              globalAssignedMembers.add(sid); // Fix #11
              if (cat == 'instrument') assignedInstrumentMembers.add(sid);
              if (cat == 'voice_role') assignedVoiceMembers.add(sid);
              assignedCategoriesByUser
                  .putIfAbsent(sid, () => <String>{})
                  .add(cat);
              assignedFunctionsEvent.putIfAbsent(sid, () => []).add(funcName);
              datesByUserFunc.putIfAbsent(sid, () => []).add(event.startDate);
              seenEventIdsByUser.putIfAbsent(sid, () => <String>{});
              if (seenEventIdsByUser[sid]!.add(event.id)) {
                datesByUser.putIfAbsent(sid, () => []).add(event.startDate);
              }
              if (isExperienced(sid)) experiencedCount++;
              count++;
            }
          }

          // Fix #1+#3: registrar resultado desta função no relatório.
          final seedsCount = seeds.length;
          String slotReason = '';
          if (count < needed) {
            final missing = needed - count;
            if (seedsCount == 0) {
              slotReason =
                  'Sem ministros autorizados para esta função (vincule via member_function ou assigned_functions).';
            } else if (count == 0) {
              slotReason =
                  '$seedsCount candidato(s) disponíveis, mas nenhum pôde ser escalado nesta data — regras de frequência (min_days_between/max_consecutive/max_per_month), bloqueios ou multi-ministério bloquearam todos.';
            } else {
              slotReason =
                  'Preenchidas $count de $needed vagas. Faltam $missing — pool drenado por regras de frequência/conflito.';
            }
          }
          if (slotRelaxedRules.isNotEmpty) {
            final relaxedTxt =
                'Regras relaxadas para fechar este slot: ${slotRelaxedRules.join(", ")}.';
            slotReason = slotReason.isEmpty
                ? relaxedTxt
                : '$slotReason  $relaxedTxt';
          }
          reportSlots.add(ScheduleSlotResult(
            ministryId: ministryId,
            funcName: funcName,
            expected: needed,
            inserted: count,
            reason: slotReason,
            relaxedRules: Set<String>.from(slotRelaxedRules),
          ));
        }

        // Ministério sem nenhuma função configurada — registrar como pendência.
        if (orderedCfg.isEmpty) {
          reportSlots.add(ScheduleSlotResult(
            ministryId: ministryId,
            funcName: '(sem funções configuradas)',
            expected: 0,
            inserted: 0,
            reason:
                'Ministério sem function_requirements ou event_function_requirements no contexto.',
          ));
        }
      }
      // Lote 3 (#14): flush em batch — 1 round-trip por evento+byFunction.
      // Se o banco falhar, NADA é inserido (Postgres já cobre atomicidade
      // de um único INSERT com múltiplas linhas). Erro propaga e a tela
      // grava `failures` no relatório.
      if (pendingInserts.isNotEmpty) {
        await ministriesRepo.addSchedulesBatch(pendingInserts);
      }
      if (inserted == 0) {
        final message =
            'Nenhuma escala foi gerada: 0 candidatos aplicáveis. '
            'Verifique vínculos de função no ministério (member_function), líderes/suplentes e regras (máx. cultos seguidos, dias mínimos, bloqueios). '
            'Diagnóstico: ${diag.join(' | ')}';
        debugPrint('AutoScheduler.generateForEvent: $message');
        if (throwIfEmpty) {
          throw Exception(message);
        }
      }
      return buildReport();
    }

    // Evento conjunto apenas presença
    int presencaInserted = 0;
    // Lote 4: batch insert no ramo de presença do evento conjunto.
    final List<Map<String, dynamic>> eventoConjuntoBatch = [];
    for (final ministryId in ministryIds) {
      final members = await ministriesRepo.getMinistryMembers(ministryId);
      final existingSchedules = await ministriesRepo.getMinistrySchedules(
        ministryId,
      );
      final contexts = await ref
          .read(roleContextsRepositoryProvider)
          .getContextsByMinistry(ministryId);
      final rules = contexts.isNotEmpty
          ? Map<String, dynamic>.from(
              contexts.first.metadata?['schedule_rules'] ?? {},
            )
          : <String, dynamic>{};
      // Fix #5+#6: ler `general_rules` (não a raiz de `schedule_rules`) com
      // cast tolerante (int/double/string) para não abortar quando vier `4.0`
      // ou string numérica.
      final generalRules = Map<String, dynamic>.from(
        rules['general_rules'] ?? const {},
      );
      int? pIntRule(dynamic v) =>
          v is int ? v : int.tryParse(v?.toString() ?? '');
      final maxPerMonth = pIntRule(generalRules['max_per_month']);
      final minDaysBetween = pIntRule(generalRules['min_days_between']);
      DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
      int dayDiff(DateTime a, DateTime b) =>
          dayKey(a).difference(dayKey(b)).inDays;
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

      // Lote 4 / B1: bidirecional. Ramo de presença do evento conjunto (real).
      bool violatesMinDays(String uid) {
        if (minDaysBetween == null) return false;
        final list = datesByUser[uid] ?? const <DateTime>[];
        if (list.isEmpty) return false;
        for (final d in list) {
          if (dayDiff(event.startDate, d).abs() < minDaysBetween) return true;
        }
        return false;
      }

      for (final m in members) {
        if (violatesMonth(m.memberId)) continue;
        if (violatesMinDays(m.memberId)) continue;
        if (globalAssignedMembers.contains(m.memberId)) continue;
        eventoConjuntoBatch.add({
          'event_id': event.id,
          'ministry_id': ministryId,
          'user_id': m.memberId,
          'notes': 'Presença Geral',
        });
        globalAssignedMembers.add(m.memberId);
        presencaInserted++;
      }
    }
    if (eventoConjuntoBatch.isNotEmpty) {
      await ministriesRepo.addSchedulesBatch(eventoConjuntoBatch);
    }
    reportGeneralNote =
        'Evento conjunto: presença registrada para $presencaInserted membro(s).';
    return buildReport();
  }

  /// Gera uma proposta de escala sem persistir no banco
  /// Retorna uma lista de mapas: { 'event_id', 'ministry_id', 'user_id', 'notes' }
  Future<List<Map<String, String>>> generateProposalForEvent({
    required WidgetRef ref,
    required Event event,
    required List<String> ministryIds,
    required bool byFunction,
    bool overwriteExisting = false,
    // Mesmos flags de generateForEvent — preview reflete o que a geração
    // real vai produzir quando a tela passa estes valores.
    bool relaxMinDays = false,
    bool relaxMaxConsecutive = false,
    bool relaxMaxPerMonth = false,
    bool fairDistribution = false,
    bool useLeaderBoostScore = true,
  }) async {
    final ministriesRepo = ref.read(ministriesRepositoryProvider);
    final proposals = <Map<String, String>>[];

    // Fix #15: tratar string vazia / whitespace como ausência de tipo
    // (default = culto_normal). Evita cair no ramo errado quando event_type
    // veio do banco como `''` em vez de `null`.
    final rawType = event.eventType?.trim();
    final type = (rawType == null || rawType.isEmpty) ? 'culto_normal' : rawType;
    final globalSchedules = await ministriesRepo.getEventSchedules(event.id);
    final Set<String> globalAssignedMembers = {
      for (final s in globalSchedules) s.memberId,
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
        for (final m in members.where(
          (mm) => mm.role.value == 'leader' || mm.role.value == 'coordinator',
        )) {
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
          'á': 'a',
          'à': 'a',
          'â': 'a',
          'ã': 'a',
          'ä': 'a',
          'é': 'e',
          'ê': 'e',
          'ë': 'e',
          'í': 'i',
          'ï': 'i',
          'ó': 'o',
          'ô': 'o',
          'õ': 'o',
          'ö': 'o',
          'ú': 'u',
          'ü': 'u',
          'ç': 'c',
        };
        final buf = StringBuffer();
        for (final ch in t.runes) {
          final c = String.fromCharCode(ch);
          buf.write(repl[c] ?? c);
        }
        return buf
            .toString()
            .replaceAll(RegExp(r'[_-]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
      int dayDiff(DateTime a, DateTime b) =>
          dayKey(a).difference(dayKey(b)).inDays;
      final Map<String, String> nameToId = {
        for (final e in catalog)
          (e['name'] ?? '').toString().trim(): (e['id'] ?? '')
              .toString()
              .trim(),
      };
      final Map<String, String> normNameToId = {
        for (final e in catalog)
          norm((e['name'] ?? '').toString()): (e['id'] ?? '').toString().trim(),
      };
      String? fidForFunc(String funcName) {
        final key = funcName.trim();
        return nameToId[key] ?? normNameToId[norm(key)];
      }

      for (final ministryId in ministryIds) {
        final members = await ministriesRepo.getMinistryMembers(ministryId);
        final contexts = await ref
            .read(roleContextsRepositoryProvider)
            .getContextsByMinistry(ministryId);
        final rawSchedules = await ministriesRepo.getMinistrySchedules(
          ministryId,
        );
        // Lote 4 / B6: quando overwrite=true, o real generator clears THIS
        // event antes do fetch — então datesByUser não enxerga as datas
        // antigas deste mesmo evento. Espelho aqui.
        final existingSchedules = overwriteExisting
            ? rawSchedules.where((s) => s.eventId != event.id).toList()
            : rawSchedules;

        final Map<String, int> cfg = {};
        final Set<String> funcsFromMeta = {};
        final Map<String, String> funcCategory = {};
        bool exclusiveInstrument = false;
        bool exclusiveVoiceRole = false;
        bool exclusiveOther = false;
        bool allowMultiMinistries = false;
        final Map<String, List<String>> assignedByFunction = {};
        final Map<String, List<String>> assignedByFunctionFromMeta = {};
        final List<Map<String, dynamic>> blocks = [];
        final List<Map<String, String>> prohibitedCombos = [];
        final List<Map<String, String>> preferredCombos = [];
        final Map<String, dynamic> memberPriorities = {};
        final Map<String, dynamic> leadersByFunction = {};
        int? maxPerMonth;
        int? minDaysBetween;
        int? maxConsecutive;
        int? minExperienced; // Lote 4 / B3: espelhar do real para sort.

        for (final c in contexts) {
          final meta = c.metadata ?? {};
          for (final f in List<dynamic>.from(meta['functions'] ?? const [])) {
            final canon = norm(f.toString());
            if (canon.isNotEmpty) funcsFromMeta.add(canon);
          }
          final eventReq = meta['event_function_requirements'];
          if (eventReq is Map) {
            final Map<String, dynamic> reqForType = Map<String, dynamic>.from(
              eventReq[type] ?? {},
            );
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
          final catMap = Map<String, dynamic>.from(
            meta['function_category_by_function'] ?? {},
          );
          catMap.forEach(
            (k, v) => funcCategory[norm(k.toString())] = v.toString(),
          );
          final restrictions = Map<String, dynamic>.from(
            meta['category_restrictions'] ?? {},
          );
          exclusiveInstrument =
              (restrictions['instrument']?['exclusive'] as bool?) ??
              exclusiveInstrument;
          exclusiveVoiceRole =
              (restrictions['voice_role']?['exclusive'] as bool?) ??
              exclusiveVoiceRole;
          exclusiveOther =
              (restrictions['other']?['exclusive'] as bool?) ?? exclusiveOther;
          final assigned = Map<String, dynamic>.from(
            meta['assigned_functions'] ?? {},
          );
          assigned.forEach((userId, funcs) {
            for (final f in List<dynamic>.from(funcs ?? const [])) {
              final name = norm(f.toString());
              assignedByFunctionFromMeta.putIfAbsent(name, () => []);
              final uid = userId.toString();
              if (!assignedByFunctionFromMeta[name]!.contains(uid)) {
                assignedByFunctionFromMeta[name]!.add(uid);
              }
            }
          });
          final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
          final bl = List<dynamic>.from(rules['blocks'] ?? const []);
          for (final b in bl) {
            if (b is Map) blocks.add(Map<String, dynamic>.from(b));
          }
          final pc = List<dynamic>.from(
            rules['prohibited_combinations'] ?? const [],
          );
          for (final p in pc) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty)
                prohibitedCombos.add({
                  'a': a,
                  'b': b,
                  'a_func': af,
                  'b_func': bf,
                });
            }
          }
          final pr = List<dynamic>.from(
            rules['preferred_combinations'] ?? const [],
          );
          for (final p in pr) {
            if (p is Map) {
              final a = p['a']?.toString() ?? '';
              final b = p['b']?.toString() ?? '';
              final af = p['a_func']?.toString() ?? '*';
              final bf = p['b_func']?.toString() ?? '*';
              if (a.isNotEmpty && b.isNotEmpty)
                preferredCombos.add({
                  'a': a,
                  'b': b,
                  'a_func': af,
                  'b_func': bf,
                });
            }
          }
          final mp = Map<String, dynamic>.from(
            rules['member_priorities'] ?? {},
          );
          mp.forEach((k, v) => memberPriorities[k] = v);
          final lf = Map<String, dynamic>.from(
            rules['leaders_by_function'] ?? {},
          );
          lf.forEach((k, v) => leadersByFunction[norm(k.toString())] = v);
          final gr = Map<String, dynamic>.from(rules['general_rules'] ?? {});
          int? pInt2(dynamic v) =>
              v is int ? v : int.tryParse(v?.toString() ?? '');
          maxPerMonth = pInt2(gr['max_per_month']) ?? maxPerMonth;
          minDaysBetween = pInt2(gr['min_days_between']) ?? minDaysBetween;
          maxConsecutive = pInt2(gr['max_consecutive']) ?? maxConsecutive;
          minExperienced = pInt2(gr['min_experienced']) ?? minExperienced;
          final am = gr['allow_multi_ministries_per_event'];
          final amBool = am is bool
              ? am
              : (am?.toString().toLowerCase() == 'true');
          allowMultiMinistries = allowMultiMinistries || (amBool == true);
        }

        if (cfg.isEmpty) {
          final fallback = <String>{
            ...funcsFromMeta,
            ...funcCategory.keys,
            ...leadersByFunction.keys,
            ...assignedByFunctionFromMeta.keys,
          };
          for (final f in fallback) {
            if (f.isNotEmpty) cfg[f] = 1;
          }
        }

        // Completar candidatos por função com vínculos do banco (member_function)
        Map<String, List<String>> mfMap = {};
        try {
          mfMap = await ministriesRepo.getMemberFunctionsByMinistry(ministryId);
        } catch (_) {}

        // Candidatos por função:
        // - `member_function` é fonte de verdade *por usuário* quando existir (evita puxar quem foi desvinculado).
        // - Para usuários sem vínculo em `member_function`, usamos `assigned_functions` do metadata como fallback.
        assignedByFunction.clear();
        final Map<String, Set<String>> linkedCanonByUser = {};
        if (mfMap.isNotEmpty) {
          for (final entry in mfMap.entries) {
            final uid = entry.key;
            for (final f in entry.value) {
              final fn = norm(f);
              if (fn.isEmpty) continue;
              linkedCanonByUser.putIfAbsent(uid, () => <String>{}).add(fn);
              assignedByFunction.putIfAbsent(fn, () => []);
              if (!assignedByFunction[fn]!.contains(uid)) {
                assignedByFunction[fn]!.add(uid);
              }
            }
          }
        }
        if (mfMap.isEmpty) {
          assignedByFunction.addAll({
            for (final entry in assignedByFunctionFromMeta.entries)
              entry.key: entry.value.toSet().toList(),
          });
        } else {
          final linkedUsers = linkedCanonByUser.keys.toSet();
          for (final entry in assignedByFunctionFromMeta.entries) {
            final fn = entry.key;
            for (final uid in entry.value) {
              if (uid.isEmpty) continue;
              if (linkedUsers.contains(uid)) {
                // Se o usuário tem vínculos no banco, o metadata não pode "reintroduzir" funções.
                final linked = linkedCanonByUser[uid] ?? const <String>{};
                if (!linked.contains(fn)) continue;
              }
              assignedByFunction.putIfAbsent(fn, () => []);
              if (!assignedByFunction[fn]!.contains(uid)) {
                assignedByFunction[fn]!.add(uid);
              }
            }
          }
        }
        assignedByFunction.removeWhere((_, v) => v.isEmpty);

        debugPrint(
          'AutoScheduler.generateProposalForEvent(byFunction): ministry=$ministryId type=$type cfg=${cfg.length} metaFuncs=${funcsFromMeta.length} leaders=${leadersByFunction.length} mfUsers=${mfMap.length} assignedByFunc=${assignedByFunction.length} maxC=${maxConsecutive ?? '-'} minDays=${minDaysBetween ?? '-'} maxPerMonth=${maxPerMonth ?? '-'}',
        );

        // Mapa de categorias permitidas por usuário com base nas funções atribuídas (prévia)
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
        final Map<String, Set<String>> assignedCategoriesByUser = {};
        final Map<String, dynamic> membersById = {
          for (final m in members) m.memberId: m,
        };
        final Map<String, Set<String>> seenEventIdsByUser = {};
        final Map<String, List<DateTime>> datesByUser = {};
        for (final s in existingSchedules) {
          if (s.eventStartDate != null) {
            seenEventIdsByUser.putIfAbsent(s.memberId, () => <String>{});
            if (seenEventIdsByUser[s.memberId]!.add(s.eventId)) {
              datesByUser
                  .putIfAbsent(s.memberId, () => [])
                  .add(s.eventStartDate!);
            }
          }
        }
        // Lote 4 / B2+B6: espelhar do real generator. existingForEvent
        // marca quem já está escalado neste evento (em qualquer função);
        // existingByFuncId fixa (member, função) específico. Em overwrite
        // mode os dois ficam vazios — o real apaga e re-insere, preview
        // simula o mesmo comportamento.
        String funcKey(String? fidArg, String? nameArg) {
          if (fidArg != null && fidArg.isNotEmpty) return 'id:$fidArg';
          return 'name:${norm(nameArg ?? '')}';
        }
        final Set<String> existingForEvent;
        final Set<String> existingByFuncId;
        if (overwriteExisting) {
          existingForEvent = <String>{};
          existingByFuncId = <String>{};
        } else {
          existingForEvent = existingSchedules
              .where((s) => s.eventId == event.id)
              .map((s) => s.memberId)
              .toSet();
          existingByFuncId = existingSchedules
              .where((s) => s.eventId == event.id)
              .map((s) =>
                  '${s.memberId}|${funcKey(s.functionId, s.functionName)}')
              .toSet();
        }
        assignedMembers.addAll(existingForEvent);
        // Agregar exclusividades por categoria a partir dos contexts
        final Set<String> exclusiveWithinCats = {};
        final Set<String> exclusiveAloneCats = {};
        for (final c in contexts) {
          final meta = c.metadata ?? {};
          final restrictions = Map<String, dynamic>.from(
            meta['category_restrictions'] ?? {},
          );
          restrictions.forEach((k, v) {
            if (v is Map) {
              if ((v['exclusive'] as bool?) == true)
                exclusiveWithinCats.add(k.toString());
              if ((v['alone'] as bool?) == true)
                exclusiveAloneCats.add(k.toString());
            }
          });
        }

        // Princípio 1 espelhado no proposal — strict vs aplicado.
        bool violatesMonthStrict(String uid) {
          if (maxPerMonth == null) return false;
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          final m = event.startDate.month;
          final y = event.startDate.year;
          final count = list.where((d) => d.month == m && d.year == y).length;
          return count >= maxPerMonth;
        }

        bool violatesMonth(String uid) =>
            relaxMaxPerMonth ? false : violatesMonthStrict(uid);

        // Lote 4 / B1: bidirecional, espelhando o real generator.
        bool violatesMinDaysStrict(String uid) {
          if (minDaysBetween == null) return false;
          final list = datesByUser[uid] ?? const <DateTime>[];
          if (list.isEmpty) return false;
          for (final d in list) {
            if (dayDiff(event.startDate, d).abs() < minDaysBetween) return true;
          }
          return false;
        }

        bool violatesMinDays(String uid) =>
            relaxMinDays ? false : violatesMinDaysStrict(uid);

        int consecutiveGlobalFor(String uid) {
          final list = List<DateTime>.from(datesByUser[uid] ?? const []);
          if (list.isEmpty) return 0;
          list.sort((a, b) => a.compareTo(b));
          final prevs = list.where((d) => d.isBefore(event.startDate)).toList();
          if (prevs.isEmpty) return 0;
          final diffToCurrent = dayDiff(event.startDate, prevs.last).abs();
          if (diffToCurrent > 9) return 0;
          int streak = 1;
          DateTime last = prevs.last;
          for (int i = prevs.length - 2; i >= 0; i--) {
            final d = prevs[i];
            final diff = dayDiff(last, d).abs();
            if (diff <= 9) {
              streak++;
              last = d;
            } else {
              break;
            }
          }
          return streak;
        }

        bool violatesConsecutiveStrict(String uid) {
          final mc = maxConsecutive ?? 0;
          if (mc <= 0) return false;
          return consecutiveGlobalFor(uid) >= mc;
        }

        bool violatesConsecutive(String uid) =>
            relaxMaxConsecutive ? false : violatesConsecutiveStrict(uid);

        bool isBlocked(String uid) {
          DateTime d = event.startDate;
          for (final b in blocks) {
            final u = b['user_id']?.toString() ?? '';
            if (u != uid) continue;
            final type = b['type']?.toString() ?? 'total';
            final sd = DateTime.tryParse(b['start_date']?.toString() ?? '');
            final ed = DateTime.tryParse(b['end_date']?.toString() ?? '');
            if (type == 'evento') {
              if (sd != null &&
                  sd.year == d.year &&
                  sd.month == d.month &&
                  sd.day == d.day)
                return true;
            } else {
              if (sd != null && ed != null && !d.isBefore(sd) && !d.isAfter(ed))
                return true;
              if (sd != null && ed == null && !d.isBefore(sd)) return true;
              if (sd == null && ed != null && !d.isAfter(ed)) return true;
            }
          }
          return false;
        }

        bool violatesProhibited(String uid, String currentFunc) {
          for (final other in assignedMembers) {
            final funcsOther = List<String>.from(
              assignedFunctionsEvent[other] ?? const [],
            );
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

        // Lote 4 / B3: espelhar `isExperienced` + `experiencedCount` do real
        // generator pra sincronizar o sort de candidatos.
        bool isExperienced(String uid) {
          final m = membersById[uid];
          if (m == null) return false;
          return m.role.value != 'member';
        }

        int experiencedCount = 0;

        final Map<String, List<String>> candidatesByFunction = {};
        for (final entry in cfg.entries) {
          final f = entry.key;
          final assignedCandidates0 = List<String>.from(
            assignedByFunction[f] ?? const [],
          );
          final leaderCfg0 = Map<String, dynamic>.from(
            leadersByFunction[f] ?? {},
          );
          final leaderId0 = leaderCfg0['leader']?.toString();
          final subs0 = List<dynamic>.from(
            leaderCfg0['subs'] ?? const [],
          ).map((e) => e.toString()).toList();
          final seeds0 = <String>{
            ...assignedCandidates0,
            if (leaderId0 != null) leaderId0,
            ...subs0,
          };
          candidatesByFunction[f] = seeds0.toList();
        }

        final List<MapEntry<String, int>> orderedCfg = () {
          final order = <String>[];
          final metaOrder = contexts
              .map(
                (c) =>
                    (c.metadata?['category_order'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const <String>[],
              )
              .firstWhere((l) => l.isNotEmpty, orElse: () => const <String>[]);
          if (metaOrder.isNotEmpty) {
            order.addAll(metaOrder);
          } else {
            order.addAll(['voice_role', 'instrument', 'other']);
          }
          int catRank(String f) {
            final cat = funcCategory[f] ?? 'other';
            final idx = order.indexOf(cat);
            return idx >= 0 ? idx : order.length;
          }

          // Lote 4 / B4: removido funcPri {ministrante:1, back:2} que só
          // existia no proposal. Alinha ordem de funções com o real generator
          // (catRank → nome alfabético).
          final list = cfg.entries.toList();
          list.sort((a, b) {
            final ra = catRank(a.key);
            final rb = catRank(b.key);
            if (ra != rb) return ra.compareTo(rb);
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
            final matchByName =
                fid == null && (norm((s.functionName ?? '')) == norm(funcName));
            if (s.eventStartDate != null && (matchById || matchByName)) {
              datesByUserFunc
                  .putIfAbsent(s.memberId, () => [])
                  .add(s.eventStartDate!);
            }
          }
          int consecutiveFor(String uid) {
            final list = List<DateTime>.from(datesByUserFunc[uid] ?? const []);
            if (list.isEmpty) return 0;
            list.sort((a, b) => a.compareTo(b));
            final prevs = list
                .where((d) => d.isBefore(event.startDate))
                .toList();
            if (prevs.isEmpty) return 0;
            int streak = 1;
            DateTime last = prevs.last;
            for (int i = prevs.length - 2; i >= 0; i--) {
              final d = prevs[i];
              final diff = dayDiff(last, d).abs();
              if (diff <= 9) {
                streak++;
                last = d;
              } else {
                break;
              }
            }
            return streak;
          }

          final assignedCandidates0 = List<String>.from(
            assignedByFunction[funcName] ?? const [],
          );
          final leaderCfg = Map<String, dynamic>.from(
            leadersByFunction[funcName] ?? {},
          );
          final leaderId = leaderCfg['leader']?.toString();
          final subs = List<dynamic>.from(
            leaderCfg['subs'] ?? const [],
          ).map((e) => e.toString()).toList();
          final seeds = <String>{
            ...assignedCandidates0,
            if (leaderId != null) leaderId,
            ...subs,
          };
          var assignedCandidates = seeds
              .where(
                (uid) =>
                    !isBlocked(uid) &&
                    !violatesMonth(uid) &&
                    !violatesMinDays(uid),
              )
              .toList();
          final maxC = maxConsecutive ?? 0;
          if (maxC > 0) {
            final allowed = assignedCandidates
                .where((uid) => consecutiveGlobalFor(uid) < maxC)
                .toList();
            final overflow = assignedCandidates
                .where((uid) => consecutiveGlobalFor(uid) >= maxC)
                .toList();
            assignedCandidates = [...allowed, ...overflow];
          }
          // Lote 4 / B3: sort sincronizado com o real generator.
          // Ordem: experienced first se minExperienced > experiencedCount →
          // fairDistribution OR scoreFor DESC → scheduledCountMonth ASC (desempate).
          // Lote 5: score = prioFor + boost de líder/suplente — espelho do
          // generateForEvent. Preview reflete o que a geração real fará.
          int scheduledCountTotal(String uid) =>
              (datesByUser[uid] ?? const []).length;
          int scheduledCountMonth(String uid) {
            final list = datesByUserFunc[uid] ?? const <DateTime>[];
            final m = event.startDate.month;
            final y = event.startDate.year;
            return list.where((d) => d.month == m && d.year == y).length;
          }
          int boostFor(String uid) {
            if (!useLeaderBoostScore) return 0;
            if (leaderId != null &&
                leaderId.isNotEmpty &&
                uid == leaderId) {
              return 2;
            }
            if (subs.contains(uid)) return 1;
            return 0;
          }
          int scoreFor(String uid) => prioFor(uid) + boostFor(uid);
          assignedCandidates.sort((a, b) {
            if ((minExperienced ?? 0) > experiencedCount) {
              final ea = isExperienced(a);
              final eb = isExperienced(b);
              if (ea != eb) return ea ? -1 : 1;
            }
            final sa = scoreFor(a);
            final sb = scoreFor(b);
            if (fairDistribution) {
              final ca = scheduledCountTotal(a);
              final cb = scheduledCountTotal(b);
              if (ca != cb) return ca.compareTo(cb);
              return sb.compareTo(sa);
            }
            final cmp = sb.compareTo(sa);
            if (cmp != 0) return cmp;
            return scheduledCountMonth(a).compareTo(scheduledCountMonth(b));
          });
          final reserved = List<String>.from(
            reservedByFunction[funcName] ?? const <String>[],
          ).where((uid) => assignedCandidates.contains(uid)).toList();
          for (int i = reserved.length - 1; i >= 0; i--) {
            final r = reserved[i];
            assignedCandidates.remove(r);
            assignedCandidates.insert(0, r);
          }
          if (!useLeaderBoostScore) {
            // Comportamento legado: empurra líder/subs pro topo da lista
            // independente da prioridade. Mantido como fallback do
            // kill-switch.
            var insertPos = 0;
            if (leaderId != null &&
                leaderId.isNotEmpty &&
                assignedCandidates.contains(leaderId)) {
              assignedCandidates.remove(leaderId);
              assignedCandidates.insert(insertPos, leaderId);
              insertPos++;
            }
            for (final sid in subs) {
              if (sid.isEmpty) continue;
              if (leaderId != null && sid == leaderId) continue;
              if (assignedCandidates.contains(sid)) {
                assignedCandidates.remove(sid);
                assignedCandidates.insert(insertPos, sid);
                insertPos++;
              }
            }
          }
          int idxA = 0;
          while (count < needed && idxA < assignedCandidates.length) {
            final uid = assignedCandidates[idxA];
            if (!membersById.containsKey(uid)) {
              idxA++;
              continue;
            }
            if (assignedMembers.contains(uid)) {
              final cats = assignedCategoriesByUser[uid] ?? <String>{};
              final allowedCats =
                  allowedCategoriesByUser[uid] ?? const <String>{};
              if (allowedCats.length == 1) {
                final onlyCat = allowedCats.first;
                if (cats.contains(onlyCat) && cat != onlyCat) {
                  idxA++;
                  continue;
                }
              }
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat)) {
                idxA++;
                continue;
              }
              if (exclusiveAloneCats.contains(cat) &&
                  cats.any((c) => c != cat)) {
                idxA++;
                continue;
              }
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat)) {
                idxA++;
                continue;
              }
              if (cat == 'instrument' &&
                  exclusiveInstrument &&
                  assignedInstrumentMembers.contains(uid)) {
                idxA++;
                continue;
              }
              if (cat == 'voice_role' &&
                  exclusiveVoiceRole &&
                  assignedVoiceMembers.contains(uid)) {
                idxA++;
                continue;
              }
              if (cat == 'other' && exclusiveOther) {
                idxA++;
                continue;
              }
            }
            if (isBlocked(uid)) {
              idxA++;
              continue;
            }
            if (violatesProhibited(uid, funcName)) {
              idxA++;
              continue;
            }
            if (violatesMonth(uid)) {
              idxA++;
              continue;
            }
            if (violatesMinDays(uid)) {
              idxA++;
              continue;
            }
            if (violatesConsecutive(uid)) {
              idxA++;
              continue;
            }
            // Fix #11 (espelhado no proposal): quando multi-ministério não
            // é permitido, o mesmo membro não pode aparecer em 2 ministérios
            // do mesmo evento — nem na prévia.
            if (!allowMultiMinistries && globalAssignedMembers.contains(uid)) {
              idxA++;
              continue;
            }
            // Lote 4 / B2: espelha existingByFuncId do real.
            final keyById = '$uid|${funcKey(fid, funcName)}';
            if (existingByFuncId.contains(keyById)) {
              idxA++;
              continue;
            }

            proposals.add({
              'event_id': event.id,
              'ministry_id': ministryId,
              'user_id': uid,
              'notes': funcName,
              'function_id': fid ?? '',
            });
            assignedMembers.add(uid);
            globalAssignedMembers.add(uid); // Fix #11 espelhado
            if (cat == 'instrument') assignedInstrumentMembers.add(uid);
            if (cat == 'voice_role') assignedVoiceMembers.add(uid);
            assignedCategoriesByUser
                .putIfAbsent(uid, () => <String>{})
                .add(cat);
            assignedFunctionsEvent.putIfAbsent(uid, () => []).add(funcName);
            // Lote 4 / B5: atualizar state maps após cada insert pra que as
            // próximas funções deste evento contem o uid recém-escalado.
            datesByUserFunc.putIfAbsent(uid, () => []).add(event.startDate);
            seenEventIdsByUser.putIfAbsent(uid, () => <String>{});
            if (seenEventIdsByUser[uid]!.add(event.id)) {
              datesByUser.putIfAbsent(uid, () => []).add(event.startDate);
            }
            if (isExperienced(uid)) experiencedCount++;
            for (final p in preferredCombos) {
              final a = p['a']!;
              final b = p['b']!;
              final af = p['a_func'] ?? '*';
              final bf = p['b_func'] ?? '*';
              bool eq(String x, String y) => norm(x) == norm(y);
              if (uid == a &&
                  (af == '*' || eq(af, funcName)) &&
                  bf != '*' &&
                  !eq(bf, funcName)) {
                reservedByFunction.putIfAbsent(bf, () => []).add(b);
                reservedByFunction.putIfAbsent(bf, () => []).add(a);
              } else if (uid == b &&
                  (bf == '*' || eq(bf, funcName)) &&
                  af != '*' &&
                  !eq(af, funcName)) {
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
                .where((sid) => !violatesConsecutive(sid))
                .toList();
            for (final sid in subsTry) {
              if (count >= needed) break;
              if (assignedMembers.contains(sid)) continue;
              final cats = assignedCategoriesByUser[sid] ?? <String>{};
              if (exclusiveWithinCats.contains(cat) && cats.contains(cat))
                continue;
              if (exclusiveAloneCats.contains(cat) && cats.any((c) => c != cat))
                continue;
              if (cats.any((c) => exclusiveAloneCats.contains(c) && c != cat))
                continue;
              if (cat == 'instrument' &&
                  exclusiveInstrument &&
                  assignedInstrumentMembers.contains(sid))
                continue;
              if (cat == 'voice_role' &&
                  exclusiveVoiceRole &&
                  assignedVoiceMembers.contains(sid))
                continue;
              if (cat == 'other' && exclusiveOther) continue;
              if (isBlocked(sid)) continue;
              if (violatesProhibited(sid, funcName)) continue;
              if (violatesMonth(sid)) continue;
              if (violatesMinDays(sid)) continue;
              if (violatesConsecutive(sid)) continue;
              // Fix #11 (espelhado no proposal).
              if (!allowMultiMinistries && globalAssignedMembers.contains(sid))
                continue;
              // Lote 4 / B2: existingByFuncId no proposal.
              final keyById = '$sid|${funcKey(fid, funcName)}';
              if (existingByFuncId.contains(keyById)) continue;

              proposals.add({
                'event_id': event.id,
                'ministry_id': ministryId,
                'user_id': sid,
                'notes': funcName,
                'function_id': fid ?? '',
              });
              assignedMembers.add(sid);
              globalAssignedMembers.add(sid); // Fix #11 espelhado
              if (cat == 'instrument') assignedInstrumentMembers.add(sid);
              if (cat == 'voice_role') assignedVoiceMembers.add(sid);
              assignedCategoriesByUser
                  .putIfAbsent(sid, () => <String>{})
                  .add(cat);
              assignedFunctionsEvent.putIfAbsent(sid, () => []).add(funcName);
              // Lote 4 / B5: atualizar state maps no fallback de subs também.
              datesByUserFunc.putIfAbsent(sid, () => []).add(event.startDate);
              seenEventIdsByUser.putIfAbsent(sid, () => <String>{});
              if (seenEventIdsByUser[sid]!.add(event.id)) {
                datesByUser.putIfAbsent(sid, () => []).add(event.startDate);
              }
              if (isExperienced(sid)) experiencedCount++;
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
          final gr = Map<String, dynamic>.from(
            c.metadata?['schedule_rules']?['general_rules'] ?? {},
          );
          final v = gr['allow_multi_ministries_per_event'];
          final b = v is bool ? v : (v?.toString().toLowerCase() == 'true');
          if (b) {
            allowMultiMinistries = true;
            break;
          }
        }
        if (allowMultiMinistries) break;
      }
    } catch (_) {}

    for (final ministryId in ministryIds) {
      final members = await ministriesRepo.getMinistryMembers(ministryId);
      final existingSchedules = await ministriesRepo.getMinistrySchedules(
        ministryId,
      );
      final contexts = await ref
          .read(roleContextsRepositoryProvider)
          .getContextsByMinistry(ministryId);
      final rules = contexts.isNotEmpty
          ? Map<String, dynamic>.from(
              contexts.first.metadata?['schedule_rules'] ?? {},
            )
          : <String, dynamic>{};
      // Fix #5+#6: ler `general_rules` (não a raiz de `schedule_rules`) com
      // cast tolerante (int/double/string) para não abortar quando vier `4.0`
      // ou string numérica.
      final generalRules = Map<String, dynamic>.from(
        rules['general_rules'] ?? const {},
      );
      int? pIntRule(dynamic v) =>
          v is int ? v : int.tryParse(v?.toString() ?? '');
      final maxPerMonth = pIntRule(generalRules['max_per_month']);
      final minDaysBetween = pIntRule(generalRules['min_days_between']);
      DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
      int dayDiff(DateTime a, DateTime b) =>
          dayKey(a).difference(dayKey(b)).inDays;
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

      // Lote 4 / B1: bidirecional. Ramo de presença do evento conjunto (proposal).
      bool violatesMinDays(String uid) {
        if (minDaysBetween == null) return false;
        final list = datesByUser[uid] ?? const <DateTime>[];
        if (list.isEmpty) return false;
        for (final d in list) {
          if (dayDiff(event.startDate, d).abs() < minDaysBetween) return true;
        }
        return false;
      }

      for (final m in members) {
        if (violatesMonth(m.memberId)) continue;
        if (violatesMinDays(m.memberId)) continue;
        if (globalAssignedMembers.contains(m.memberId)) continue;
        proposals.add({
          'event_id': event.id,
          'ministry_id': ministryId,
          'user_id': m.memberId,
          'notes': 'Presença Geral',
        });
        globalAssignedMembers.add(m.memberId);
      }
    }
    return proposals;
  }
}

// ============================================================================
// Relatório de geração (Fix #1+#3)
//
// Substitui o falso "Escala gerada com sucesso" por um relatório estruturado
// que distingue OK / PARCIAL / VAZIO por função e registra os motivos pelos
// quais o pool não fechou. A tela exibe esse relatório em modal ao final.
// ============================================================================

enum ScheduleSlotStatus { ok, partial, empty }

class ScheduleSlotResult {
  final String ministryId;
  final String funcName;
  final int expected;
  final int inserted;

  /// Texto agregado descrevendo por que o slot não fechou (vazio se OK).
  /// Ex.: "Pool insuficiente — bloqueio: 2, min_days: 1, sem pessoas
  /// autorizadas com função vinculada."
  final String reason;

  /// Conjunto de regras de frequência que foram relaxadas para conseguir
  /// preencher este slot (apenas faz sentido com o relaxamento opt-in
  /// ativado pela tela). Vazio quando nenhuma regra foi contornada.
  final Set<String> relaxedRules;

  const ScheduleSlotResult({
    required this.ministryId,
    required this.funcName,
    required this.expected,
    required this.inserted,
    this.reason = '',
    this.relaxedRules = const <String>{},
  });

  ScheduleSlotStatus get status {
    if (inserted >= expected) return ScheduleSlotStatus.ok;
    if (inserted == 0) return ScheduleSlotStatus.empty;
    return ScheduleSlotStatus.partial;
  }

  int get missing => (expected - inserted).clamp(0, expected);
  bool get hasRelaxation => relaxedRules.isNotEmpty;
}

class EventScheduleReport {
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final List<ScheduleSlotResult> slots;

  /// Nota geral aplicada quando o ramo é de presença (sem cfg rígido por
  /// função). Ex.: "Presença total escalada (12 membros)".
  final String? generalNote;

  const EventScheduleReport({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    this.slots = const [],
    this.generalNote,
  });

  ScheduleSlotStatus get status {
    if (slots.isEmpty) {
      return generalNote == null
          ? ScheduleSlotStatus.empty
          : ScheduleSlotStatus.ok;
    }
    final allOk = slots.every((s) => s.status == ScheduleSlotStatus.ok);
    if (allOk) return ScheduleSlotStatus.ok;
    final allEmpty = slots.every((s) => s.status == ScheduleSlotStatus.empty);
    if (allEmpty) return ScheduleSlotStatus.empty;
    return ScheduleSlotStatus.partial;
  }

  Iterable<ScheduleSlotResult> get pendingSlots =>
      slots.where((s) => s.status != ScheduleSlotStatus.ok);

  int get totalExpected => slots.fold(0, (a, s) => a + s.expected);
  int get totalInserted => slots.fold(0, (a, s) => a + s.inserted);
}
