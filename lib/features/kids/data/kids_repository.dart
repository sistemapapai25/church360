import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/kids_guardian.dart';
import '../domain/models/kids_token.dart';
import '../domain/models/kids_checkin.dart';
import '../domain/models/kids_child_profile.dart';

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

      // `whereType` em vez de `as String`: as duas colunas são nullable no
      // banco e a FK para `user_account` é SET NULL, então excluir a ficha
      // de alguém deixa a linha do vínculo com um dos lados vazio. Um cast
      // aqui estourava dentro do `try` e o `catch` abaixo engolia a busca
      // inteira — o responsável perdia TODAS as crianças da lista por causa
      // de uma linha órfã de outra família.
      final childIds = <String>{
        ...(asParentDirect as List).map((r) => r['parente_id']).whereType<String>(),
        ...(asParentReverse as List).map((r) => r['membro_id']).whereType<String>(),
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
  // FICHA DA CRIANÇA (saúde, comportamento, imagem)
  // ==========================================

  /// Ficha de uma criança; `null` se ainda não foi preenchida ou se a RLS
  /// não deixa ver (só equipe do Infantil, pais e responsáveis).
  Future<KidsChildProfile?> getChildProfile(String childId) async {
    final response = await _supabase
        .from('kids_child_profile')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('child_id', childId)
        .maybeSingle();
    return response == null ? null : KidsChildProfile.fromJson(response);
  }

  /// Fichas visíveis da igreja, por criança (selos da lista da equipe).
  Future<Map<String, KidsChildProfile>> getChildProfiles() async {
    final response = await _supabase
        .from('kids_child_profile')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    return {
      for (final row in response as List)
        (row as Map)['child_id'] as String:
            KidsChildProfile.fromJson(Map<String, dynamic>.from(row)),
    };
  }

  /// Pai/mãe/tutor da criança (só ele dá a autorização de imagem).
  Future<bool> isParentOf(String childId) async {
    final result = await _supabase.rpc(
      'kids_is_parent',
      params: {
        'p_tenant': SupabaseConstants.currentTenantId,
        'p_child': childId,
      },
    );
    return result == true;
  }

  /// Grava a ficha. `imageConsent` nulo não mexe na autorização de imagem.
  Future<void> saveChildProfile({
    required String childId,
    String? allergies,
    String? intolerances,
    String? medications,
    String? specialNeeds,
    String? behaviorProfile,
    String? notes,
    bool? imageConsent,
  }) async {
    await _supabase.rpc(
      'kids_save_child_profile',
      params: {
        'p_child': childId,
        'p_allergies': allergies,
        'p_intolerances': intolerances,
        'p_medications': medications,
        'p_special_needs': specialNeeds,
        'p_behavior_profile': behaviorProfile,
        'p_notes': notes,
        'p_image_consent': imageConsent,
      },
    );
  }

  // ==========================================
  // QR DOS PAIS
  // ==========================================

  /// Gera o QR de check-in (15 min). A RPC grava `generated_by` com o
  /// `user_account.id` de quem gera (o auth.uid é outro id em metade das
  /// contas e quebrava a FK).
  Future<KidsCheckInToken> generateCheckInToken(String childId) async {
    final response = await _supabase.rpc(
      'kids_new_token',
      params: {'p_child': childId},
    );
    return KidsCheckInToken.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Código de retirada (KOUT) do check-in aberto da criança; null se ela
  /// não está na sala. Só quem pode retirá-la recebe (RPC).
  Future<Map<String, dynamic>?> getCheckoutCode(String childId) async {
    final response = await _supabase.rpc(
      'kids_my_checkout_code',
      params: {'p_child': childId},
    );
    return response == null ? null : Map<String, dynamic>.from(response as Map);
  }

  // ==========================================
  // BALCÃO (check-in/check-out pela equipe do Infantil)
  // ==========================================

  /// A pessoa logada é da equipe do Infantil (kids.manage ou serve num
  /// ministério do tipo 'infantil')?
  Future<bool> isTeam() async {
    final result = await _supabase.rpc(
      'kids_is_team',
      params: {'p_tenant': SupabaseConstants.currentTenantId},
    );
    return result == true;
  }

  /// Culto de hoje + crianças na sala agora.
  Future<KidsBoard> getBoard() async {
    final result = await _supabase.rpc('kids_board');
    return KidsBoard.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<KidsChildCard>> searchChildren(String query) async {
    final result = await _supabase.rpc(
      'kids_search_children',
      params: {'p_query': query},
    );
    return [
      for (final row in result as List)
        KidsChildCard.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Lê o QR sem gastar o código.
  Future<KidsChildCard> scan(String token) async {
    final result = await _supabase.rpc('kids_scan', params: {'p_token': token});
    return KidsChildCard.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Check-in pelo QR ([token]) ou pelo nome ([childId]). Sem [roomId], a
  /// sala sai pela idade.
  Future<KidsChildCard> checkIn({
    String? token,
    String? childId,
    String? roomId,
  }) async {
    final result = await _supabase.rpc(
      'kids_checkin',
      params: {'p_token': token, 'p_child': childId, 'p_room': roomId},
    );
    return KidsChildCard.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Quem pode retirar a criança deste check-in.
  Future<List<KidsPicker>> getCheckoutOptions(String attendanceId) async {
    final result = await _supabase.rpc(
      'kids_checkout_options',
      params: {'p_attendance': attendanceId},
    );
    return [
      for (final row in result as List)
        KidsPicker.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> checkOut({
    required String attendanceId,
    required String pickedUpBy,
    String? token,
  }) async {
    await _supabase.rpc(
      'kids_checkout',
      params: {
        'p_attendance': attendanceId,
        'p_picked_up_by': pickedUpBy,
        'p_token': token,
      },
    );
  }

  /// Chama o responsável (push aos pais e à Mídia). Cartilha §7.2.
  Future<KidsCallResult> callGuardian(String attendanceId, String? reason) async {
    final result = await _supabase.rpc(
      'kids_call_guardian',
      params: {'p_attendance': attendanceId, 'p_reason': reason},
    );
    return KidsCallResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Relatório do Infantil (K8): últimos [days] dias de check-in.
  Future<Map<String, dynamic>> getReport({int days = 90}) async {
    final result = await _supabase.rpc('kids_report', params: {'p_days': days});
    return Map<String, dynamic>.from(result as Map);
  }

  /// Aula do culto de hoje (K7); `null` se ainda não foi registrada.
  Future<Map<String, dynamic>?> getTodayLesson() async {
    final result = await _supabase.rpc('kids_today_lesson');
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }

  /// Grava a aula de hoje; com [notify], avisa os pais das crianças com
  /// check-in. Devolve quantos responsáveis foram avisados.
  Future<int> saveLesson({
    required String theme,
    String? verse,
    String? activity,
    bool notify = false,
  }) async {
    final result = await _supabase.rpc(
      'kids_save_lesson',
      params: {
        'p_theme': theme,
        'p_verse': verse,
        'p_activity': activity,
        'p_notify': notify,
      },
    );
    return ((result as Map)['notified'] as num?)?.toInt() ?? 0;
  }

  /// Aulas dos cultos em que a criança esteve (pais e equipe).
  Future<List<Map<String, dynamic>>> getChildLessons(String childId) async {
    final result = await _supabase.rpc(
      'kids_child_lessons',
      params: {'p_child': childId},
    );
    return [
      for (final row in result as List) Map<String, dynamic>.from(row as Map),
    ];
  }

  // ==========================================
  // SALAS
  // ==========================================

  Future<List<KidsRoom>> getRooms() async {
    final response = await _supabase
        .from('kids_room')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('sort_order')
        .order('name');
    return [
      for (final row in response as List)
        KidsRoom.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> saveRoom(KidsRoom room) async {
    await _supabase.rpc(
      'kids_save_room',
      params: {
        'p_id': room.id,
        'p_name': room.name,
        'p_min_age': room.minAge,
        'p_max_age': room.maxAge,
        'p_active': room.isActive,
        'p_sort': room.sortOrder,
      },
    );
  }
}
