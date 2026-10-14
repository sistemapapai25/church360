import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/worship_service.dart';

/// Repository para gerenciar cultos e presença
class WorshipRepository {
  final SupabaseClient _supabase;

  WorshipRepository(this._supabase);

  // ==================== CULTOS (da Agenda) ====================

  /// Cultos da Agenda (`event` com `event_type` `culto%`) até 2 semanas à
  /// frente, o mais novo primeiro. `start_date` é hora de parede rotulada UTC.
  /// Rascunho some pela RLS de `event`.
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _cultos() {
    final now = DateTime.now();
    final limite = DateTime.utc(now.year, now.month, now.day)
        .add(const Duration(days: 15));
    return _supabase
        .from('event')
        .select(WorshipService.eventSelect)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .like('event_type', 'culto%')
        .lt('start_date', limite.toIso8601String());
  }

  /// Buscar todos os cultos
  Future<List<WorshipService>> getAllWorshipServices() async {
    final response = await _cultos().order('start_date', ascending: false);
    return response.map(WorshipService.fromEvent).toList();
  }

  /// Buscar culto por ID
  Future<WorshipService?> getWorshipServiceById(String id) async {
    final response = await _supabase
        .from('event')
        .select(WorshipService.eventSelect)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return WorshipService.fromEvent(response);
  }

  /// Alias para getWorshipServiceById
  Future<WorshipService?> getServiceById(String id) => getWorshipServiceById(id);

  /// Visitantes presentes por culto (id do culto -> quantidade).
  /// Usa o status atual da pessoa: visitante que virou membro conta como membro.
  Future<Map<String, int>> getVisitorCountByService() async {
    final response = await _supabase
        .from('worship_attendance')
        .select('event_id, user_account:user_id!inner(status)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('user_account.status', 'visitor');

    final counts = <String, int>{};
    for (final row in response as List) {
      final id = row['event_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  // ==================== WORSHIP ATTENDANCE ====================

  /// Buscar presenças de um culto
  Future<List<WorshipAttendance>> getWorshipAttendance(String worshipServiceId) async {
    final response = await _supabase
        .from('worship_attendance')
        .select('''
          *,
          user_account:user_id (
            first_name,
            last_name
          )
        ''')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('event_id', worshipServiceId)
        .order('checked_in_at', ascending: true);

    return (response as List).map((json) {
      final member = json['user_account'];
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
      'event_id': worshipServiceId,
      'user_id': memberId,
      'checked_in_at': DateTime.now().toIso8601String(),
      'tenant_id': SupabaseConstants.currentTenantId,
    };

    final response = await _supabase
        .from('worship_attendance')
        .insert(data)
        .select()
        .single();

    return WorshipAttendance.fromJson(response);
  }

  /// Validar ([ok] = true) ou recusar a presença pelo celular de uma pessoa
  /// (RPC `worship_attendance_validate`, migration 007100, `worship.attendance`).
  /// Recusar apaga a linha geo; a manual se desfaz pelo [checkOut].
  Future<void> validateCheckin(
    String worshipServiceId,
    String memberId, {
    required bool ok,
  }) => _supabase.rpc(
    'worship_attendance_validate',
    params: {'p_event_id': worshipServiceId, 'p_user_id': memberId, 'p_ok': ok},
  );

  /// Remover presença (check-out)
  Future<void> checkOut(String worshipServiceId, String memberId) async {
    await _supabase
        .from('worship_attendance')
        .delete()
        .eq('event_id', worshipServiceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('user_id', memberId);
  }
}
