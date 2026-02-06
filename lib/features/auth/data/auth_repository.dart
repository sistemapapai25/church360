import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

/// Repository de autenticação
/// Responsável por toda comunicação com Supabase Auth
class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  String? _resolveUserEmail(User user) {
    final direct = user.email?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final meta = user.userMetadata?['email']?.toString().trim();
    if (meta != null && meta.isNotEmpty) return meta;

    try {
      final ids = user.identities;
      if (ids != null) {
        for (final identity in ids) {
          final data = identity.identityData;
          final v = data?['email']?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _resolveUserEmailFromServer() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {}
    try {
      final response = await _supabase.auth.getUser();
      final user = response.user;
      if (user == null) return null;
      return _resolveUserEmail(user);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickBestUserAccountRow(List<dynamic> rows) {
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

  Future<String?> ensureUserAccountForSession({
    String? preferredFullName,
  }) async {
    final user =
        _supabase.auth.currentUser ?? _supabase.auth.currentSession?.user;
    if (user == null) return null;

    final tenantId = SupabaseConstants.currentTenantId;
    var email = (_resolveUserEmail(user) ?? '').trim();
    if (email.isEmpty) {
      final serverEmail = (await _resolveUserEmailFromServer() ?? '').trim();
      if (serverEmail.isNotEmpty) email = serverEmail;
    }
    final String? provisioningEmail = email.isNotEmpty ? email : null;
    bool isPlaceholderEmail(String value) {
      final t = value.trim();
      return t.startsWith('no-email+') && t.endsWith('@church360.local');
    }

    final metadataName = user.userMetadata?['full_name']?.toString();
    final safeFullName =
        (preferredFullName ?? metadataName ?? '').trim().isNotEmpty
        ? (preferredFullName ?? metadataName ?? '').trim()
        : (email.isNotEmpty ? email.split('@').first : user.id);
    final metadataNickname = user.userMetadata?['nickname']?.toString();
    final safeNickname = (metadataNickname ?? '').trim().isNotEmpty
        ? (metadataNickname ?? '').trim()
        : (email.isNotEmpty
              ? email.split('@').first
              : (safeFullName.trim().isNotEmpty
                    ? safeFullName.trim().split(' ').first
                    : user.id));

    try {
      await _supabase.rpc(
        'ensure_my_account',
        params: {
          '_tenant_id': tenantId,
          '_email': provisioningEmail,
          '_full_name': safeFullName,
          '_nickname': safeNickname,
        },
      );
    } catch (_) {}

    Map<String, dynamic>? row;
    var hasAuthUserIdColumn = true;
    var hasTenantIdColumn = true;
    var hasNicknameColumn = true;
    final desiredId = user.id;
    String? selectedId;

    try {
      void pickRowFromRows(List<dynamic> rows) {
        if (rows.isEmpty) return;
        final exact = rows
            .where((e) => (e as Map)['id']?.toString() == desiredId)
            .toList();
        if (exact.isNotEmpty) {
          row = _pickBestUserAccountRow(exact);
        } else if (email.isNotEmpty) {
          final emailMatches = rows
              .where(
                (e) =>
                    ((e as Map)['email']?.toString() ?? '')
                        .trim()
                        .toLowerCase() ==
                    email.toLowerCase(),
              )
              .toList();
          if (emailMatches.isNotEmpty) {
            row = _pickBestUserAccountRow(emailMatches);
          }
        }
        row ??= _pickBestUserAccountRow(rows);
        selectedId = row?['id']?.toString();
      }

      final rows = await _supabase
          .from('user_account')
          .select(
            'id, auth_user_id, email, full_name, tenant_id, status, is_active, nickname',
          )
          .eq('auth_user_id', user.id)
          .eq('tenant_id', tenantId)
          .limit(10);

      pickRowFromRows(rows);
    } catch (e) {
      final msg = e.toString();
      final missingAuthUserId =
          msg.contains('auth_user_id') &&
          (msg.contains('PGRST204') ||
              msg.toLowerCase().contains('does not exist') ||
              msg.toLowerCase().contains('column'));
      final missingNickname =
          msg.contains('nickname') &&
          (msg.contains('PGRST204') ||
              msg.toLowerCase().contains('does not exist') ||
              msg.toLowerCase().contains('column'));
      if (missingAuthUserId) {
        hasAuthUserIdColumn = false;
      } else if (msg.contains('tenant_id') &&
          (msg.contains('PGRST204') ||
              msg.toLowerCase().contains('does not exist') ||
              msg.toLowerCase().contains('column'))) {
        hasTenantIdColumn = false;
      } else if (missingNickname) {
        hasNicknameColumn = false;
        try {
          final rows = await _supabase
              .from('user_account')
              .select(
                'id, auth_user_id, email, full_name, tenant_id, status, is_active',
              )
              .eq('auth_user_id', user.id)
              .eq('tenant_id', tenantId)
              .limit(10);
          if (rows.isNotEmpty) {
            final exact = rows
                .where((e) => (e as Map)['id']?.toString() == desiredId)
                .toList();
            if (exact.isNotEmpty) {
              row = _pickBestUserAccountRow(exact);
            } else if (email.isNotEmpty) {
              final emailMatches = rows
                  .where(
                    (e) =>
                        ((e as Map)['email']?.toString() ?? '')
                            .trim()
                            .toLowerCase() ==
                        email.toLowerCase(),
                  )
                  .toList();
              if (emailMatches.isNotEmpty) {
                row = _pickBestUserAccountRow(emailMatches);
              }
            }
            row ??= _pickBestUserAccountRow(rows);
            selectedId = row?['id']?.toString();
          }
        } catch (_) {}
      } else {
        debugPrint(
          '❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por auth_user_id: $e',
        );
      }
    }

    if (selectedId != null && selectedId != desiredId) {
      row = null;
      selectedId = null;
    }

    if (row == null) {
      try {
        var query = _supabase
            .from('user_account')
            .select(
              'id, email, full_name, tenant_id${hasNicknameColumn ? ', nickname' : ''}',
            )
            .eq('id', desiredId);
        row = await query.maybeSingle();
        selectedId = row?['id']?.toString();
      } catch (e) {
        final msg = e.toString();
        final missingTenantId =
            msg.contains('tenant_id') &&
            (msg.contains('PGRST204') ||
                msg.toLowerCase().contains('does not exist') ||
                msg.toLowerCase().contains('column'));
        final missingNickname =
            msg.contains('nickname') &&
            (msg.contains('PGRST204') ||
                msg.toLowerCase().contains('does not exist') ||
                msg.toLowerCase().contains('column'));
        if (missingNickname && hasNicknameColumn) {
          hasNicknameColumn = false;
          try {
            row = await _supabase
                .from('user_account')
                .select(
                  hasTenantIdColumn
                      ? 'id, email, full_name, tenant_id'
                      : 'id, email, full_name',
                )
                .eq('id', desiredId)
                .maybeSingle();
            selectedId = row?['id']?.toString();
          } catch (_) {}
        }
        if (missingTenantId && hasTenantIdColumn) {
          hasTenantIdColumn = false;
          try {
            row = await _supabase
                .from('user_account')
                .select(
                  'id, email, full_name${hasNicknameColumn ? ', nickname' : ''}',
                )
                .eq('id', desiredId)
                .maybeSingle();
            selectedId = row?['id']?.toString();
          } catch (e2) {
            debugPrint(
              '❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por id: $e2',
            );
          }
        } else {
          debugPrint(
            '❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por id: $e',
          );
        }
      }
    }

    if (row == null && email.isNotEmpty) {
      try {
        final rows = await _supabase
            .from('user_account')
            .select(
              'id, auth_user_id, email, full_name, tenant_id, status, is_active${hasNicknameColumn ? ', nickname' : ''}',
            )
            .eq('email', email)
            .eq('tenant_id', tenantId)
            .limit(10);
        if (rows.isNotEmpty) {
          row = _pickBestUserAccountRow(rows);
          selectedId = row?['id']?.toString();
        }
      } catch (_) {}
    }

    var userAccountId = selectedId ?? row?['id']?.toString();

    if (userAccountId != null && userAccountId != desiredId) {
      row = null;
      selectedId = null;
      userAccountId = null;
    }

    if (userAccountId == null) {
      final payload = <String, dynamic>{
        'id': desiredId,
        'full_name': safeFullName,
        'nickname': safeNickname,
        'is_active': true,
        'status': 'visitor',
      };
      if (provisioningEmail != null) payload['email'] = provisioningEmail;
      if (hasTenantIdColumn) payload['tenant_id'] = tenantId;
      if (hasAuthUserIdColumn) payload['auth_user_id'] = user.id;

      try {
        final created = await _supabase
            .from('user_account')
            .insert(payload)
            .select('id')
            .single();
        userAccountId = created['id']?.toString();
      } catch (e) {
        final msg = e.toString();
        final retry = Map<String, dynamic>.from(payload);
        final lower = msg.toLowerCase();
        final looksLikeEmailRequired =
            lower.contains('email') &&
            (lower.contains('null') ||
                lower.contains('not-null') ||
                lower.contains('not null') ||
                lower.contains('violates'));
        if (looksLikeEmailRequired &&
            (retry['email'] == null ||
                (retry['email']?.toString().trim().isEmpty ?? true))) {
          retry['email'] = 'no-email+${user.id}@church360.local';
        }
        final looksLikeEmailConflict =
            lower.contains('email') && lower.contains('duplicate');
        if (looksLikeEmailConflict) {
          retry['email'] = 'no-email+${user.id}@church360.local';
        }
        if (msg.contains('status')) retry.remove('status');
        if (msg.contains('nickname')) retry.remove('nickname');
        if (msg.contains('tenant_id')) retry.remove('tenant_id');
        if (msg.contains('auth_user_id')) retry.remove('auth_user_id');
        try {
          final created = await _supabase
              .from('user_account')
              .insert(retry)
              .select('id')
              .single();
          userAccountId = created['id']?.toString();
        } catch (e2) {
          debugPrint(
            '❌ [AuthRepository.ensureUserAccountForSession] Erro ao inserir user_account: $e2',
          );
          return null;
        }
      }
    } else {
      final updates = <String, dynamic>{};
      final currentEmail = row?['email']?.toString().trim() ?? '';
      final currentFullName = row?['full_name']?.toString().trim() ?? '';
      final currentNickname = row?['nickname']?.toString().trim() ?? '';
      final currentTenant = row?['tenant_id']?.toString();

      if (email.isNotEmpty &&
          (currentEmail.isEmpty || isPlaceholderEmail(currentEmail))) {
        updates['email'] = email;
      }
      if (currentFullName.isEmpty) updates['full_name'] = safeFullName;
      if (hasNicknameColumn && currentNickname.isEmpty) {
        updates['nickname'] = safeNickname;
      }
      if (hasTenantIdColumn &&
          (currentTenant == null || currentTenant.trim().isEmpty)) {
        updates['tenant_id'] = tenantId;
      }
      updates['is_active'] = true;
      if (hasAuthUserIdColumn) updates['auth_user_id'] = user.id;

      if (updates.isNotEmpty) {
        try {
          await _supabase
              .from('user_account')
              .update(updates)
              .eq('id', userAccountId)
              .select()
              .maybeSingle();
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('nickname')) {
            updates.remove('nickname');
            try {
              await _supabase
                  .from('user_account')
                  .update(updates)
                  .eq('id', userAccountId)
                  .select()
                  .maybeSingle();
            } catch (e2) {
              debugPrint(
                '❌ [AuthRepository.ensureUserAccountForSession] Erro ao atualizar user_account: $e2',
              );
            }
          } else {
            debugPrint(
              '❌ [AuthRepository.ensureUserAccountForSession] Erro ao atualizar user_account: $e',
            );
          }
        }
      }
    }

    if (userAccountId != null) {
      try {
        Map<String, dynamic>? existing;
        try {
          existing = await _supabase
              .from('user_access_level')
              .select('user_id, tenant_id')
              .eq('user_id', desiredId)
              .eq('tenant_id', tenantId)
              .maybeSingle();
        } catch (e) {
          final msg = e.toString();
          final missingTenantId =
              msg.contains('tenant_id') &&
              (msg.contains('PGRST204') ||
                  msg.toLowerCase().contains('does not exist') ||
                  msg.toLowerCase().contains('column'));
          if (missingTenantId) {
            existing = await _supabase
                .from('user_access_level')
                .select('user_id')
                .eq('user_id', desiredId)
                .maybeSingle();
          } else {
            rethrow;
          }
        }
        if (existing == null) {
          final accessLevelPayload = <String, dynamic>{
            'user_id': desiredId,
            'access_level': 'visitor',
            'access_level_number': 0,
          };
          accessLevelPayload['tenant_id'] = tenantId;
          await _supabase.from('user_access_level').insert(accessLevelPayload);
        }
      } catch (e) {
        debugPrint(
          '❌ [AuthRepository.ensureUserAccountForSession] Erro ao garantir user_access_level: $e',
        );
      }
    }

    return userAccountId;
  }

  /// Login com email e senha
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint(
        '[Auth] signInWithPassword start email=${email.trim()} tenant=${SupabaseConstants.currentTenantId}',
      );
      debugPrint('[Auth] supabase url=${SupabaseConstants.supabaseUrl}');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      try {
        await SupabaseConstants.syncTenantFromServer(_supabase);
      } catch (_) {}
      try {
        await _supabase.rpc(
          'ensure_my_account',
          params: {
            '_tenant_id': SupabaseConstants.currentTenantId,
            '_email': email,
            '_full_name': userFullNameFromEmail(email),
            '_nickname': userFullNameFromEmail(email),
          },
        );
      } catch (e) {
        debugPrint(
          '❌ [AuthRepository.signInWithPassword] ensure_my_account falhou: $e',
        );
      }
      try {
        await ensureUserAccountForSession(
          preferredFullName: userFullNameFromEmail(email),
        );
      } catch (e) {
        debugPrint(
          '❌ [AuthRepository.signInWithPassword] ensureUserAccountForSession falhou: $e',
        );
      }
      return response;
    } catch (e) {
      debugPrint(
        '[Auth] signInWithPassword failed type=${e.runtimeType} error=$e',
      );
      if (e is AuthApiException) {
        debugPrint(
          '[Auth] status=${e.statusCode} code=${e.code} message=${e.message}',
        );
      } else if (e is AuthException) {
        debugPrint('[Auth] auth_exception message=${e.message}');
      }
      rethrow;
    }
  }

  String userFullNameFromEmail(String email) {
    final clean = email.trim();
    if (clean.isEmpty) return '';
    return clean.split('@').first;
  }

  /// Buscar dados de visitante por email (para auto-preenchimento no signup)
  Future<Map<String, dynamic>?> getVisitorDataByEmail(String email) async {
    try {
      debugPrint('🔍 [AuthRepository] Buscando visitante com email: $email');

      final response = await _supabase
          .from('user_account')
          .select(
            'first_name, last_name, phone, address, city, state, zip_code',
          )
          .eq('email', email)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('status', 'visitor')
          .maybeSingle();

      debugPrint('📦 [AuthRepository] Resposta do Supabase: $response');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ [AuthRepository] ERRO ao buscar visitante: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Registro de novo usuário
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String nickname,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'tenant_id': SupabaseConstants.currentTenantId,
          'full_name': '$firstName $lastName',
        },
      );

      if (response.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      try {
        await SupabaseConstants.syncTenantFromServer(_supabase);
      } catch (_) {}

      try {
        await _supabase.rpc(
          'ensure_my_account',
          params: {
            '_tenant_id': SupabaseConstants.currentTenantId,
            '_full_name': '$firstName $lastName',
            '_email': email,
            '_nickname': nickname,
          },
        );
      } catch (e) {
        debugPrint('❌ [AuthRepository.signUp] ensure_my_account falhou: $e');
      }

      final memberId = await ensureUserAccountForSession(
        preferredFullName: '$firstName $lastName',
      );
      if (memberId != null) {
        try {
          await _supabase
              .from('user_account')
              .update({'nickname': nickname, 'is_active': true})
              .eq('id', memberId)
              .select()
              .maybeSingle();
        } catch (e) {
          debugPrint(
            '❌ [AuthRepository.signUp] update user_account falhou: $e',
          );
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Usuário atual
  User? get currentUser => _supabase.auth.currentUser;

  /// Sessão atual
  Session? get currentSession => _supabase.auth.currentSession;

  /// Stream de mudanças de autenticação
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Verificar se está autenticado
  bool get isAuthenticated => currentSession != null || currentUser != null;
}
