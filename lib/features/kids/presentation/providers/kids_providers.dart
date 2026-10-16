import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/kids_repository.dart';
import '../../domain/models/kids_guardian.dart';
import '../../domain/models/kids_token.dart';
import '../../domain/models/kids_child_profile.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Provider do repositório Kids
final kidsRepositoryProvider = Provider<KidsRepository>((ref) {
  return KidsRepository(Supabase.instance.client);
});

/// Provider para buscar crianças gerenciadas pelo usuário logado
/// (alimenta a lista "Meus Filhos" em KidsSelectChildScreen)
final managedChildrenProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final currentMember = await ref.watch(currentMemberProvider.future);
      if (currentMember == null) return [];

      final repository = ref.watch(kidsRepositoryProvider);
      return repository.getManagedChildren(currentMember.id);
    });

/// Provider para listar guardiões de uma criança
final kidsGuardiansProvider = FutureProvider.family<List<KidsAuthorizedGuardian>, String>((ref, childId) async {
  final repository = ref.watch(kidsRepositoryProvider);
  return repository.getGuardians(childId);
});

/// Ficha da criança (saúde, comportamento, imagem)
final kidsChildProfileProvider =
    FutureProvider.autoDispose.family<KidsChildProfile?, String>((ref, childId) {
  return ref.watch(kidsRepositoryProvider).getChildProfile(childId);
});

/// Fichas da igreja por criança (selos na lista da equipe)
final kidsChildProfilesProvider =
    FutureProvider.autoDispose<Map<String, KidsChildProfile>>((ref) {
  return ref.watch(kidsRepositoryProvider).getChildProfiles();
});

/// O usuário é pai/mãe/tutor da criança?
final kidsIsParentProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, childId) {
  return ref.watch(kidsRepositoryProvider).isParentOf(childId);
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
