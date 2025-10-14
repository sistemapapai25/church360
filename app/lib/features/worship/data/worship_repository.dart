import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/worship_service.dart';

/// Repository para gerenciar cultos e presença
class WorshipRepository {
  final SupabaseClient _supabase;

  WorshipRepository(this._supabase);

  // ==================== WORSHIP SERVICES ====================

  /// Buscar todos os cultos
  Future<List<WorshipService>> getAllWorshipServices() async {
    final response = await _supabase
        .from('worship_service')
        .select()
        .order('service_date', ascending: false);

    return (response as List)
        .map((json) => WorshipService.fromJson(json))
        .toList();
  }

  /// Buscar cultos por período
  Future<List<WorshipService>> getWorshipServicesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('worship_service')
        .select()
        .gte('service_date', startDate.toIso8601String().split('T')[0])
        .lte('service_date', endDate.toIso8601String().split('T')[0])
        .order('service_date', ascending: false);

    return (response as List)
        .map((json) => WorshipService.fromJson(json))
        .toList();
  }

  /// Buscar culto por ID
  Future<WorshipService?> getWorshipServiceById(String id) async {
    final response = await _supabase
        .from('worship_service')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return WorshipService.fromJson(response);
  }

  /// Criar culto
  Future<WorshipService> createWorshipService(Map<String, dynamic> data) async {
    final response = await _supabase
        .from('worship_service')
        .insert(data)
        .select()
        .single();

    return WorshipService.fromJson(response);
  }

  /// Atualizar culto
  Future<WorshipService> updateWorshipService(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _supabase
        .from('worship_service')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return WorshipService.fromJson(response);
  }

  /// Deletar culto
  Future<void> deleteWorshipService(String id) async {
    await _supabase.from('worship_service').delete().eq('id', id);
  }

  /// Contar total de cultos
  Future<int> countWorshipServices() async {
    final response = await _supabase
        .from('worship_service')
        .select()
        .count();

    return response.count;
  }

  // ==================== WORSHIP ATTENDANCE ====================

  /// Buscar presenças de um culto
  Future<List<WorshipAttendance>> getWorshipAttendance(String worshipServiceId) async {
    final response = await _supabase
        .from('worship_attendance')
        .select('''
          *,
          member:member_id (
            first_name,
            last_name
          )
        ''')
        .eq('worship_service_id', worshipServiceId)
        .order('checked_in_at', ascending: true);

    return (response as List).map((json) {
      final member = json['member'];
      final memberName = member != null
          ? '${member['first_name']} ${member['last_name']}'
          : null;

      return WorshipAttendance.fromJson({
        ...json,
        'member_name': memberName,
      });
    }).toList();
  }

  /// Registrar presença (check-in)
  Future<WorshipAttendance> checkIn(String worshipServiceId, String memberId) async {
    final data = {
      'worship_service_id': worshipServiceId,
      'member_id': memberId,
      'checked_in_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('worship_attendance')
        .insert(data)
        .select()
        .single();

    return WorshipAttendance.fromJson(response);
  }

  /// Remover presença (check-out)
  Future<void> checkOut(String worshipServiceId, String memberId) async {
    await _supabase
        .from('worship_attendance')
        .delete()
        .eq('worship_service_id', worshipServiceId)
        .eq('member_id', memberId);
  }

  /// Verificar se membro está presente
  Future<bool> isMemberPresent(String worshipServiceId, String memberId) async {
    final response = await _supabase
        .from('worship_attendance')
        .select()
        .eq('worship_service_id', worshipServiceId)
        .eq('member_id', memberId)
        .maybeSingle();

    return response != null;
  }

  /// Buscar histórico de presença de um membro
  Future<List<WorshipAttendance>> getMemberAttendanceHistory(String memberId) async {
    final response = await _supabase
        .from('worship_attendance')
        .select('''
          *,
          worship_service:worship_service_id (
            service_date,
            service_type,
            theme
          )
        ''')
        .eq('member_id', memberId)
        .order('checked_in_at', ascending: false);

    return (response as List)
        .map((json) => WorshipAttendance.fromJson(json))
        .toList();
  }

  /// Estatísticas de frequência de um membro
  Future<Map<String, dynamic>> getMemberAttendanceStats(String memberId) async {
    // Total de presenças
    final totalResponse = await _supabase
        .from('worship_attendance')
        .select()
        .eq('member_id', memberId)
        .count();

    final totalAttendances = totalResponse.count;

    // Total de cultos nos últimos 3 meses
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final totalServicesResponse = await _supabase
        .from('worship_service')
        .select()
        .gte('service_date', threeMonthsAgo.toIso8601String().split('T')[0])
        .count();

    final totalServices = totalServicesResponse.count;

    // Presenças nos últimos 3 meses
    final recentAttendancesResponse = await _supabase
        .from('worship_attendance')
        .select('*, worship_service:worship_service_id(service_date)')
        .eq('member_id', memberId);

    final recentAttendances = (recentAttendancesResponse as List).where((json) {
      final serviceDate = DateTime.parse(json['worship_service']['service_date']);
      return serviceDate.isAfter(threeMonthsAgo);
    }).length;

    final attendanceRate = totalServices > 0
        ? (recentAttendances / totalServices * 100).round()
        : 0;

    return {
      'total_attendances': totalAttendances,
      'recent_attendances': recentAttendances,
      'total_services_last_3_months': totalServices,
      'attendance_rate': attendanceRate,
    };
  }

  /// Buscar membros ausentes (não compareceram nos últimos X cultos)
  Future<List<String>> getAbsentMembers({int lastServicesCount = 3}) async {
    // Buscar os últimos X cultos
    final recentServices = await _supabase
        .from('worship_service')
        .select('id')
        .order('service_date', ascending: false)
        .limit(lastServicesCount);

    if (recentServices.isEmpty) return [];

    final serviceIds = (recentServices as List)
        .map((s) => s['id'] as String)
        .toList();

    // Buscar todos os membros ativos
    final allMembers = await _supabase
        .from('member')
        .select('id')
        .eq('status', 'member_active');

    final allMemberIds = (allMembers as List)
        .map((m) => m['id'] as String)
        .toSet();

    // Buscar membros que compareceram
    final attendances = await _supabase
        .from('worship_attendance')
        .select('member_id')
        .inFilter('worship_service_id', serviceIds);

    final presentMemberIds = (attendances as List)
        .map((a) => a['member_id'] as String)
        .toSet();

    // Retornar membros ausentes
    return allMemberIds.difference(presentMemberIds).toList();
  }
}

