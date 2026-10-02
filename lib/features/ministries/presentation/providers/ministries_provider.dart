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

// CHU-384 (29/09/2026): aqui existia `currentUserIsMinistryCoordinatorProvider`,
// que respondia se a pessoa era `coordinator` de algum ministério. Seu único
// consumidor era o gate do card "Próximos Eventos" no Dashboard, removido
// junto — o papel `coordinator` não existe no dado de produção, então o
// provider respondia `false` para todo mundo e escondia o card de todos.
// `MinistryRole.coordinator` segue no enum: quem voltar a usá-lo precisa
// antes provar que existe linha com esse papel.

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

/// Indica se o usuário atual pode **entrar** em um ministério específico —
/// o `canAccessMinistryWorkspace` da régua de escopo.
///
/// `visão global OU vínculo ativo`. É o gate do workspace base e o primeiro
/// degrau do `MinistrySubmoduleGuard`; o que a pessoa pode fazer lá dentro
/// continua vindo das permissões de cada aba.
///
/// Repare no que ele **não** consulta: `ministries.view`. Essa permissão diz
/// que a pessoa vê o hub de ministérios, não que ela vê todos eles — quem dá
/// visão global é [ministriesCanSeeAllProvider]. Misturar as duas faria um
/// líder de departamento enxergar ministérios de que não participa.
final ministryAccessProvider =
    FutureProvider.family<bool, String>((ref, ministryId) async {
  final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
  if (canSeeAll) return true;
  final mine = await ref.watch(currentMemberMinistriesProvider.future);
  return mine.any((m) => m.id == ministryId);
});

// O bloco MinistryCapabilities/ministryCapabilitiesProvider morava aqui e foi
// removido na Fase 2 (24/09). Eram ~50 linhas sem um único consumidor em lib/
// nem em test/: um provider que ninguém observava, três getters isRaizes/
// isDiaconato/isBatismo que ninguém lia e uma segunda cópia do switch de rota
// (specializedRoutePath) que nunca foi chamada. Quem precisa da rota hoje
// pergunta ao catálogo: ministryTypeCatalogSyncProvider + catalog.routeFor().

/// Ordem pessoal das abas do ministério (vazia = ordem padrão). Quem grava
/// invalida — Realtime não é ligado por migration neste banco.
final myMinistryTabOrderProvider =
    FutureProvider.family<List<String>, String>((ref, ministryId) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(ministriesRepositoryProvider).getMyTabOrder(ministryId);
});

/// Quem liga/desliga abas na engrenagem: o líder **deste** ministério ou
/// quem tem `ministries.edit`. É a mesma régua da RPC `set_ministry_tab`.
final canConfigureMinistryTabsProvider =
    FutureProvider.family<bool, String>((ref, ministryId) async {
  if (await ref.watch(
    currentUserHasPermissionProvider('ministries.edit').future,
  )) {
    return true;
  }
  final me = await ref.watch(currentMemberIdProvider.future);
  if (me == null) return false;
  final members = await ref.watch(ministryMembersProvider(ministryId).future);
  return members.any((m) => m.memberId == me && m.role == MinistryRole.leader);
});
