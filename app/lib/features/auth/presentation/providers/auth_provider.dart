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
  final authState = ref.watch(authStateProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  final fromClient = supabase.auth.currentUser ?? supabase.auth.currentSession?.user;
  final fromStream = authState?.session?.user;
  return fromStream ?? fromClient;
});

final resolvedUserEmailProvider = FutureProvider<String?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final localUser = supabase.auth.currentUser ?? supabase.auth.currentSession?.user;
  if (localUser == null) return null;

  final direct = (localUser.email ?? localUser.userMetadata?['email']?.toString() ?? '').trim();
  if (direct.isNotEmpty) return direct;

  try {
    await supabase.auth.refreshSession();
  } catch (_) {}

  try {
    final response = await supabase.auth.getUser();
    final user = response.user;
    final serverEmail = (user?.email ?? user?.userMetadata?['email']?.toString() ?? '').trim();
    if (serverEmail.isNotEmpty) return serverEmail;
  } catch (_) {}

  try {
    final ids = localUser.identities;
    if (ids != null) {
      for (final identity in ids) {
        final v = identity.identityData?['email']?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
  } catch (_) {}

  return null;
});

/// Provider de stream de mudanças de autenticação
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Provider para verificar se está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.isAuthenticated;
});
