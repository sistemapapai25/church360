import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/utils/name_sort.dart';

import '../domain/models/ministry.dart';

/// Repository para gerenciar ministérios
class MinistriesRepository {
  final SupabaseClient _supabase;

  MinistriesRepository(this._supabase);

  // ==================== MINISTÉRIOS ====================

  /// Buscar todos os ministérios
  Future<List<Ministry>> getAllMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('name', ascending: true);

    return (response as List).map((json) => Ministry.fromJson(json)).toList();
  }

  /// Buscar ministérios ativos
  Future<List<Ministry>> getActiveMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select('''
          *,
          ministry_member(count)
        ''')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List).map((json) {
      final memberCount = json['ministry_member'] != null
          ? (json['ministry_member'] as List).length
          : 0;

      return Ministry.fromJson({...json, 'member_count': memberCount});
    }).toList();
  }

  /// Buscar ministério por ID
  Future<Ministry?> getMinistryById(String id) async {
    final response = await _supabase
        .from('ministry')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return Ministry.fromJson(response);
  }

  /// Criar ministério
  Future<Ministry> createMinistry(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('ministry')
        .insert({...data, 'tenant_id': SupabaseConstants.currentTenantId})
        .select()
        .single();

    return Ministry.fromJson(response);
  }

  /// Criar ministério **com o vínculo inicial de liderança**, numa transação.
  ///
  /// É a porta da Fase 3: a RPC `create_ministry_with_leader` grava em
  /// `ministry` e em `ministry_member` de uma vez. [createMinistry] acima
  /// continua existindo para quem só precisa da linha, mas quem cria pela tela
  /// passa por aqui — senão o ministério nasce sem ninguém dentro e some da
  /// lista de todo mundo que não tem visão global.
  ///
  /// A RPC também repete no servidor o gate `ministries.create` que hoje só
  /// existe na rota do app.
  ///
  /// [leaderUserId] é um `user_account.id` (não um `auth.users.id` — são chaves
  /// diferentes neste banco). Omitido, a RPC vincula o próprio chamador.
  ///
  /// Devolve o `id` do ministério criado. Erros que ela propaga:
  /// `42501` sem permissão, `22023` nome vazio ou tipo desconhecido.
  Future<String> createMinistryWithLeader({
    required String name,
    required String ministryType,
    String? description,
    String? color,
    String? whatsappGroupNumber,
    String? leaderUserId,
  }) async {
    final id = await _supabase.rpc(
      'create_ministry_with_leader',
      params: {
        'p_name': name,
        'p_ministry_type': ministryType,
        'p_description': description,
        'p_color': color,
        'p_whatsapp_group_number': whatsappGroupNumber,
        'p_leader_user_id': leaderUserId,
      },
    );
    return id as String;
  }

  /// Atualizar ministério
  Future<Ministry> updateMinistry(String id, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('ministry')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return Ministry.fromJson(response);
  }

  /// Excluir ministério com tudo o que é dele (cargos de contexto, equipe,
  /// escalas...). Cursos ficam, só desvinculados; financeiro vai para o caixa
  /// geral. A RPC faz tudo numa transação e exige `ministries.delete`.
  Future<void> deleteMinistry(String id) async {
    await _supabase.rpc('delete_ministry', params: {'p_ministry_id': id});
  }

  /// Liga/desliga uma aba do ministério (`settings.tabs`). A RPC aceita o
  /// líder do ministério ou quem tem `ministries.edit`.
  Future<void> setMinistryTab(String ministryId, String key, bool enabled) =>
      _supabase.rpc(
        'set_ministry_tab',
        params: {
          'p_ministry_id': ministryId,
          'p_key': key,
          'p_enabled': enabled,
        },
      );

  /// Ordem pessoal das abas do ministério (a RLS só devolve a linha de quem
  /// está logado). Vazia = ordem padrão.
  Future<List<String>> getMyTabOrder(String ministryId) async {
    final row = await _supabase
        .from('user_ministry_tab_order')
        .select('tab_keys')
        .eq('ministry_id', ministryId)
        .maybeSingle();
    final keys = row?['tab_keys'];
    return keys is List ? [for (final k in keys) k.toString()] : const [];
  }

  /// `user_id` é o `auth.uid()` (a RLS confere).
  Future<void> saveMyTabOrder(String ministryId, List<String> keys) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada.');
    await _supabase.from('user_ministry_tab_order').upsert({
      'user_id': userId,
      'ministry_id': ministryId,
      'tab_keys': keys,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,ministry_id');
  }

  /// Contar ministérios
  Future<int> countMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select('id')
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    return (response as List).length;
  }

  /// Contar ministérios ativos
  Future<int> countActiveMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select('id')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true);

    return (response as List).length;
  }

  // ==================== MEMBROS DO MINISTÉRIO ====================

  /// Buscar membros de um ministério
  Future<List<MinistryMember>> getMinistryMembers(String ministryId) async {
    final response = await _supabase
        .from('ministry_member')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name,
            nickname,
            phone,
            auth_user_id
          )
        ''')
        .eq('ministry_id', ministryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('role', ascending: true);

    // `user_roles` é chaveado pelo login (auth_user_id), `ministry_member` e
    // `assigned_functions` pelo user_account.id — guardar as duas chaves.
    final authByAccount = <String, String?>{};
    var members = (response as List).map((json) {
      final member = json['user_account'];
      String memberName = '';
      if (member != null) {
        authByAccount[json['user_id'] as String] =
            member['auth_user_id'] as String?;
        final nick = (member['nickname'] ?? member['apelido'] ?? '')
            .toString()
            .trim();
        if (nick.isNotEmpty) {
          memberName = nick;
        } else {
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          memberName = ('$fn $ln').trim();
        }
      }

      // O embed pode vir nulo sem erro nenhum quando a RLS de `user_account`
      // não libera a linha para quem consulta — telefone ausente aqui
      // significa "não sei", e a tela trata isso como o terceiro estado.
      final phone = member == null ? null : member['phone'] as String?;

      return MinistryMember.fromJson({
        ...json,
        'member_name': memberName,
        'member_phone': phone,
      });
    }).toList();

    // Fallback: preencher nomes para registros que não retornaram join
    final missing = members.where((m) => (m.memberName).isEmpty).toList();
    if (missing.isNotEmpty) {
      final keys = missing.map((m) => m.memberId).toSet().toList();
      try {
        final details = await _supabase
            .from('user_account')
            .select('id,first_name,last_name,nickname,phone,auth_user_id')
            .inFilter('id', keys)
            .eq('tenant_id', SupabaseConstants.currentTenantId);
        final nameById = <String, String>{};
        final phoneById = <String, String?>{};
        for (final row in (details as List)) {
          final id = row['id'] as String?;
          if (id != null) {
            phoneById[id] = row['phone'] as String?;
            authByAccount[id] = row['auth_user_id'] as String?;
            final nick = (row['nickname'] ?? row['apelido'] ?? '')
                .toString()
                .trim();
            if (nick.isNotEmpty) {
              nameById[id] = nick;
            } else {
              final fn = (row['first_name'] ?? '').toString();
              final ln = (row['last_name'] ?? '').toString();
              nameById[id] = ('$fn $ln').trim();
            }
          }
        }
        members = members
            .map(
              (m) => nameById.containsKey(m.memberId)
                  ? m.copyWith(
                      memberName: nameById[m.memberId],
                      phone: m.phone ?? phoneById[m.memberId],
                    )
                  : m,
            )
            .toList();
      } catch (_) {}
    }

    members.sort((a, b) => compareNames(a.memberName, b.memberName));
    if (members.isEmpty) return members;

    final contexts = await _supabase
        .from('role_contexts')
        .select('id, role_id, metadata, is_active')
        .contains('metadata', {'ministry_id': ministryId})
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true);

    final contextList = (contexts as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    if (contextList.isEmpty) return members;

    final contextById = {for (final c in contextList) c['id'] as String: c};
    List<String> functionsIn(Map<String, dynamic> ctx, String accountId) {
      final meta = ctx['metadata'] as Map<String, dynamic>? ?? const {};
      final assigned =
          meta['assigned_functions'] as Map<String, dynamic>? ?? const {};
      return List<dynamic>.from(
        assigned[accountId] ?? const [],
      ).map((f) => f.toString()).toList();
    }

    // Uma RPC por integrante, mas em paralelo (CHU-388): a espera é a da
    // mais lenta, não a soma de todas.
    Future<MinistryMember> resolve(MinistryMember m) async {
      final accountId = m.memberId;
      final authId = authByAccount[accountId];
      final cargos = <String>{};
      final functions = <String>{};

      if (!authByAccount.containsKey(accountId)) {
        // Linha de user_account escondida pela RLS: não dá para saber se
        // tem login, então não mostra cargo nem função.
      } else if (authId == null) {
        // Sem login não existe `user_roles` para validar: a função gravada
        // pelo diálogo de edição é a única fonte, então vale como está.
        for (final ctx in contextList) {
          functions.addAll(functionsIn(ctx, accountId));
        }
      } else {
        try {
          // A RPC já filtra vínculo ativo e não expirado; só os contextos
          // deste ministério que ela devolver contam — função de contexto
          // cujo vínculo caiu não volta para a tela.
          final resp = await _supabase.rpc(
            'get_user_role_contexts',
            params: {'p_user_id': authId, 'p_role_id': null},
          );
          for (final it in (resp as List).cast<Map<String, dynamic>>()) {
            final ctx = contextById[it['context_id'] as String?];
            if (ctx == null) continue;
            final name = it['role_name'] as String?;
            if (name != null && name.isNotEmpty) cargos.add(name);
            functions.addAll(functionsIn(ctx, accountId));
          }
        } catch (_) {}
      }

      final sortedCargos = cargos.toList()..sort();
      return m.copyWith(
        cargoName: sortedCargos.isEmpty ? null : sortedCargos.first,
        cargoNames: sortedCargos,
        assignedFunctions: functions.toList()..sort(),
      );
    }

    return Future.wait(members.map(resolve));
  }

  /// Verifica se já existe vínculo do membro com o ministério
  Future<bool> membershipExists({
    required String ministryId,
    required String personId,
  }) async {
    final existingUser = await _supabase
        .from('ministry_member')
        .select('id')
        .eq('ministry_id', ministryId)
        .eq('user_id', personId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();
    if (existingUser != null) return true;
    return false;
  }

  /// Adicionar membro ao ministério
  Future<MinistryMember> addMinistryMember(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final response = await _supabase
        .from('ministry_member')
        .insert({...payload, 'tenant_id': SupabaseConstants.currentTenantId})
        .select('*')
        .single();

    final String? userKey = response['user_id'] as String?;
    String memberName = '';
    if (userKey != null) {
      final ua = await _supabase
          .from('user_account')
          .select('first_name,last_name,nickname')
          .eq('id', userKey)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();
      if (ua != null) {
        final nick = (ua['nickname'] ?? ua['apelido'] ?? '').toString().trim();
        if (nick.isNotEmpty) {
          memberName = nick;
        } else {
          final fn = (ua['first_name'] ?? '').toString();
          final ln = (ua['last_name'] ?? '').toString();
          memberName = ('$fn $ln').trim();
        }
      }
    }

    return MinistryMember.fromJson({...response, 'member_name': memberName});
  }

  /// Atualizar membro do ministério
  Future<MinistryMember> updateMinistryMember(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('ministry_member')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name,
            nickname
          )
        ''')
        .single();

    final member = response['user_account'];
    String memberName = '';
    if (member != null) {
      final nick = (member['nickname'] ?? member['apelido'] ?? '')
          .toString()
          .trim();
      if (nick.isNotEmpty) {
        memberName = nick;
      } else {
        final fn = (member['first_name'] ?? '').toString();
        final ln = (member['last_name'] ?? '').toString();
        memberName = ('$fn $ln').trim();
      }
    }

    return MinistryMember.fromJson({...response, 'member_name': memberName});
  }

  /// Remover membro do ministério
  Future<void> removeMinistryMember(String id) async {
    await _supabase
        .from('ministry_member')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Buscar ministérios de um membro
  Future<List<Ministry>> getMemberMinistries(String memberId) async {
    final response = await _supabase
        .from('ministry_member')
        .select('''
          ministry:ministry_id (*)
        ''')
        .eq('user_id', memberId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    // O embed `ministry:ministry_id (*)` volta NULL — sem erro nenhum — quando
    // a RLS de `ministry` não deixa o leitor ver aquela linha. Sem este filtro,
    // `Ministry.fromJson(null)` estoura e o chamador recebe um erro que parece
    // de rede. Descartar a linha ilegível é o comportamento certo: a pessoa vê
    // os ministérios que pode ver, não uma exceção.
    return (response as List)
        .where((json) => json['ministry'] != null)
        .map((json) => Ministry.fromJson(json['ministry']))
        .toList();
  }

  /// Ministérios em que o membro está na liderança (`role = leader`).
  Future<Set<String>> getLedMinistryIds(String memberId) async {
    final rows = await _supabase
        .from('ministry_member')
        .select('ministry_id')
        .eq('user_id', memberId)
        .eq('role', 'leader')
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    return {for (final r in rows as List) r['ministry_id'] as String};
  }

  // CHU-384 (29/09/2026): aqui existia `isCoordinatorOfAnyMinistry`, que
  // consultava ministry_member por `role = coordinator`. Nenhuma linha de
  // produção tem esse papel, então a consulta respondia `false` sempre e
  // escondia o card "Próximos Eventos" do Dashboard de todo mundo. Removida
  // junto com o único consumidor.

  // ==================== ESCALAS ====================

  /// Buscar escalas de um evento
  Future<List<MinistrySchedule>> getEventSchedules(String eventId) async {
    final response = await _supabase
        .from('ministry_schedule')
        .select('''
          *,
          event!fk_ministry_schedule_event (name),
          ministry!fk_ministry_schedule_ministry (name),
          user_account!fk_ministry_schedule_user (first_name, last_name, nickname),
          ministry_function:function_id (id,name,code)
        ''')
        .eq('event_id', eventId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('ministry_id', ascending: true);

    return (response as List).map((json) {
      final event = json['event'];
      final ministry = json['ministry'];
      final member = json['user_account'];
      final func = json['ministry_function'];

      return MinistrySchedule.fromJson({
        ...json,
        'event_name': event?['name'] ?? '',
        'ministry_name': ministry?['name'] ?? '',
        'member_name': (() {
          if (member == null) return '';
          final nick = (member['nickname'] ?? member['apelido'] ?? '')
              .toString()
              .trim();
          if (nick.isNotEmpty) return nick;
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          return ('$fn $ln').trim();
        })(),
        'function_name': func != null
            ? (func['name'] ?? func['code'] ?? '')
            : null,
      });
    }).toList();
  }

  /// Buscar escalas de um ministério
  Future<List<MinistrySchedule>> getMinistrySchedules(String ministryId) async {
    final response = await _supabase
        .from('ministry_schedule')
        .select('''
          *,
          event!fk_ministry_schedule_event (name,start_date),
          ministry!fk_ministry_schedule_ministry (name),
          user_account!fk_ministry_schedule_user (first_name, last_name, nickname),
          ministry_function:function_id (id,name,code)
        ''')
        .eq('ministry_id', ministryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final event = json['event'];
      final ministry = json['ministry'];
      final member = json['user_account'];
      final func = json['ministry_function'];

      return MinistrySchedule.fromJson({
        ...json,
        'event_name': event?['name'] ?? '',
        'event_start_date': event?['start_date'],
        'ministry_name': ministry?['name'] ?? '',
        'member_name': (() {
          if (member == null) return '';
          final nick = (member['nickname'] ?? member['apelido'] ?? '')
              .toString()
              .trim();
          if (nick.isNotEmpty) return nick;
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          return ('$fn $ln').trim();
        })(),
        'function_name': func != null
            ? (func['name'] ?? func['code'] ?? '')
            : null,
      });
    }).toList();
  }

  /// Adicionar escala
  Future<MinistrySchedule> addSchedule(Map<String, dynamic> data) async {
    // Guardar: normalizar chave de membro para a coluna correta
    final payload = Map<String, dynamic>.from(data);
    if (payload.containsKey('member_id') && !payload.containsKey('user_id')) {
      payload['user_id'] = payload['member_id'];
      payload.remove('member_id');
    }
    final response = await _supabase
        .from('ministry_schedule')
        .insert({...payload, 'tenant_id': SupabaseConstants.currentTenantId})
        .select('''
          *,
          event!fk_ministry_schedule_event (name),
          ministry!fk_ministry_schedule_ministry (name),
          user_account!fk_ministry_schedule_user (first_name, last_name),
          ministry_function:function_id (id,name,code)
        ''')
        .single();

    final event = response['event'];
    final ministry = response['ministry'];
    final member = response['user_account'];
    final func = response['ministry_function'];

    return MinistrySchedule.fromJson({
      ...response,
      'event_name': event?['name'] ?? '',
      'ministry_name': ministry?['name'] ?? '',
      'member_name': member != null
          ? '${member['first_name']} ${member['last_name']}'
          : '',
      'function_name': func != null
          ? (func['name'] ?? func['code'] ?? '')
          : null,
    });
  }

  /// Lote 3 (#14): inserção em batch — uma única requisição com array de
  /// schedules. Reduz N round-trips para 1 e fica em uma única transação
  /// no Postgres (atomicidade efetiva). Retorna a contagem inserida.
  Future<int> addSchedulesBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final payload = rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      if (m.containsKey('member_id') && !m.containsKey('user_id')) {
        m['user_id'] = m['member_id'];
        m.remove('member_id');
      }
      m['tenant_id'] = SupabaseConstants.currentTenantId;
      return m;
    }).toList();
    final response = await _supabase
        .from('ministry_schedule')
        .insert(payload)
        .select('id');
    return (response as List).length;
  }

  /// Remover escala
  Future<void> removeSchedule(String id) async {
    await _supabase
        .from('ministry_schedule')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> clearSchedulesForEventMinistry(
    String eventId,
    String ministryId,
  ) async {
    await _supabase
        .from('ministry_schedule')
        .delete()
        .eq('event_id', eventId)
        .eq('ministry_id', ministryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<List<Map<String, String>>> getFunctionsCatalog() async {
    try {
      final response = await _supabase
          .from('ministry_function')
          .select('id,name,code,is_active')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('is_active', true);
      return (response as List)
          .map((row) {
            final id = row['id']?.toString() ?? '';
            final name = (row['name']?.toString() ?? '').trim();
            final code = (row['code']?.toString() ?? '').trim();
            return {'id': id, 'name': name.isNotEmpty ? name : code};
          })
          .where(
            (e) => (e['id'] ?? '').isNotEmpty && (e['name'] ?? '').isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<String>>> getMemberFunctionsByMinistry(
    String ministryId,
  ) async {
    try {
      final response = await _supabase
          .from('member_function')
          .select(
            'user_id,function_id,ministry_id,ministry_function:function_id(id,name,code)',
          )
          .eq('ministry_id', ministryId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
      final out = <String, List<String>>{};
      for (final row in (response as List)) {
        final uid =
            row['user_id']?.toString() ?? row['member_id']?.toString() ?? '';
        final fn = row['ministry_function'] as Map<String, dynamic>?;
        final name = (fn?['name']?.toString() ?? fn?['code']?.toString() ?? '')
            .trim();
        if (uid.isEmpty || name.isEmpty) continue;
        out.putIfAbsent(uid, () => []);
        if (!out[uid]!.contains(name)) out[uid]!.add(name);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> getUserNamesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return {};
      final response = await _supabase
          .from('user_account')
          .select('id,first_name,last_name,nickname')
          .inFilter('id', ids)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
      final out = <String, String>{};
      for (final row in (response as List)) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final nick = (row['nickname'] ?? row['apelido'] ?? '')
            .toString()
            .trim();
        if (nick.isNotEmpty) {
          out[id] = nick;
        } else {
          final fn = row['first_name']?.toString() ?? '';
          final ln = row['last_name']?.toString() ?? '';
          out[id] = ('$fn $ln').trim();
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> getUserPhotoUrlsByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return {};
      final response = await _supabase
          .from('user_account')
          .select('id,photo_url')
          .inFilter('id', ids)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
      final out = <String, String>{};
      for (final row in (response as List)) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final url = row['photo_url']?.toString() ?? '';
        if (url.trim().isNotEmpty) out[id] = url.trim();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> setMemberFunctionsByMinistry(
    String ministryId,
    Map<String, List<String>> byFunc,
  ) async {
    final catalog = await getFunctionsCatalog();
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

    final nameToId = {
      for (final e in catalog)
        (e['name'] ?? '').toString().trim(): (e['id'] ?? '').toString().trim(),
    };
    final normNameToId = {
      for (final e in catalog)
        norm((e['name'] ?? '').toString()): (e['id'] ?? '').toString().trim(),
    };
    await _supabase
        .from('member_function')
        .delete()
        .eq('ministry_id', ministryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    final rows = <Map<String, dynamic>>[];
    byFunc.forEach((funcName, userIds) {
      final nameKey = funcName.trim();
      String? fid = nameToId[nameKey];
      fid ??= normNameToId[norm(nameKey)];
      if (fid == null || fid.isEmpty) return;
      for (final uid in userIds.where((e) => (e).toString().isNotEmpty)) {
        rows.add({
          'ministry_id': ministryId,
          'user_id': uid,
          'function_id': fid,
          'tenant_id': SupabaseConstants.currentTenantId,
        });
      }
    });
    if (rows.isNotEmpty) {
      await _supabase.from('member_function').insert(rows);
    }
  }
}
