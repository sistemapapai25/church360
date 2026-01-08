import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/group_meeting.dart';

/// Provider do repositório de reuniões de grupos
final groupMeetingsRepositoryProvider = Provider<GroupMeetingsRepository>((ref) {
  return GroupMeetingsRepository(Supabase.instance.client);
});

/// Repositório de reuniões de grupos
class GroupMeetingsRepository {
  final SupabaseClient _supabase;

  GroupMeetingsRepository(this._supabase);

  /// Buscar todas as reuniões de um grupo
  Future<List<GroupMeeting>> getGroupMeetings(String groupId) async {
    try {
      final response = await _supabase
          .from('group_meeting')
          .select()
          .eq('group_id', groupId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('meeting_date', ascending: false);

      return (response as List).map((data) => GroupMeeting.fromJson(data)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar reunião por ID
  Future<GroupMeeting?> getMeetingById(String id) async {
    try {
      final response = await _supabase
          .from('group_meeting')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return GroupMeeting.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar reunião
  Future<GroupMeeting> createMeeting(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['tenant_id'] = payload['tenant_id'] ?? SupabaseConstants.currentTenantId;
      final response = await _supabase
          .from('group_meeting')
          .insert(payload)
          .select()
          .single();

      return GroupMeeting.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar reunião
  Future<GroupMeeting> updateMeeting(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('group_meeting')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return GroupMeeting.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar reunião
  Future<void> deleteMeeting(String id) async {
    try {
      await _supabase
          .from('group_meeting')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar presenças de uma reunião
  Future<List<GroupAttendance>> getMeetingAttendances(String meetingId) async {
    try {
      final response = await _supabase
          .from('group_attendance')
          .select('''
            *,
            user_account:user_id (
              first_name,
              last_name
            )
          ''')
          .eq('meeting_id', meetingId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: true);

      return (response as List).map((data) {
        final attendanceData = Map<String, dynamic>.from(data);

        // Adicionar nome do membro
        if (attendanceData['user_account'] != null) {
          final member = attendanceData['user_account'];
          attendanceData['member_name'] = '${member['first_name']} ${member['last_name']}';
        }

        return GroupAttendance.fromJson(attendanceData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Registrar presença
  Future<GroupAttendance> recordAttendance(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['tenant_id'] = payload['tenant_id'] ?? SupabaseConstants.currentTenantId;
      final response = await _supabase
          .from('group_attendance')
          .insert(payload)
          .select()
          .single();

      return GroupAttendance.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar presença
  Future<GroupAttendance> updateAttendance(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('group_attendance')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return GroupAttendance.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar presença
  Future<void> deleteAttendance(String id) async {
    try {
      await _supabase
          .from('group_attendance')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar total de presença da reunião
  Future<void> updateMeetingAttendanceCount(String meetingId) async {
    try {
      // Contar presenças
      final attendances = await getMeetingAttendances(meetingId);
      final presentCount = attendances.where((a) => a.wasPresent).length;

      // Atualizar total
      await _supabase
          .from('group_meeting')
          .update({'total_attendance': presentCount})
          .eq('id', meetingId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar estatísticas de frequência de um membro em um grupo
  Future<Map<String, dynamic>> getMemberAttendanceStats(
    String groupId,
    String memberId,
  ) async {
    try {
      // Buscar todas as reuniões do grupo
      final meetings = await getGroupMeetings(groupId);
      
      if (meetings.isEmpty) {
        return {
          'total_meetings': 0,
          'attended': 0,
          'missed': 0,
          'attendance_rate': 0.0,
        };
      }

      // Buscar presenças do membro
      final response = await _supabase
          .from('group_attendance')
          .select('was_present, meeting_id')
          .eq('user_id', memberId)
          .inFilter('meeting_id', meetings.map((m) => m.id).toList())
          .eq('tenant_id', SupabaseConstants.currentTenantId);

      final attendances = response as List;
      final attended = attendances.where((a) => a['was_present'] == true).length;
      final totalMeetings = meetings.length;
      final missed = totalMeetings - attended;
      final attendanceRate = totalMeetings > 0 ? (attended / totalMeetings) * 100 : 0.0;

      return {
        'total_meetings': totalMeetings,
        'attended': attended,
        'missed': missed,
        'attendance_rate': attendanceRate,
      };
    } catch (e) {
      rethrow;
    }
  }
}
