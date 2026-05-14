import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministries_repository.dart';
import '../../domain/models/ministry.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';

/// Provider do repository de ministérios
final ministriesRepositoryProvider = Provider<MinistriesRepository>((ref) {
  return MinistriesRepository(Supabase.instance.client);
});

/// Provider de todos os ministérios
final allMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getAllMinistries();
});

/// Provider de ministérios ativos
final activeMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getActiveMinistries();
});

/// Provider de ministério por ID
final ministryByIdProvider = FutureProvider.family<Ministry?, String>((ref, id) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistryById(id);
});

/// Provider de contagem total de ministérios
final totalMinistriesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.countMinistries();
});

/// Provider de contagem de ministérios ativos
final activeMinistriesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.countActiveMinistries();
});

/// Provider de membros de um ministério
final ministryMembersProvider = FutureProvider.family<List<MinistryMember>, String>((ref, ministryId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistryMembers(ministryId);
});

/// Provider de ministérios de um membro
final memberMinistriesProvider = FutureProvider.family<List<Ministry>, String>((ref, memberId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMemberMinistries(memberId);
});

/// Provider de ministérios do membro atual (resolve id correto via cadastro)
final currentMemberMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return [];
  return repo.getMemberMinistries(member.id);
});

/// Provider de escalas de um evento
final eventSchedulesProvider = FutureProvider.family<List<MinistrySchedule>, String>((ref, eventId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getEventSchedules(eventId);
});

/// Provider de escalas de um ministério
final ministrySchedulesProvider = FutureProvider.family<List<MinistrySchedule>, String>((ref, ministryId) async {
  final repo = ref.watch(ministriesRepositoryProvider);
  return repo.getMinistrySchedules(ministryId);
});

/// Indica se o usuário atual tem visão global do hub de ministérios.
///
/// Verdadeiro quando ele tem permissão `ministries.view_all`, `ministries.manage`
/// ou alguma das permissões administrativas históricas (`ministries.create`,
/// `ministries.edit`, `ministries.delete`). Caso contrário, considera-se que o
/// usuário só pode enxergar os ministérios em que está vinculado.
final ministriesCanSeeAllProvider = FutureProvider<bool>((ref) async {
  Future<bool> hasPermission(String code) async {
    final value = await ref.watch(
      currentUserHasPermissionProvider(code).future,
    );
    return value;
  }

  final results = await Future.wait<bool>([
    hasPermission('ministries.view_all'),
    hasPermission('ministries.manage'),
    hasPermission('ministries.create'),
    hasPermission('ministries.edit'),
    hasPermission('ministries.delete'),
  ]);
  return results.any((v) => v);
});

/// Lista de ministérios visíveis para o usuário atual.
///
/// Se o usuário tem visão global retorna todos; caso contrário retorna apenas
/// os ministérios em que ele está vinculado (via `currentMemberMinistriesProvider`).
final visibleMinistriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
  if (canSeeAll) {
    return ref.watch(allMinistriesProvider.future);
  }
  return ref.watch(currentMemberMinistriesProvider.future);
});

/// Indica se o usuário atual pode acessar um ministério específico.
///
/// Útil em route guards: o `true` exige visão global OU vínculo ativo no
/// ministério indicado.
final ministryAccessProvider =
    FutureProvider.family<bool, String>((ref, ministryId) async {
  final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
  if (canSeeAll) return true;
  final mine = await ref.watch(currentMemberMinistriesProvider.future);
  return mine.any((m) => m.id == ministryId);
});

/// Capabilities resolvidas a partir do registro do ministério: tipo e
/// configurações. Útil para decidir qual submódulo abrir (Raízes/Diaconato/...).
final ministryCapabilitiesProvider =
    FutureProvider.family<MinistryCapabilities, String>((ref, ministryId) async {
  final ministry = await ref.watch(ministryByIdProvider(ministryId).future);
  if (ministry == null) {
    return const MinistryCapabilities.empty();
  }
  return MinistryCapabilities(
    ministryType: ministry.ministryType,
    settings: ministry.settings,
  );
});

/// Snapshot imutável das capacidades de um ministério no contexto atual.
class MinistryCapabilities {
  final MinistryType ministryType;
  final Map<String, dynamic> settings;

  const MinistryCapabilities({
    required this.ministryType,
    required this.settings,
  });

  const MinistryCapabilities.empty()
      : ministryType = MinistryType.generic,
        settings = const {};

  bool get isRaizes => ministryType == MinistryType.raizes;
  bool get isDiaconato => ministryType == MinistryType.diaconato;

  /// Rota do submódulo especializado (mesma lógica do `Ministry.specializedRoute`),
  /// preservada aqui para uso em decisões que não têm o objeto Ministry à mão.
  String? specializedRoutePath(String ministryId) {
    switch (ministryType) {
      case MinistryType.raizes:
        return '/ministries/$ministryId/raizes';
      case MinistryType.diaconato:
        return '/ministries/$ministryId/diaconato';
      case MinistryType.generic:
      case MinistryType.kids:
      case MinistryType.louvor:
      case MinistryType.midia:
        return null;
    }
  }
}
