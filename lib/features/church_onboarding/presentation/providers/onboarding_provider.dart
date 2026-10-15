import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_status.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(Supabase.instance.client);
});

/// Estado dos primeiros passos da igreja atual. Erra com 42501 para quem não
/// tem `church_info.edit`; o card da Dashboard trata isso como "não mostrar".
/// Quem grava (etapa, dores, ministério) invalida este provider.
final onboardingStatusProvider = FutureProvider<OnboardingStatus>((ref) async {
  ref.watch(authStateProvider);
  final supabase = Supabase.instance.client;
  SupabaseConstants.applyTenantHeadersToClient(supabase);
  try {
    await SupabaseConstants.syncTenantFromServer(supabase, syncJwt: false);
  } catch (_) {}
  return ref.watch(onboardingRepositoryProvider).status();
});
