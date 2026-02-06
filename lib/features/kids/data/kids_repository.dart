import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/kids_guardian.dart';
import '../domain/models/kids_token.dart';
import '../domain/models/kids_attendance.dart';

class KidsRepository {
  final SupabaseClient _supabase;

  KidsRepository(this._supabase);

  // ==========================================
  // GESTÃO DE CRIANÇAS (PAIS/GUARDIÕES)
  // ==========================================

  /// Listar crianças gerenciadas pelo usuário (Filhos no Household + Guardião autorizado)
  Future<List<Map<String, dynamic>>> getManagedChildren(String userId) async {
    List<Map<String, dynamic>> allChildren = [];

    // 1. Buscar crianças onde sou guardião autorizado
    try {
      final guardiansResponse = await _supabase
          .from('kids_authorized_guardian')
          .select('child:user_account!child_id(*)')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('guardian_id', userId);
      
      final guardianChildren = (guardiansResponse as List).map((row) {
        final child = Map<String, dynamic>.from(row['child'] as Map<String, dynamic>);
        child['relationship_source'] = 'guardian';
        return child;
      }).toList();
      allChildren.addAll(guardianChildren);
    } catch (e) {
      // Ignorar erro se tabela não existir ou permissão falhar (fallback)
      debugPrint('Erro ao buscar guardiões: $e');
    }

    // 2. Buscar meu household_id para encontrar filhos
    try {
      final userResponse = await _supabase
          .from('user_account')
          .select('household_id')
          .eq('id', userId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();
      
      final householdId = userResponse?['household_id'];
      
      if (householdId != null) {
        // Buscar outros membros do household
        final householdResponse = await _supabase
            .from('user_account')
            .select('*')
            .eq('household_id', householdId)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .neq('id', userId);
            
        final householdChildren = (householdResponse as List).where((m) {
           // Filtro: tipo 'crianca' OU idade <= 12
           final type = m['member_type'] ?? '';
           final birthdateStr = m['birthdate'];
           int age = 99;
           if (birthdateStr != null) {
              try {
                final birth = DateTime.parse(birthdateStr);
                final now = DateTime.now();
                age = now.year - birth.year;
                if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
                  age--;
                }
              } catch (_) {}
           }
           
           return type == 'crianca' || age <= 12;
        }).map((m) {
          final data = Map<String, dynamic>.from(m);
          data['relationship_source'] = 'household';
          // Normalizar nome se necessário (member tem first_name, user_account tem full_name)
          if (data['full_name'] == null) {
             data['full_name'] = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
          }
          // Normalizar avatar
          if (data['avatar_url'] == null && data['photo_url'] != null) {
            data['avatar_url'] = data['photo_url'];
          }
          return data;
        }).toList();
        
        allChildren.addAll(householdChildren);
      }
    } catch (e) {
      debugPrint('Erro ao buscar household: $e');
    }

    // Remover duplicatas por ID
    final Map<String, Map<String, dynamic>> uniqueChildren = {};
    for (var child in allChildren) {
      if (child['id'] != null) {
        uniqueChildren[child['id']] = child;
      }
    }

    return uniqueChildren.values.toList();
  }

  // ==========================================
  // GUARDIÕES
  // ==========================================

  /// Listar guardiões de uma criança
  Future<List<KidsAuthorizedGuardian>> getGuardians(String childId) async {
    final response = await _supabase
        .from('kids_authorized_guardian')
        .select('*, guardian:user_account!guardian_id(full_name, avatar_url)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('child_id', childId);

    return (response as List).map((json) {
      final data = Map<String, dynamic>.from(json);
      if (data['guardian'] != null) {
        data['guardian_name'] = data['guardian']['full_name'];
        data['guardian_photo'] = data['guardian']['avatar_url'];
      }
      return KidsAuthorizedGuardian.fromJson(data);
    }).toList();
  }

  /// Adicionar guardião
  Future<KidsAuthorizedGuardian> addGuardian(KidsAuthorizedGuardian guardian) async {
    final response = await _supabase
        .from('kids_authorized_guardian')
        .insert({
          ...guardian.toJson(),
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();
    
    return KidsAuthorizedGuardian.fromJson(response);
  }

  /// Remover guardião
  Future<void> removeGuardian(String guardianId) async {
    await _supabase
        .from('kids_authorized_guardian')
        .delete()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', guardianId);
  }

  // ==========================================
  // TOKENS (QR CODE)
  // ==========================================

  /// Gerar Token de Check-in
  Future<KidsCheckInToken> generateCheckInToken({
    required String childId,
    required String generatedBy,
    String? eventId,
    String type = 'checkin',
    int durationMinutes = 15,
  }) async {
    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));
    
    final response = await _supabase
        .from('kids_checkin_token')
        .insert({
          'child_id': childId,
          'generated_by': generatedBy,
          'event_id': eventId,
          'token_type': type,
          'expires_at': expiresAt.toIso8601String(),
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return KidsCheckInToken.fromJson(response);
  }

  /// Validar Token (Leitura do QR)
  Future<KidsCheckInToken?> validateToken(String token) async {
    final response = await _supabase
        .from('kids_checkin_token')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('token', token)
        .filter('used_at', 'is', null)
        .gt('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();

    if (response == null) return null;
    return KidsCheckInToken.fromJson(response);
  }

  /// Marcar Token como usado
  Future<void> markTokenAsUsed(String token) async {
    await _supabase
        .from('kids_checkin_token')
        .update({'used_at': DateTime.now().toIso8601String()})
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('token', token);
  }

  // ==========================================
  // ATTENDANCE (PRESENÇA)
  // ==========================================

  /// Realizar Check-in
  Future<KidsAttendance> checkIn({
    required String childId,
    required String worshipServiceId,
    required String checkInBy,
    required String checkInTokenId,
  }) async {
    // 1. Marcar token como usado
    await markTokenAsUsed(checkInTokenId);

    // 2. Criar registro de presença
    final response = await _supabase
        .from('kids_attendance')
        .insert({
          'child_id': childId,
          'worship_service_id': worshipServiceId,
          'checkin_by': checkInBy,
          'checkin_token_id': checkInTokenId,
          'checkin_time': DateTime.now().toIso8601String(),
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return KidsAttendance.fromJson(response);
  }

  /// Realizar Check-out
  Future<KidsAttendance> checkOut({
    required String attendanceId,
    required String checkOutBy,
    required String pickedUpBy,
    required String checkOutTokenId,
  }) async {
    // 1. Marcar token como usado
    await markTokenAsUsed(checkOutTokenId);

    // 2. Atualizar registro de presença
    final response = await _supabase
        .from('kids_attendance')
        .update({
          'checkout_time': DateTime.now().toIso8601String(),
          'checkout_by': checkOutBy,
          'picked_up_by': pickedUpBy,
          'checkout_token_id': checkOutTokenId,
        })
        .eq('id', attendanceId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return KidsAttendance.fromJson(response);
  }
}
