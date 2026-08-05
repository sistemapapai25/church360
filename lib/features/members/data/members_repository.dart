import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/member.dart';

class LgpdDataRequest {
  final String id;
  final String requestType;
  final String status;
  final String? reason;
  final String? resolutionNotes;
  final DateTime? retentionUntil;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;

  const LgpdDataRequest({
    required this.id,
    required this.requestType,
    required this.status,
    this.reason,
    this.resolutionNotes,
    this.retentionUntil,
    this.requestedAt,
    this.resolvedAt,
  });

  factory LgpdDataRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return LgpdDataRequest(
      id: (json['id'] ?? '').toString(),
      requestType: (json['request_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      reason: json['reason']?.toString(),
      resolutionNotes: json['resolution_notes']?.toString(),
      retentionUntil: parseDate(json['retention_until']),
      requestedAt: parseDate(json['requested_at']),
      resolvedAt: parseDate(json['resolved_at']),
    );
  }
}

/// Repository de Membros
/// Responsável por toda comunicação com a tabela 'user_account' no Supabase
class MembersRepository {
  final SupabaseClient _supabase;

  MembersRepository(this._supabase);
  static const List<List<String>> _lgpdStrategies = [
    ['lgpd_consent', 'lgpd_consent_at'],
    ['consentimento_lgpd', 'consentimento_lgpd_at'],
    ['privacy_consent', 'privacy_consent_at'],
  ];

  bool _isMissingColumnError(Object error, [Iterable<String>? columns]) {
    final msg = error.toString().toLowerCase();
    final hasMissingMarker =
        msg.contains('pgrst204') ||
        msg.contains('42703') ||
        msg.contains('does not exist') ||
        msg.contains('column');
    if (!hasMissingMarker) return false;
    if (columns == null || columns.isEmpty) return true;
    return columns.any((column) => msg.contains(column.toLowerCase()));
  }

  bool _isLgpdMissingColumnError(Object error) {
    final allColumns = <String>[
      for (final strategy in _lgpdStrategies) ...strategy,
    ];
    return _isMissingColumnError(error, allColumns);
  }

  Map<String, dynamic> _withoutLgpdFields(Map<String, dynamic> payload) {
    final filtered = Map<String, dynamic>.from(payload);
    for (final strategy in _lgpdStrategies) {
      for (final key in strategy) {
        filtered.remove(key);
      }
    }
    return filtered;
  }

  Map<String, dynamic>? _pickBestMemberRow(List<dynamic> rows) {
    if (rows.isEmpty) return null;

    int statusScore(String? status) {
      switch ((status ?? '').trim()) {
        case 'member_active':
          return 4;
        case 'member_inactive':
          return 3;
        case 'visitor':
          return 1;
        default:
          return 0;
      }
    }

    int rowScore(Map<String, dynamic> r) {
      final isActive = (r['is_active'] == true) ? 1 : 0;
      final status = statusScore(r['status']?.toString());
      final fullName = (r['full_name']?.toString() ?? '').trim().isNotEmpty
          ? 1
          : 0;
      return (isActive * 100) + (status * 10) + fullName;
    }

    Map<String, dynamic> best = Map<String, dynamic>.from(rows.first as Map);
    var bestScore = rowScore(best);
    for (final raw in rows.skip(1)) {
      final r = Map<String, dynamic>.from(raw as Map);
      final score = rowScore(r);
      if (score > bestScore) {
        best = r;
        bestScore = score;
      }
    }
    return best;
  }

  Future<String?> _currentMemberId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc(
          'ensure_my_account',
          params: {
            '_tenant_id': SupabaseConstants.currentTenantId,
            '_email': email,
            '_nickname': nickname,
          },
        );
      } catch (_) {}
    }
    return user.id;
  }

  /// Como [_currentMemberId], mas resolve o `user_account.id` real (via
  /// `auth_user_id`) em vez do `auth.uid()` cru. Necessario para qualquer
  /// coluna `created_by` que referencie `user_account(id)` (a maioria das
  /// tabelas do schema) - usar o auth.uid() cru quebra
  /// user_account_created_by_fkey (e equivalentes) para contas
  /// legadas/reaproveitadas por email, onde id != auth.uid().
  Future<String?> _currentAccountId() async {
    final authId = await _currentMemberId();
    if (authId == null) return null;
    try {
      final resolved = await getMemberByAuthUserId(authId);
      if (resolved != null) return resolved.id;
    } catch (_) {}
    return authId;
  }

  /// Buscar todos os membros (incluindo visitantes)
  Future<List<Member>> getAllMembers() async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('first_name', ascending: true);

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membro por ID
  Future<Member?> getMemberById(String id) async {
    try {
      var response = await _supabase
          .from('user_account')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      response ??= await _supabase
          .from('user_account')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membro por email
  Future<Member?> getMemberByEmail(String email) async {
    try {
      debugPrint('🔍 [MembersRepository] Buscando usuário com email: $email');

      final response = await _supabase
          .from('user_account')
          .select()
          .eq('email', email)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      debugPrint('📦 [MembersRepository] Resposta: $response');

      if (response == null) {
        debugPrint('❌ [MembersRepository] Nenhum usuário encontrado');
        return null;
      }

      final member = Member.fromJson(response);
      debugPrint(
        '✅ [MembersRepository] Usuário encontrado: ${member.firstName} ${member.lastName} (${member.status})',
      );
      return member;
    } catch (e, stackTrace) {
      debugPrint('❌ [MembersRepository] ERRO ao buscar usuário: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Buscar membro por auth_user_id
  Future<Member?> getMemberByAuthUserId(String authUserId) async {
    try {
      Map<String, dynamic>? response;
      try {
        final rows = await _supabase
            .from('user_account')
            .select()
            .eq('auth_user_id', authUserId)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .limit(10);
        if (rows.isNotEmpty) {
          response = _pickBestMemberRow(rows);
        }
      } catch (e) {
        final msg = e.toString();
        final missingAuthUserId =
            msg.contains('auth_user_id') &&
            (msg.contains('PGRST204') ||
                msg.toLowerCase().contains('does not exist') ||
                msg.toLowerCase().contains('column'));
        if (!missingAuthUserId) rethrow;
      }

      if (response == null) {
        try {
          final rows = await _supabase
              .from('user_account')
              .select()
              .eq('auth_user_id', authUserId)
              .limit(10);
          if (rows.isNotEmpty) {
            response = _pickBestMemberRow(rows);
          }
        } catch (_) {}
      }

      response ??= await _supabase
          .from('user_account')
          .select()
          .eq('id', authUserId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      response ??= await _supabase
          .from('user_account')
          .select()
          .eq('id', authUserId)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por status
  Future<List<Member>> getMembersByStatus(String status) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('status', status)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('first_name', ascending: true);

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros ativos
  Future<List<Member>> getActiveMembers() async {
    return getMembersByStatus('member_active');
  }

  /// Buscar visitantes
  Future<List<Member>> getVisitors() async {
    return getMembersByStatus('visitor');
  }

  /// Criar novo membro
  Future<Member> createMember(Member member) async {
    try {
      final payload = {
        ...member.toJson(),
        'tenant_id': SupabaseConstants.currentTenantId,
      };

      final nicknameValue = (payload['nickname'] as String?)?.trim();
      final firstNameValue = (payload['first_name'] as String?)?.trim();
      final fullNameValue = (payload['full_name'] as String?)?.trim();
      final emailValue = (payload['email'] as String?)?.trim();
      payload['nickname'] = (nicknameValue != null && nicknameValue.isNotEmpty)
          ? nicknameValue
          : ((firstNameValue != null && firstNameValue.isNotEmpty)
                ? firstNameValue
                : ((fullNameValue != null && fullNameValue.isNotEmpty)
                      ? fullNameValue.split(' ').first
                      : ((emailValue != null && emailValue.isNotEmpty)
                            ? emailValue.split('@').first
                            : 'Membro')));

      final response = await _supabase
          .from('user_account')
          .insert(payload)
          .select()
          .single();

      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo membro a partir de JSON (sem ID)
  Future<Member> createMemberFromJson(Map<String, dynamic> data) async {
    try {
      final creatorId = await _currentAccountId();
      final nicknameValue = (data['nickname'] as String?)?.trim();
      final firstNameValue = (data['first_name'] as String?)?.trim();
      final fullNameValue = (data['full_name'] as String?)?.trim();
      final emailValue = (data['email'] as String?)?.trim();

      data = {
        ...data,
        'created_by': data['created_by'] ?? creatorId,
        'status': data['status'] ?? 'visitor',
        'id': data['id'] ?? const Uuid().v4(),
        'tenant_id': SupabaseConstants.currentTenantId,
        'nickname': (nicknameValue != null && nicknameValue.isNotEmpty)
            ? nicknameValue
            : ((firstNameValue != null && firstNameValue.isNotEmpty)
                  ? firstNameValue
                  : ((fullNameValue != null && fullNameValue.isNotEmpty)
                        ? fullNameValue.split(' ').first
                        : ((emailValue != null && emailValue.isNotEmpty)
                              ? emailValue.split('@').first
                              : 'Membro'))),
      };

      final response = await _supabase
          .from('user_account')
          .insert(data)
          .select()
          .single();

      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se [childId] é uma criança vinculada a [currentMemberId]/
  /// [currentAuthId] (pai/mãe/tutor), via `created_by` ou
  /// `relacionamentos_familiares` (mesma fonte da verdade usada por
  /// KidsRepository.getManagedChildren e pela política de RLS
  /// `is_linked_child()` no backend). Usado para permitir que um
  /// responsável comum edite o cadastro do próprio filho.
  Future<bool> _isLinkedChild(
    String childId,
    String? currentMemberId,
    String? currentAuthId,
  ) async {
    final candidateIds = <String>{
      if (currentMemberId != null) currentMemberId,
      if (currentAuthId != null) currentAuthId,
    };

    // currentMemberId/currentAuthId acima sao auth.uid() (ver
    // _currentMemberId() e _supabase.auth.currentUser?.id). Mas
    // created_by/relacionamentos_familiares guardam o user_account.id
    // real, que pode divergir do auth.uid() para linhas pre-existentes ou
    // reaproveitadas por email (ensure_my_account "prefer existing" -
    // mesmo padrao ja documentado para isSelfEdit/authUserId acima, so
    // que sem coluna auth_user_id equivalente do lado do filho pra
    // resolver de graca). Resolve o id real via auth_user_id antes de
    // comparar, espelhando currentMemberProvider no client e
    // my_user_account_id() no backend.
    if (currentAuthId != null) {
      try {
        final resolved = await getMemberByAuthUserId(currentAuthId);
        if (resolved != null) candidateIds.add(resolved.id);
      } catch (_) {}
    }

    if (candidateIds.isEmpty) return false;

    try {
      final child = await _supabase
          .from('user_account')
          .select('created_by, member_type')
          .eq('id', childId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();
      if (child == null || child['member_type'] != 'crianca') return false;
      if (candidateIds.contains(child['created_by'])) return true;

      for (final parentId in candidateIds) {
        final direct = await _supabase
            .from('relacionamentos_familiares')
            .select('id')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .eq('membro_id', parentId)
            .eq('parente_id', childId)
            .inFilter('tipo_relacionamento', [
              'filho',
              'filha',
              'tutelado',
              'tutelada',
            ])
            .maybeSingle();
        if (direct != null) return true;

        final reverse = await _supabase
            .from('relacionamentos_familiares')
            .select('id')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .eq('parente_id', parentId)
            .eq('membro_id', childId)
            .inFilter('tipo_relacionamento', ['pai', 'mae', 'tutor', 'tutora'])
            .maybeSingle();
        if (reverse != null) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Atualizar membro
  Future<Member> updateMember(Member member) async {
    try {
      final currentAuthId = _supabase.auth.currentUser?.id;
      final currentMemberId = await _currentMemberId();

      int? accessLevelNumber;
      String? roleGlobal;
      if (currentMemberId != null) {
        try {
          final level = await _supabase
              .from('user_access_level')
              .select('access_level_number')
              .eq('user_id', currentMemberId)
              .maybeSingle();
          accessLevelNumber = level?['access_level_number'] as int?;
        } catch (_) {}

        if (currentAuthId != null) {
          try {
            // id = auth.uid() cobre contas novas; auth_user_id cobre
            // linhas legadas/reaproveitadas por email onde user_account.id
            // diverge do auth.uid() atual (mesmo padrao de
            // my_user_account_id() no backend) - sem isso, um admin nessa
            // situacao seria incorretamente tratado como nao-elevado.
            final rg = await _supabase
                .from('user_account')
                .select('role_global')
                .or('id.eq.$currentAuthId,auth_user_id.eq.$currentAuthId')
                .eq('tenant_id', SupabaseConstants.currentTenantId)
                .limit(1)
                .maybeSingle();
            roleGlobal = rg?['role_global'] as String?;
          } catch (_) {}
        }
      }

      final isElevated =
          (accessLevelNumber ?? 0) >= 3 ||
          (roleGlobal != null &&
              (roleGlobal == 'owner' ||
                  roleGlobal == 'admin' ||
                  roleGlobal == 'leader'));

      final isSelfEdit =
          currentMemberId == member.id || currentAuthId == member.authUserId;

      var isLinkedChildEdit = false;
      if (!isElevated && !isSelfEdit) {
        isLinkedChildEdit = await _isLinkedChild(
          member.id,
          currentMemberId,
          currentAuthId,
        );
      }

      if (!isElevated && !isSelfEdit && !isLinkedChildEdit) {
        throw Exception('Sem permissão para editar este membro');
      }

      final raw = Map<String, dynamic>.from(member.toJson());
      raw.remove('created_at');
      raw.remove('id');

      // created_by e imutavel apos a criacao e nao deve ser tocado num
      // update. O Member montado em MemberFormScreen nunca preenche
      // createdBy, entao um fallback aqui sempre disparava - e o valor
      // (currentMemberId = auth.uid() cru) viola user_account_created_by_fkey
      // (que referencia user_account.id, nao auth.users.id) sempre que o
      // editor logado for uma conta legada com id != auth.uid() (ex.: editar
      // o cadastro de um filho vinculado). Preserva o valor ja existente na
      // linha em vez de sobrescrever.
      raw.remove('created_by');
      if ((raw['email'] as String?)?.trim().isEmpty ?? false) {
        raw.remove('email');
      }

      if (!isElevated) {
        raw.remove('status');
        raw.remove('member_type');
        raw.remove('membership_date');
        raw.remove('baptism_date');
        raw.remove('conversion_date');
        // 'email' é permitido: membro comum só chega aqui editando o
        // próprio cadastro (editar terceiros já lançou exceção acima),
        // e a troca do email de login (Supabase Auth) é feita à parte
        // em MemberFormScreen._saveMember via auth.updateUser().
      }

      final payload = <String, dynamic>{};
      for (final entry in raw.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) continue;
        payload[key] = value;
      }

      Map<String, dynamic>? response;
      try {
        response = await _supabase
            .from('user_account')
            .update(payload)
            .eq('id', member.id)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .select()
            .maybeSingle();
      } catch (e) {
        if (!_isLgpdMissingColumnError(e)) rethrow;
        final fallbackPayload = _withoutLgpdFields(payload);
        response = await _supabase
            .from('user_account')
            .update(fallbackPayload)
            .eq('id', member.id)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .select()
            .maybeSingle();
      }

      if (response != null) {
        return Member.fromJson(response);
      }

      throw Exception(
        'Atualização não aplicada (RLS/sem permissões ou registro não encontrado)',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza consentimento LGPD no `user_account`, com fallback de schema.
  Future<Member> updateLgpdConsent({
    required String memberId,
    required bool consent,
  }) async {
    final consentAt = DateTime.now().toIso8601String();
    Object? lastMissingColumnError;

    for (final strategy in _lgpdStrategies) {
      final payload = <String, dynamic>{
        strategy[0]: consent,
        strategy[1]: consentAt,
      };
      try {
        final response = await _supabase
            .from('user_account')
            .update(payload)
            .eq('id', memberId)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .select()
            .maybeSingle();
        if (response != null) {
          return Member.fromJson(response);
        }
      } catch (e) {
        if (_isMissingColumnError(e, strategy)) {
          lastMissingColumnError = e;
          continue;
        }
        rethrow;
      }
    }

    // Fallback final para manter um sinal mínimo de consentimento em schemas antigos.
    try {
      final response = await _supabase
          .from('user_account')
          .update({'show_contact': consent})
          .eq('id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .maybeSingle();
      if (response != null) {
        final merged = Map<String, dynamic>.from(response);
        merged['lgpd_consent'] = consent;
        merged['lgpd_consent_at'] = consentAt;
        return Member.fromJson(merged);
      }
    } catch (e) {
      if (_isMissingColumnError(e, const ['show_contact'])) {
        if (lastMissingColumnError != null) {
          throw Exception(
            'Não foi possível persistir consentimento LGPD. '
            'Colunas esperadas não encontradas no banco. '
            'Detalhe: $lastMissingColumnError',
          );
        }
      }
      rethrow;
    }

    throw Exception(
      'Não foi possível atualizar o consentimento LGPD (registro não encontrado ou sem permissão).',
    );
  }

  /// Abre uma solicitação de direito do titular (LGPD).
  Future<String> submitLgpdDataRequest({
    required String requestType,
    String? reason,
    DateTime? retentionUntil,
  }) async {
    final response = await _supabase.rpc(
      'submit_lgpd_data_request',
      params: {
        'p_request_type': requestType,
        'p_reason': reason,
        'p_retention_until': retentionUntil?.toIso8601String(),
      },
    );

    final requestId = response?.toString();
    if (requestId == null || requestId.trim().isEmpty) {
      throw Exception('Não foi possível registrar a solicitação LGPD.');
    }
    return requestId;
  }

  /// Lista solicitações LGPD do usuário autenticado.
  Future<List<LgpdDataRequest>> getMyLgpdDataRequests({int limit = 20}) async {
    final response = await _supabase
        .from('lgpd_data_requests')
        .select(
          'id, request_type, status, reason, resolution_notes, retention_until, requested_at, resolved_at',
        )
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('requested_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => LgpdDataRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Lista solicitações LGPD para processamento (uso administrativo).
  Future<List<LgpdDataRequest>> getLgpdDataRequestsForProcessing({
    String? status,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('lgpd_data_requests')
        .select(
          'id, request_type, status, reason, resolution_notes, retention_until, requested_at, resolved_at',
        )
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.eq('status', normalizedStatus);
    }

    final response = await query.order('requested_at', ascending: false).limit(limit);
    return (response as List)
        .map((row) => LgpdDataRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Processa solicitação LGPD (aprovar/rejeitar/concluir/in_review), via RPC com validação no backend.
  Future<void> processLgpdDataRequest({
    required String requestId,
    required String nextStatus,
    String? resolutionNotes,
  }) async {
    await _supabase.rpc(
      'process_lgpd_data_request',
      params: {
        'p_request_id': requestId,
        'p_next_status': nextStatus,
        'p_resolution_notes': resolutionNotes,
      },
    );
  }

  /// Deletar membro
  Future<void> deleteMember(String id) async {
    try {
      // relacionamentos_familiares.membro_id/parente_id sao NOT NULL, mas a
      // FK real no banco e ON DELETE SET NULL - sem essa limpeza previa, o
      // DELETE em user_account tenta zerar essas colunas em cascata e
      // viola o NOT NULL (23502). So remove os vinculos onde o usuario
      // atual e uma das partes (RLS bloqueia o resto silenciosamente, sem
      // lancar erro) - cobre o caso comum (vinculo direto pai/filho).
      try {
        await _supabase
            .from('relacionamentos_familiares')
            .delete()
            .or('membro_id.eq.$id,parente_id.eq.$id');
      } catch (_) {
        // Nao bloquear a exclusao do membro por falha ao limpar vinculos.
      }

      await _supabase
          .from('user_account')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por nome (pesquisa)
  Future<List<Member>> searchMembers(String query) async {
    try {
      final q = query.trim();
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .ilike('full_name', '%$q%')
          .order('first_name', ascending: true);

      final members = (response as List)
          .map((json) => Member.fromJson(json))
          .toList();
      final uniqueById = <String, Member>{};
      for (final m in members) {
        final existing = uniqueById[m.id];
        if (existing == null) {
          uniqueById[m.id] = m;
        } else {
          final hasPhoneExisting = (existing.phone ?? '').trim().isNotEmpty;
          final hasPhoneNew = (m.phone ?? '').trim().isNotEmpty;
          if (!hasPhoneExisting && hasPhoneNew) {
            uniqueById[m.id] = m;
          }
        }
      }
      final deduped = uniqueById.values.toList();
      deduped.sort(
        (a, b) => (a.firstName ?? a.nickname ?? a.fullName ?? '').compareTo(
          b.firstName ?? b.nickname ?? b.fullName ?? '',
        ),
      );
      return deduped;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar membros por status
  Future<int> countMembersByStatus(String status) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('status', status)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de membros
  Future<int> countAllMembers() async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros da mesma família (household)
  Future<List<Member>> getHouseholdMembers(String householdId) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('household_id', householdId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order(
            'birthdate',
            ascending: true,
          ); // Ordenar por idade (mais velho primeiro)

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar profissões por nome (autocomplete)
  Future<List<ProfessionOption>> searchProfessions(String query) async {
    try {
      final q = query.trim();
      if (q.isEmpty) return [];

      try {
        final rpcResponse = await _supabase.rpc(
          'search_profissao',
          params: {'p_query': q},
        );

        if (rpcResponse is List) {
          final codeRegex = RegExp(r'^prof\d{6}$');
          final allOptions = rpcResponse
              .map((raw) {
                final json = Map<String, dynamic>.from(raw as Map);
                final id = (json['id'] ?? json['idprofissao'] ?? '').toString();
                final label = (json['label'] ?? json['profissao'] ?? '')
                    .toString();
                if (id.isEmpty || label.isEmpty) return null;
                return ProfessionOption(id: id, label: label);
              })
              .whereType<ProfessionOption>()
              .toList();

          final coded = allOptions
              .where((o) => codeRegex.hasMatch(o.id))
              .toList();
          final options = coded.isNotEmpty ? coded : allOptions;
          if (options.isNotEmpty) return options.take(20).toList();
        }
      } catch (_) {}

      List<dynamic> response;
      try {
        response = await _supabase
            .from('profissao')
            .select('idprofissao, profissao')
            .ilike('profissao', '%$q%')
            .limit(50);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final missingIdProfissao =
            msg.contains('idprofissao') &&
            (msg.contains('does not exist') || msg.contains('column'));
        if (!missingIdProfissao) rethrow;
        response = await _supabase
            .from('profissao')
            .select('id, profissao')
            .ilike('profissao', '%$q%')
            .limit(50);
      }

      final codeRegex = RegExp(r'^prof\d{6}$');
      final options = response
          .map((raw) {
            final json = raw as Map<String, dynamic>;
            final id = (json['idprofissao'] ?? json['id'] ?? '').toString();
            final label = (json['profissao'] ?? '').toString();
            if (id.isEmpty || label.isEmpty) return null;
            return ProfessionOption(id: id, label: label);
          })
          .whereType<ProfessionOption>()
          .toList();

      final coded = options.where((o) => codeRegex.hasMatch(o.id)).toList();
      final effective = coded.isNotEmpty ? coded : options;

      final deduped = <String, ProfessionOption>{};
      for (final o in effective) {
        deduped[o.id] = o;
      }

      final loweredQuery = q.toLowerCase();
      final sorted = deduped.values.toList()
        ..sort((a, b) {
          final al = a.label.toLowerCase();
          final bl = b.label.toLowerCase();

          final aStarts = al.startsWith(loweredQuery);
          final bStarts = bl.startsWith(loweredQuery);
          if (aStarts != bStarts) return aStarts ? -1 : 1;

          final aIdx = al.indexOf(loweredQuery);
          final bIdx = bl.indexOf(loweredQuery);
          if (aIdx != bIdx) return aIdx.compareTo(bIdx);

          return al.compareTo(bl);
        });

      return sorted.take(20).toList();
    } catch (e) {
      try {
        final q = query.trim();
        if (q.isEmpty) return [];
        List<dynamic> response;
        try {
          response = await _supabase
              .from('profissao')
              .select('idprofissao, profissao')
              .ilike('profissao', '%$q%')
              .limit(50);
        } catch (e) {
          final msg = e.toString().toLowerCase();
          final missingIdProfissao =
              msg.contains('idprofissao') &&
              (msg.contains('does not exist') || msg.contains('column'));
          if (!missingIdProfissao) rethrow;
          response = await _supabase
              .from('profissao')
              .select('id, profissao')
              .ilike('profissao', '%$q%')
              .limit(50);
        }

        final options = response
            .map((raw) {
              final json = raw as Map<String, dynamic>;
              final id = (json['idprofissao'] ?? json['id'] ?? '').toString();
              final label = (json['profissao'] ?? '').toString();
              if (id.isEmpty || label.isEmpty) return null;
              return ProfessionOption(id: id, label: label);
            })
            .whereType<ProfessionOption>()
            .toList();

        final loweredQuery = q.toLowerCase();
        options.sort((a, b) {
          final al = a.label.toLowerCase();
          final bl = b.label.toLowerCase();

          final aStarts = al.startsWith(loweredQuery);
          final bStarts = bl.startsWith(loweredQuery);
          if (aStarts != bStarts) return aStarts ? -1 : 1;

          final aIdx = al.indexOf(loweredQuery);
          final bIdx = bl.indexOf(loweredQuery);
          if (aIdx != bIdx) return aIdx.compareTo(bIdx);

          return al.compareTo(bl);
        });

        return options.take(20).toList();
      } catch (inner) {
        debugPrint('Erro ao buscar profissões: $inner');
        return [];
      }
    }
  }

  /// Buscar aniversariantes do mês atual
  Future<List<Member>> getBirthdaysOfMonth() async {
    try {
      final now = DateTime.now();

      // Supabase não tem filtro de mês direto fácil no client dart sem usar filters específicos
      // Uma abordagem é usar o filtro .filter() com sintaxe postgrest ou buscar todos e filtrar no client (se forem poucos).
      // Mas para ser eficiente, vamos usar uma RPC se existir, ou raw filter.
      // Como não tenho RPC, vou tentar filtrar com query raw se possível ou buscar todos ativos e filtrar aqui (não ideal para muitos usuários).
      // Melhor abordagem: usar .rpc se criar, ou tentar o filter manual.
      // Dado que não posso criar RPC agora sem script, vou usar o filtro de texto na data.
      // Formato data: YYYY-MM-DD.
      // SQL: extract(month from birthdate) = X.
      // Dart client supporta filtros avançados?
      // Vou buscar todos os membros ativos (que costumam ter data de nascimento) e filtrar em memória por enquanto,
      // pois é mais seguro do que tentar adivinhar a sintaxe do Postgrest filter complexo sem testar.
      // O ideal seria criar uma RPC 'get_birthdays_of_month'.

      // Tentativa de filtro mais otimizado: trazer apenas campos necessários
      final response = await _supabase
          .from('user_account')
          .select(
            'id, full_name, nickname, birthdate, photo_url, phone, show_birthday, show_contact',
          )
          .eq('status', 'member_active')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .not('birthdate', 'is', null);

      final members = (response as List)
          .map((json) => Member.fromJson(json))
          .toList();

      return members.where((m) {
        if (m.birthdate == null) return false;
        // Verifica se é o mês atual
        if (m.birthdate!.month != now.month) return false;
        // Verifica privacidade (se show_birthday for false, não mostra - assumindo default true ou false conforme regra)
        // Regra atual: se show_birthday for false, esconde. Se for null, assume true?
        // No Member model, bool? showBirthday.
        if (m.showBirthday == false) return false;

        return true;
      }).toList()..sort((a, b) => a.birthdate!.day.compareTo(b.birthdate!.day));
    } catch (e) {
      debugPrint('Erro ao buscar aniversariantes: $e');
      return [];
    }
  }

  /// Buscar nome da profissão por ID
  Future<String?> getProfessionLabelById(String id) async {
    try {
      // Primeiro tenta pela coluna 'idprofissao' (conforme dados importados)
      final byCode = await _supabase
          .from('profissao')
          .select('profissao')
          .eq('idprofissao', id)
          .maybeSingle();

      if (byCode != null) {
        return byCode['profissao'] as String?;
      }

      // Fallback: tenta pela coluna 'id' caso exista
      try {
        final byId = await _supabase
            .from('profissao')
            .select('profissao')
            .eq('id', id)
            .maybeSingle();
        if (byId != null) {
          return byId['profissao'] as String?;
        }
      } catch (_) {}

      return null;
    } catch (e) {
      try {
        final rpc = await _supabase.rpc(
          'get_profession_label',
          params: {'p_profession_id': id},
        );
        if (rpc is String && rpc.isNotEmpty) return rpc;
      } catch (_) {}
      return null;
    }
  }
}
