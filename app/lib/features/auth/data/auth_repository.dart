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

