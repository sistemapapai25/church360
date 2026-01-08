import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

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

      return Ministry.fromJson({
        ...json,
        'member_count': memberCount,
      });
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
        .insert({
          ...data,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return Ministry.fromJson(response);
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

  /// Deletar ministério
  Future<void> deleteMinistry(String id) async {
    await _supabase
        .from('ministry')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
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
            nickname
          )
        ''')
        .eq('ministry_id', ministryId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('role', ascending: true);

    var members = (response as List).map((json) {
      final member = json['user_account'];
      String memberName = '';
      if (member != null) {
        final nick = (member['nickname'] ?? member['apelido'] ?? '').toString().trim();
        if (nick.isNotEmpty) {
          memberName = nick;
        } else {
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          memberName = ('$fn $ln').trim();
        }
      }

      return MinistryMember.fromJson({
        ...json,
        'member_name': memberName,
      });
    }).toList();

    // Fallback: preencher nomes para registros que não retornaram join
    final missing = members.where((m) => (m.memberName).isEmpty).toList();
    if (missing.isNotEmpty) {
      final keys = missing.map((m) => m.memberId).toSet().toList();
      try {
        final details = await _supabase
            .from('user_account')
            .select('id,first_name,last_name,nickname')
            .inFilter('id', keys)
            .eq('tenant_id', SupabaseConstants.currentTenantId);
        final nameById = <String, String>{};
        for (final row in (details as List)) {
          final id = row['id'] as String?;
          if (id != null) {
            final nick = (row['nickname'] ?? row['apelido'] ?? '').toString().trim();
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
            .map((m) => nameById.containsKey(m.memberId)
                ? m.copyWith(memberName: nameById[m.memberId])
                : m)
            .toList();
      } catch (_) {}
    }

    if (members.isEmpty) return members;

    final memberIds = members.map((m) => m.memberId).toList();
    final contexts = await _supabase
        .from('role_contexts')
        .select('id, role_id, metadata, is_active')
        .contains('metadata', {'ministry_id': ministryId})
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true);

    final contextList = (contexts as List).map((e) => e as Map<String, dynamic>).toList();
    if (contextList.isEmpty) return members;

    final contextIds = contextList.map((c) => c['id'] as String).toList();
    final cargoByUser = <String, String>{};

    for (final uid in memberIds) {
      try {
        final resp = await _supabase.rpc(
          'get_user_role_contexts',
          params: {
            'p_user_id': uid,
            'p_role_id': null,
          },
        );
        final items = (resp as List).map((e) => e as Map<String, dynamic>).toList();
        final match = items.firstWhere(
          (it) => contextIds.contains(it['context_id'] as String?),
          orElse: () => {},
        );
        final name = match.isNotEmpty ? match['role_name'] as String? : null;
        if (name != null) {
          cargoByUser[uid] = name;
        }
      } catch (_) {}
    }

    return members
        .map((m) => m.copyWith(cargoName: cargoByUser[m.memberId]))
        .toList();
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
        .insert({
          ...payload,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
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

    return MinistryMember.fromJson({
      ...response,
      'member_name': memberName,
    });
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
      final nick = (member['nickname'] ?? member['apelido'] ?? '').toString().trim();
      if (nick.isNotEmpty) {
        memberName = nick;
      } else {
        final fn = (member['first_name'] ?? '').toString();
        final ln = (member['last_name'] ?? '').toString();
        memberName = ('$fn $ln').trim();
      }
    }

    return MinistryMember.fromJson({
      ...response,
      'member_name': memberName,
    });
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

    return (response as List)
        .map((json) => Ministry.fromJson(json['ministry']))
        .toList();
  }

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
          final nick = (member['nickname'] ?? member['apelido'] ?? '').toString().trim();
          if (nick.isNotEmpty) return nick;
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          return ('$fn $ln').trim();
        })(),
        'function_name': func != null ? (func['name'] ?? func['code'] ?? '') : null,
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
          final nick = (member['nickname'] ?? member['apelido'] ?? '').toString().trim();
          if (nick.isNotEmpty) return nick;
          final fn = (member['first_name'] ?? '').toString();
          final ln = (member['last_name'] ?? '').toString();
          return ('$fn $ln').trim();
        })(),
        'function_name': func != null ? (func['name'] ?? func['code'] ?? '') : null,
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
        .insert({
          ...payload,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
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
      'function_name': func != null ? (func['name'] ?? func['code'] ?? '') : null,
    });
  }

  /// Remover escala
  Future<void> removeSchedule(String id) async {
    await _supabase
        .from('ministry_schedule')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> clearSchedulesForEventMinistry(String eventId, String ministryId) async {
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
      return (response as List).map((row) {
        final id = row['id']?.toString() ?? '';
        final name = (row['name']?.toString() ?? '').trim();
        final code = (row['code']?.toString() ?? '').trim();
        return {
          'id': id,
          'name': name.isNotEmpty ? name : code,
        };
      }).where((e) => (e['id'] ?? '').isNotEmpty && (e['name'] ?? '').isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<String>>> getMemberFunctionsByMinistry(String ministryId) async {
    try {
      final response = await _supabase
          .from('member_function')
          .select('user_id,function_id,ministry_id,ministry_function:function_id(id,name,code)')
          .eq('ministry_id', ministryId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
      final out = <String, List<String>>{};
      for (final row in (response as List)) {
        final uid = row['user_id']?.toString() ?? row['member_id']?.toString() ?? '';
        final fn = row['ministry_function'] as Map<String, dynamic>?;
        final name = (fn?['name']?.toString() ?? fn?['code']?.toString() ?? '').trim();
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
        final nick = (row['nickname'] ?? row['apelido'] ?? '').toString().trim();
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

  Future<void> setMemberFunctionsByMinistry(String ministryId, Map<String, List<String>> byFunc) async {
    try {
      final catalog = await getFunctionsCatalog();
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
      final nameToId = {
        for (final e in catalog) (e['name'] ?? '').toString().trim(): (e['id'] ?? '').toString().trim()
      };
      final normNameToId = {
        for (final e in catalog) norm((e['name'] ?? '').toString()): (e['id'] ?? '').toString().trim()
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
    } catch (_) {}
  }
}
