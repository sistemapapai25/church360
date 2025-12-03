import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository de autenticação
/// Responsável por toda comunicação com Supabase Auth
class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

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
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar dados de visitante por email (para auto-preenchimento no signup)
  Future<Map<String, dynamic>?> getVisitorDataByEmail(String email) async {
    try {
      debugPrint('🔍 [AuthRepository] Buscando visitante com email: $email');

      final response = await _supabase
          .from('user_account')
          .select('first_name, last_name, phone, address, city, state, zip_code')
          .eq('email', email)
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
  }) async {
    try {
      // 1. Verificar se já existe um registro com este email em user_account
      final existingUser = await _supabase
          .from('user_account')
          .select('id, email')
          .eq('email', email)
          .maybeSingle();

      // 2. Criar usuário no Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      if (existingUser != null) {
        // 3a. Se já existe registro (visitante cadastrado por líder)
        // Apenas atualizar o ID para vincular ao Auth
        await _supabase.from('user_account').update({
          'id': response.user!.id,
          'is_active': true,
        }).eq('email', email);

        // Verificar se já tem access_level
        final existingAccess = await _supabase
            .from('user_access_level')
            .select('user_id')
            .eq('user_id', response.user!.id)
            .maybeSingle();

        if (existingAccess == null) {
          // Criar access_level se não existir
          await _supabase.from('user_access_level').insert({
            'user_id': response.user!.id,
            'access_level': 'visitor',
            'access_level_number': 0,
          });
        }
      } else {
        // 3b. Se não existe registro, criar novo
        await _supabase.from('user_account').insert({
          'id': response.user!.id,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'full_name': '$firstName $lastName',
          'status': 'visitor',
          'is_active': true,
        });

        // Criar registro na tabela user_access_level
        await _supabase.from('user_access_level').insert({
          'user_id': response.user!.id,
          'access_level': 'visitor',
          'access_level_number': 0,
        });
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
  bool get isAuthenticated => currentSession != null;
}
