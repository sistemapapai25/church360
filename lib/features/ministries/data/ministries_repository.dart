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

    return (response as List).map((json) {
      final member = json['user_account'];
      final memberName = member != null
          ? '${member['first_name']} ${member['last_name']}'
          : '';

      return MinistryMember.fromJson({
        ...json,
        'member_name': memberName,
      });
    }).toList();
  }

  /// Adicionar membro ao ministério
  Future<MinistryMember> addMinistryMember(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('ministry_member')
        .insert(data)
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
          user_account:member_id (first_name, last_name)
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
          event:event_id (name),
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
          member:member_id (first_name, last_name)
        ''')
        .single();

    final event = response['event'];
    final ministry = response['ministry'];
    final member = response['member'];

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

