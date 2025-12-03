import 'package:supabase_flutter/supabase_flutter.dart';

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
        .maybeSingle();

    if (response == null) return null;
    return Ministry.fromJson(response);
  }

  /// Criar ministério
  Future<Ministry> createMinistry(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('ministry')
        .insert(data)
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
        .select()
        .single();

    return Ministry.fromJson(response);
  }

  /// Deletar ministério
  Future<void> deleteMinistry(String id) async {
    await _supabase.from('ministry').delete().eq('id', id);
  }

  /// Contar ministérios
  Future<int> countMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select('id');

    return (response as List).length;
  }

  /// Contar ministérios ativos
  Future<int> countActiveMinistries() async {
    final response = await _supabase
        .from('ministry')
        .select('id')
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
            last_name
          )
        ''')
        .eq('ministry_id', ministryId)
        .order('role', ascending: true);

    var members = (response as List).map((json) {
      final member = json['user_account'];
      final memberName = member != null
          ? '${member['first_name']} ${member['last_name']}'
          : '';

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
            .select('id,first_name,last_name')
            .inFilter('id', keys);
        final nameById = <String, String>{};
        for (final row in (details as List)) {
          final id = row['id'] as String?;
          if (id != null) {
            final fn = row['first_name'] ?? '';
            final ln = row['last_name'] ?? '';
            nameById[id] = '$fn $ln'.trim();
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
        .maybeSingle();
    if (existingUser != null) return true;
    return false;
  }

  /// Adicionar membro ao ministério
  Future<MinistryMember> addMinistryMember(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final response = await _supabase
        .from('ministry_member')
        .insert(payload)
        .select('*')
        .single();

    final String? userKey = response['user_id'] as String?;
    String memberName = '';
    if (userKey != null) {
      final ua = await _supabase
          .from('user_account')
          .select('first_name,last_name')
          .eq('id', userKey)
          .maybeSingle();
      if (ua != null) {
        final fn = ua['first_name'] ?? '';
        final ln = ua['last_name'] ?? '';
        memberName = '$fn $ln'.trim();
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
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .single();

    final member = response['user_account'];
    final memberName = member != null
        ? '${member['first_name']} ${member['last_name']}'
        : '';

    return MinistryMember.fromJson({
      ...response,
      'member_name': memberName,
    });
  }

  /// Remover membro do ministério
  Future<void> removeMinistryMember(String id) async {
    await _supabase.from('ministry_member').delete().eq('id', id);
  }

  /// Buscar ministérios de um membro
  Future<List<Ministry>> getMemberMinistries(String memberId) async {
    final response = await _supabase
        .from('ministry_member')
        .select('''
          ministry:ministry_id (*)
        ''')
        .eq('user_id', memberId);

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
          event:event_id (name),
          ministry:ministry_id (name),
          user_account:user_id (first_name, last_name)
        ''')
        .eq('event_id', eventId)
        .order('ministry_id', ascending: true);

    return (response as List).map((json) {
      final event = json['event'];
      final ministry = json['ministry'];
      final member = json['user_account'];

      return MinistrySchedule.fromJson({
        ...json,
        'event_name': event?['name'] ?? '',
        'ministry_name': ministry?['name'] ?? '',
        'member_name': member != null
            ? '${member['first_name']} ${member['last_name']}'
            : '',
      });
    }).toList();
  }

  /// Buscar escalas de um ministério
  Future<List<MinistrySchedule>> getMinistrySchedules(String ministryId) async {
    final response = await _supabase
        .from('ministry_schedule')
        .select('''
          *,
          event:event_id (name,start_date),
          ministry:ministry_id (name),
          user_account:user_id (first_name, last_name)
        ''')
        .eq('ministry_id', ministryId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final event = json['event'];
      final ministry = json['ministry'];
      final member = json['user_account'];

      return MinistrySchedule.fromJson({
        ...json,
        'event_name': event?['name'] ?? '',
        'event_start_date': event?['start_date'],
        'ministry_name': ministry?['name'] ?? '',
        'member_name': member != null
            ? '${member['first_name']} ${member['last_name']}'
            : '',
      });
    }).toList();
  }

  /// Adicionar escala
  Future<MinistrySchedule> addSchedule(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('ministry_schedule')
        .insert(data)
        .select('''
          *,
          event:event_id (name),
          ministry:ministry_id (name),
          user_account:user_id (first_name, last_name)
        ''')
        .single();

    final event = response['event'];
    final ministry = response['ministry'];
    final member = response['user_account'];

    return MinistrySchedule.fromJson({
      ...response,
      'event_name': event?['name'] ?? '',
      'ministry_name': ministry?['name'] ?? '',
      'member_name': member != null
          ? '${member['first_name']} ${member['last_name']}'
          : '',
    });
  }

  /// Remover escala
  Future<void> removeSchedule(String id) async {
    await _supabase.from('ministry_schedule').delete().eq('id', id);
  }
}
