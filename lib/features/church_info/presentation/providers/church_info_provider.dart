import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/church_info_repository.dart';
import '../../domain/models/church_info.dart';

/// Provider do repository de informações da igreja
final churchInfoRepositoryProvider = Provider<ChurchInfoRepository>((ref) {
  return ChurchInfoRepository(Supabase.instance.client);
});

/// Provider de informações da igreja
final churchInfoProvider = FutureProvider<ChurchInfo?>((ref) async {
  ref.watch(authStateProvider);
  final supabase = Supabase.instance.client;
  SupabaseConstants.applyTenantHeadersToClient(supabase);
  try {
    await SupabaseConstants.syncTenantFromServer(supabase, syncJwt: false);
  } catch (_) {}
  final repo = ref.watch(churchInfoRepositoryProvider);
  return repo.getChurchInfo();
});
