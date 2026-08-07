import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/kids_guardian.dart';
import '../domain/models/kids_token.dart';
import '../domain/models/kids_attendance.dart';

class KidsRepository {
  final SupabaseClient _supabase;

  KidsRepository(this._supabase);

  bool _isChildRecord(Map<String, dynamic> row) {
    final type = (row['member_type'] ?? '').toString().trim().toLowerCase();
    if (type == 'crianca' || type == 'child') {
      return true;
    }

    final birthdateStr = row['birthdate']?.toString();
    if (birthdateStr == null || birthdateStr.trim().isEmpty) {
      return false;
    }

    try {
      final birth = DateTime.parse(birthdateStr);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age <= 12;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _normalizeChildRecord(
    Map<String, dynamic> row, {
    required String source,
  }) {
    final child = Map<String, dynamic>.from(row);
    child['relationship_source'] = source;

    if (child['full_name'] == null) {
      final firstName = (child['first_name'] ?? '').toString().trim();
      final lastName = (child['last_name'] ?? '').toString().trim();
      final computed = '$firstName $lastName'.trim();
      if (computed.isNotEmpty) {
        child['full_name'] = computed;
      }
    }

    if (child['avatar_url'] == null && child['photo_url'] != null) {
      child['avatar_url'] = child['photo_url'];
    }

    return child;
  }

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
        final child = Map<String, dynamic>.from(
          row['child'] as Map<String, dynamic>,
        );
        return _normalizeChildRecord(child, source: 'guardian');
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

        final householdChildren = (householdResponse as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where(_isChildRecord)
            .map((row) => _normalizeChildRecord(row, source: 'household'))
            .toList();

        allChildren.addAll(householdChildren);
      }
    } catch (e) {
      debugPrint('Erro ao buscar household: $e');
    }

    // 3. Fallback: crianças criadas por este responsável
    try {
      final authId = _supabase.auth.currentUser?.id;
      final creatorIds = <String>{userId};
      if (authId != null && authId.trim().isNotEmpty) {
        creatorIds.add(authId.trim());
      }

      for (final creatorId in creatorIds) {
        final createdResponse = await _supabase
            .from('user_account')
            .select('*')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .eq('created_by', creatorId);

        final createdChildren = (createdResponse as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where(_isChildRecord)
            .map((row) => _normalizeChildRecord(row, source: 'created_by'))
            .toList();
        allChildren.addAll(createdChildren);
      }
    } catch (e) {
      debugPrint('Erro ao buscar crianças por created_by: $e');
    }

    // 4. Buscar crianças via vínculo familiar formal (relacionamentos_familiares)
    // Fonte da verdade para "quem é responsável por essa criança": cobre tanto
    // o vínculo direto (eu -> filho/tutelado) quanto o inverso, gravado quando
    // a relação é criada (ver FamilyRelationshipsRepository._addRelationshipCore).
    try {
      final asParentDirect = await _supabase
          .from('relacionamentos_familiares')
          .select('parente_id')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('membro_id', userId)
          .inFilter('tipo_relacionamento', ['filho', 'filha', 'tutelado', 'tutelada']);

      final asParentReverse = await _supabase
          .from('relacionamentos_familiares')
          .select('membro_id')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('parente_id', userId)
          .inFilter('tipo_relacionamento', ['pai', 'mae', 'tutor', 'tutora']);

      final childIds = <String>{
        ...(asParentDirect as List).map((r) => r['parente_id'] as String),
        ...(asParentReverse as List).map((r) => r['membro_id'] as String),
      };

      if (childIds.isNotEmpty) {
        final childrenResponse = await _supabase
            .from('user_account')
            .select('*')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .inFilter('id', childIds.toList());

        final relationshipChildren = (childrenResponse as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .map(
              (row) =>
                  _normalizeChildRecord(row, source: 'family_relationship'),
            )
            .toList();
        allChildren.addAll(relationshipChildren);
      }
    } catch (e) {
      debugPrint('Erro ao buscar crianças via relacionamentos_familiares: $e');
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
  ///
  /// Resolve nome/foto do guardião via RPC (get_tenant_member_directory) em
  /// vez de embed direto em user_account: a RLS de user_account só libera
  /// leitura de terceiros para papéis elevados, então o embed retornava nulo
  /// para um membro comum mesmo com o vínculo correto no banco.
  Future<List<KidsAuthorizedGuardian>> getGuardians(String childId) async {
    final response = await _supabase
        .from('kids_authorized_guardian')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('child_id', childId);

    final rows = (response as List)
        .map((json) => Map<String, dynamic>.from(json))
        .toList();

    if (rows.isEmpty) return [];

    Map<String, dynamic> directoryById = {};
    try {
      final guardianIds =
          rows.map((r) => r['guardian_id'] as String).toSet().toList();
      final directory = await _supabase.rpc(
        'get_tenant_member_directory',
        params: {'p_ids': guardianIds},
      );
      directoryById = {
        for (final entry in (directory as List))
          (entry as Map)['id'] as String: entry,
      };
    } catch (e) {
      debugPrint('Erro ao buscar diretório de membros: $e');
    }

    return rows.map((data) {
      final guardian = directoryById[data['guardian_id']];
      if (guardian != null) {
        data['guardian_name'] = guardian['full_name'];
        data['guardian_photo'] = guardian['avatar_url'];
      }
      return KidsAuthorizedGuardian.fromJson(data);
    }).toList();
  }

  /// Adicionar guardião
  Future<KidsAuthorizedGuardian> addGuardian(
    KidsAuthorizedGuardian guardian,
  ) async {
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
