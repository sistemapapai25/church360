import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/kids_repository.dart';
import '../../domain/models/kids_guardian.dart';
import '../../domain/models/kids_token.dart';

/// Provider do repositório Kids
final kidsRepositoryProvider = Provider<KidsRepository>((ref) {
  return KidsRepository(Supabase.instance.client);
});

/// Provider para listar guardiões de uma criança
final kidsGuardiansProvider = FutureProvider.family<List<KidsAuthorizedGuardian>, String>((ref, childId) async {
  final repository = ref.watch(kidsRepositoryProvider);
  return repository.getGuardians(childId);
});

/// Provider para gerar token de check-in (QR Code)
final kidsCheckInTokenProvider = FutureProvider.family<KidsCheckInToken, ({String childId, String generatedBy, String? eventId})>((ref, params) async {
  final repository = ref.watch(kidsRepositoryProvider);
  return repository.generateCheckInToken(
    childId: params.childId,
    generatedBy: params.generatedBy,
    eventId: params.eventId,
  );
});
