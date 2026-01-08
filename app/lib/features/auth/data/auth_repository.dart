import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

/// Repository de autenticação
/// Responsável por toda comunicação com Supabase Auth
class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

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
      final fullName = (r['full_name']?.toString() ?? '').trim().isNotEmpty ? 1 : 0;
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

  Future<String?> ensureUserAccountForSession({String? preferredFullName}) async {
    final user = _supabase.auth.currentUser ?? _supabase.auth.currentSession?.user;
    if (user == null) return null;

    final tenantId = SupabaseConstants.currentTenantId;
    final email = (user.email ?? '').trim();
    final metadataName = user.userMetadata?['full_name']?.toString();
    final safeFullName = (preferredFullName ?? metadataName ?? '').trim().isNotEmpty
        ? (preferredFullName ?? metadataName ?? '').trim()
        : (email.isNotEmpty ? email.split('@').first : user.id);
    final metadataNickname = user.userMetadata?['nickname']?.toString();
    final safeNickname = (metadataNickname ?? '').trim().isNotEmpty
        ? (metadataNickname ?? '').trim()
        : (email.isNotEmpty
            ? email.split('@').first
            : (safeFullName.trim().isNotEmpty ? safeFullName.trim().split(' ').first : user.id));

    if (email.isNotEmpty) {
      try {
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': tenantId,
          '_email': email,
          '_full_name': safeFullName,
          '_nickname': safeNickname,
        });
      } catch (_) {}
    }

    Map<String, dynamic>? row;
    var hasAuthUserIdColumn = true;
    var hasTenantIdColumn = true;
    final desiredId = user.id;
    String? selectedId;

    try {
      final rows = await _supabase
          .from('user_account')
          .select('id, auth_user_id, email, full_name, tenant_id, status, is_active')
          .eq('auth_user_id', user.id)
          .eq('tenant_id', tenantId)
          .limit(10);

      if (rows.isNotEmpty) {
        row = _pickBestUserAccountRow(rows);
        selectedId = row?['id']?.toString();
      }
    } catch (e) {
      final msg = e.toString();
      final missingAuthUserId = msg.contains('auth_user_id') &&
          (msg.contains('PGRST204') || msg.toLowerCase().contains('does not exist') || msg.toLowerCase().contains('column'));
      if (missingAuthUserId) {
        hasAuthUserIdColumn = false;
      } else if (msg.contains('tenant_id') &&
          (msg.contains('PGRST204') || msg.toLowerCase().contains('does not exist') || msg.toLowerCase().contains('column'))) {
        hasTenantIdColumn = false;
      } else {
        debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por auth_user_id: $e');
      }
    }

    if (row == null) {
      try {
        var query = _supabase
            .from('user_account')
            .select('id, email, full_name, tenant_id')
            .eq('id', desiredId);
        row = await query.maybeSingle();
        selectedId = row?['id']?.toString();
      } catch (e) {
        final msg = e.toString();
        final missingTenantId = msg.contains('tenant_id') &&
            (msg.contains('PGRST204') || msg.toLowerCase().contains('does not exist') || msg.toLowerCase().contains('column'));
        if (missingTenantId && hasTenantIdColumn) {
          hasTenantIdColumn = false;
          try {
            row = await _supabase
                .from('user_account')
                .select('id, email, full_name')
                .eq('id', desiredId)
                .maybeSingle();
            selectedId = row?['id']?.toString();
          } catch (e2) {
            debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por id: $e2');
          }
        } else {
          debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao buscar por id: $e');
        }
      }
    }

    var userAccountId = selectedId ?? row?['id']?.toString();

    if (userAccountId == null) {
      final payload = <String, dynamic>{
        'id': desiredId,
        'email': email,
        'full_name': safeFullName,
        'nickname': safeNickname,
        'is_active': true,
        'status': 'visitor',
      };
      if (hasTenantIdColumn) payload['tenant_id'] = tenantId;
      if (hasAuthUserIdColumn) payload['auth_user_id'] = user.id;

      try {
        final created = await _supabase.from('user_account').insert(payload).select('id').single();
        userAccountId = created['id']?.toString();
      } catch (e) {
        final msg = e.toString();
        final retry = Map<String, dynamic>.from(payload);
        if (msg.contains('status')) retry.remove('status');
        if (msg.contains('nickname')) retry.remove('nickname');
        if (msg.contains('tenant_id')) retry.remove('tenant_id');
        if (msg.contains('auth_user_id')) retry.remove('auth_user_id');
        try {
          final created = await _supabase.from('user_account').insert(retry).select('id').single();
          userAccountId = created['id']?.toString();
        } catch (e2) {
          debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao inserir user_account: $e2');
          return null;
        }
      }
    } else {
      final updates = <String, dynamic>{};
      final currentEmail = row?['email']?.toString().trim() ?? '';
      final currentFullName = row?['full_name']?.toString().trim() ?? '';
      final currentTenant = row?['tenant_id']?.toString();

      if (email.isNotEmpty && currentEmail.isEmpty) updates['email'] = email;
      if (currentFullName.isEmpty) updates['full_name'] = safeFullName;
      updates['nickname'] = safeNickname;
      if (hasTenantIdColumn && (currentTenant == null || currentTenant.trim().isEmpty)) {
        updates['tenant_id'] = tenantId;
      }
      updates['is_active'] = true;
      if (hasAuthUserIdColumn) updates['auth_user_id'] = user.id;

      if (updates.isNotEmpty) {
        try {
          await _supabase.from('user_account').update(updates).eq('id', userAccountId).select().maybeSingle();
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('nickname')) {
            updates.remove('nickname');
            try {
              await _supabase.from('user_account').update(updates).eq('id', userAccountId).select().maybeSingle();
            } catch (e2) {
              debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao atualizar user_account: $e2');
            }
          } else {
            debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao atualizar user_account: $e');
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
          final missingTenantId = msg.contains('tenant_id') &&
              (msg.contains('PGRST204') || msg.toLowerCase().contains('does not exist') || msg.toLowerCase().contains('column'));
          if (missingTenantId) {
            existing = await _supabase.from('user_access_level').select('user_id').eq('user_id', desiredId).maybeSingle();
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
        debugPrint('❌ [AuthRepository.ensureUserAccountForSession] Erro ao garantir user_access_level: $e');
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
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      try {
        await SupabaseConstants.syncTenantFromServer(_supabase);
      } catch (_) {}
      try {
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_full_name': userFullNameFromEmail(email),
          '_nickname': userFullNameFromEmail(email),
        });
      } catch (e) {
        debugPrint('❌ [AuthRepository.signInWithPassword] ensure_my_account falhou: $e');
      }
      try {
        await ensureUserAccountForSession(preferredFullName: userFullNameFromEmail(email));
      } catch (e) {
        debugPrint('❌ [AuthRepository.signInWithPassword] ensureUserAccountForSession falhou: $e');
      }
      return response;
    } catch (e) {
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
          .select('first_name, last_name, phone, address, city, state, zip_code')
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
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_full_name': '$firstName $lastName',
          '_email': email,
          '_nickname': nickname,
        });
      } catch (e) {
        debugPrint('❌ [AuthRepository.signUp] ensure_my_account falhou: $e');
      }

      final memberId = await ensureUserAccountForSession(preferredFullName: '$firstName $lastName');
      if (memberId != null) {
        try {
          await _supabase
              .from('user_account')
              .update({
                'nickname': nickname,
                'is_active': true,
              })
              .eq('id', memberId)
              .select()
              .maybeSingle();
        } catch (e) {
          debugPrint('❌ [AuthRepository.signUp] update user_account falhou: $e');
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
