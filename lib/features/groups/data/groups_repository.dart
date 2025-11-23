import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/group.dart';
import '../domain/models/group_visitor.dart';

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
            host:member!host_id(first_name, last_name),
            group_member(count)
          ''')
          .order('name');

      return (response as List).map((json) {
        // Adiciona o nome do líder, anfitrião e contagem de membros
        final data = Map<String, dynamic>.from(json);

        if (data['leader'] != null) {
          final leader = data['leader'];
          data['leader_name'] = '${leader['first_name']} ${leader['last_name']}';
        }

        if (data['host'] != null) {
          final host = data['host'];
          data['host_name'] = '${host['first_name']} ${host['last_name']}';
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
            host:member!host_id(first_name, last_name),
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

        if (data['host'] != null) {
          final host = data['host'];
          data['host_name'] = '${host['first_name']} ${host['last_name']}';
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
            host:member!host_id(first_name, last_name),
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

      if (data['host'] != null) {
        final host = data['host'];
        data['host_name'] = '${host['first_name']} ${host['last_name']}';
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
          .order('joined_date');

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
  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    try {
      await _supabase
          .from('group_member')
          .delete()
          .eq('group_id', groupId)
          .eq('member_id', memberId);
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

  // =====================================================
  // VISITANTES
  // =====================================================

  /// Buscar visitantes de uma reunião
  Future<List<GroupVisitor>> getVisitorsByMeeting(String meetingId) async {
    try {
      final response = await _supabase
          .from('visitor')
          .select('''
            *,
            mentor:member!assigned_mentor_id(first_name, last_name)
          ''')
          .eq('meeting_id', meetingId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => GroupVisitor.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar visitantes que são salvações (para relatórios)
  Future<List<GroupVisitor>> getSalvationsByMeeting(String meetingId) async {
    try {
      final response = await _supabase
          .from('visitor')
          .select('''
            *,
            mentor:member!assigned_mentor_id(first_name, last_name)
          ''')
          .eq('meeting_id', meetingId)
          .eq('is_salvation', true)
          .order('salvation_date', ascending: false);

      return (response as List)
          .map((json) => GroupVisitor.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar todas as salvações (para relatórios gerais)
  Future<List<GroupVisitor>> getAllSalvations() async {
    try {
      final response = await _supabase
          .from('visitor')
          .select('''
            *,
            mentor:member!assigned_mentor_id(first_name, last_name)
          ''')
          .eq('is_salvation', true)
          .order('salvation_date', ascending: false);

      return (response as List)
          .map((json) => GroupVisitor.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Contar salvações
  Future<int> countSalvations() async {
    try {
      final response = await _supabase
          .from('visitor')
          .select()
          .eq('is_salvation', true)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Criar visitante
  Future<GroupVisitor> createVisitor(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('visitor')
          .insert(data)
          .select()
          .single();

      return GroupVisitor.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar visitante
  Future<GroupVisitor> updateVisitor(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('visitor')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return GroupVisitor.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar visitante
  Future<void> deleteVisitor(String id) async {
    try {
      await _supabase.from('visitor').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Contar salvações por período (usando group_visitor)
  Future<int> countSalvationsByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('group_visitor')
          .select()
          .eq('is_salvation', true)
          .gte('salvation_date', startDate.toIso8601String().split('T')[0])
          .lte('salvation_date', endDate.toIso8601String().split('T')[0])
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }
}

