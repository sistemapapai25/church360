import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';

/// Provider do cliente Supabase
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider do AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(supabase);
});

/// Provider do usuário atual
final currentUserProvider = Provider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.currentUser;
});

/// Provider de stream de mudanças de autenticação
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Provider para verificar se está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.isAuthenticated;
});

