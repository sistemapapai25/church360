import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/group.dart';

/// Repository para gerenciar grupos
class GroupsRepository {
  final SupabaseClient _supabase;

  GroupsRepository(this._supabase);

  /// Buscar todos os grupos
  Future<List<Group>> getAllGroups() async {
    try {
      final response = await _supabase
          .from('group')
          .select('''
            *,
            leader:member!leader_id(first_name, last_name),
            group_member(count)
          ''')
          .order('name');

      return (response as List).map((json) {
        // Adiciona o nome do líder e contagem de membros
        final data = Map<String, dynamic>.from(json);
        
        if (data['leader'] != null) {
          final leader = data['leader'];
          data['leader_name'] = '${leader['first_name']} ${leader['last_name']}';
        }
        
        if (data['group_member'] != null) {
          data['member_count'] = (data['group_member'] as List).length;
        }
        
        return Group.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar grupos ativos
  Future<List<Group>> getActiveGroups() async {
    try {
      final response = await _supabase
          .from('group')
          .select('''
            *,
            leader:member!leader_id(first_name, last_name),
            group_member(count)
          ''')
          .eq('is_active', true)
          .order('name');

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['leader'] != null) {
          final leader = data['leader'];
          data['leader_name'] = '${leader['first_name']} ${leader['last_name']}';
        }
        
        if (data['group_member'] != null) {
          data['member_count'] = (data['group_member'] as List).length;
        }
        
        return Group.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar grupo por ID
  Future<Group?> getGroupById(String id) async {
    try {
      final response = await _supabase
          .from('group')
          .select('''
            *,
            leader:member!leader_id(first_name, last_name),
            group_member(count)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);
      
      if (data['leader'] != null) {
        final leader = data['leader'];
        data['leader_name'] = '${leader['first_name']} ${leader['last_name']}';
      }
      
      if (data['group_member'] != null) {
        data['member_count'] = (data['group_member'] as List).length;
      }

      return Group.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo grupo
  Future<Group> createGroupFromJson(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('group')
          .insert(data)
          .select()
          .single();

      return Group.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar grupo
  Future<Group> updateGroup(Group group) async {
    try {
      final response = await _supabase
          .from('group')
          .update(group.toJson())
          .eq('id', group.id)
          .select()
          .single();

      return Group.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar grupo
  Future<void> deleteGroup(String id) async {
    try {
      await _supabase.from('group').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Contar grupos
  Future<int> countGroups() async {
    try {
      final response = await _supabase
          .from('group')
          .select()
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar grupos ativos
  Future<int> countActiveGroups() async {
    try {
      final response = await _supabase
          .from('group')
          .select()
          .eq('is_active', true)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  // ========== MEMBROS DO GRUPO ==========

  /// Buscar membros de um grupo
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final response = await _supabase
          .from('group_member')
          .select('''
            *,
            member(first_name, last_name)
          ''')
          .eq('group_id', groupId)
          .order('joined_at');

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['member'] != null) {
          final member = data['member'];
          data['member_name'] = '${member['first_name']} ${member['last_name']}';
        }
        
        return GroupMember.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Adicionar membro ao grupo
  Future<GroupMember> addMemberToGroup({
    required String groupId,
    required String memberId,
    String? role,
  }) async {
    try {
      final response = await _supabase
          .from('group_member')
          .insert({
            'group_id': groupId,
            'member_id': memberId,
            'role': role,
          })
          .select()
          .single();

      return GroupMember.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Remover membro do grupo
  Future<void> removeMemberFromGroup(String groupMemberId) async {
    try {
      await _supabase.from('group_member').delete().eq('id', groupMemberId);
    } catch (e) {
      rethrow;
    }
  }

  // ========== REUNIÕES ==========

  /// Buscar reuniões de um grupo
  Future<List<GroupMeeting>> getGroupMeetings(String groupId) async {
    try {
      final response = await _supabase
          .from('group_meeting')
          .select('''
            *,
            group_attendance(count)
          ''')
          .eq('group_id', groupId)
          .order('meeting_date', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['group_attendance'] != null) {
          data['attendance_count'] = (data['group_attendance'] as List).length;
        }
        
        return GroupMeeting.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Criar reunião
  Future<GroupMeeting> createMeetingFromJson(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('group_meeting')
          .insert(data)
          .select()
          .single();

      return GroupMeeting.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar reunião
  Future<void> deleteMeeting(String meetingId) async {
    try {
      await _supabase.from('group_meeting').delete().eq('id', meetingId);
    } catch (e) {
      rethrow;
    }
  }
}

