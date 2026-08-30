import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/events_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_audience.dart';
import '../../../permissions/providers/permissions_providers.dart';

/// Provider do repository de eventos
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(Supabase.instance.client);
});

/// Provider de todos os eventos
final allEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getAllEvents();
});

/// Provider de eventos ativos
final activeEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getActiveEvents();
});

/// Provider de eventos futuros
final upcomingEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getUpcomingEvents();
});

/// Provider de evento por ID
final eventByIdProvider = FutureProvider.family<Event?, String>((ref, id) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventById(id);
});

/// Provider de contagem total de eventos
final totalEventsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getTotalEventsCount();
});

/// Provider de contagem de eventos ativos
final activeEventsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getActiveEventsCount();
});

/// Provider de inscrições de um evento
final eventRegistrationsProvider = FutureProvider.family<List<EventRegistration>, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventRegistrations(eventId);
});

/// Provider de responsáveis (event_audience, role='responsible') de um evento
final eventResponsiblesProvider = FutureProvider.family<List<EventAudience>, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventResponsibles(eventId);
});

/// VIS-03: audiência de um evento para um papel qualquer
/// (`responsible`, `visibility` ou `registration`).
///
/// `FutureProvider.family` aceita um único argumento, então a chave é um
/// record `(eventId, role)`. `eventResponsiblesProvider` continua existindo
/// intacto — é consumido pelo formulário desde a Fase 1.
final eventAudienceProvider =
    FutureProvider.family<List<EventAudience>, ({String eventId, String role})>((
      ref,
      arg,
    ) async {
      final repo = ref.watch(eventsRepositoryProvider);
      return repo.getEventAudience(arg.eventId, arg.role);
    });

/// VIS-03/VIS-04: o usuário atual pode se inscrever NESTE evento?
///
/// Resolvido inteiramente no servidor (`am_i_eligible_to_register`, Plano
/// 06). É insumo de UX: existe para antecipar a recusa em vez de deixar a
/// pessoa descobrir por erro depois de tentar. **Não é boundary de
/// segurança** — a autoridade é `register_member_in_event` (Plano 07), e
/// nenhuma checagem do servidor pode ser afrouxada por causa deste provider.
final amIEligibleToRegisterProvider = FutureProvider.family<bool, String>((
  ref,
  eventId,
) async {
  return ref.watch(eventsRepositoryProvider).amIEligibleToRegister(eventId);
});

/// VIS-03: membros que o servidor considera elegíveis a se inscrever no
/// evento. Fonte do diálogo "Adicionar Inscrito" quando a inscrição é
/// restrita.
///
/// "Don't Hand-Roll": a resolução de grupo/ministério/cargo acontece dentro
/// de `list_event_eligible_members`. Reimplementar o filtro em Dart exigiria
/// expor `user_roles`/`group_member` ao cliente.
final eligibleMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      eventId,
    ) async {
      return ref
          .watch(eventsRepositoryProvider)
          .listEventEligibleMembers(eventId);
    });

/// REG-03: o usuário atual é responsável por ESTE evento?
///
/// Vínculo de instância (aquele evento), resolvido no servidor. Não é
/// permissão de cargo e não deve ser confundido com uma.
final isEventResponsibleProvider = FutureProvider.family<bool, String>((
  ref,
  eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.isEventResponsible(eventId);
});

/// REG-03: "posso gerenciar os inscritos deste evento?".
///
/// Gate composto de propósito: permissão global de cargo OU vínculo de
/// responsável naquele evento. Checar só a permissão global quebraria o
/// critério de sucesso #1 da fase — o líder de grupo marcado como
/// responsável não a tem e perderia todas as ações da aba.
///
/// O inverso também é proibido: conceder a permissão global a quem vira
/// responsável daria gestão de TODOS os eventos do tenant. É escalação de
/// privilégio por design e está em Out of Scope no REQUIREMENTS.md.
///
/// Curto-circuito: com a permissão global respondendo `true`, a consulta de
/// responsável não chega a ser disparada.
final canManageEventRegistrationsProvider = FutureProvider.family<bool, String>(
  (ref, eventId) async {
    final temPermissaoGlobal = await ref.watch(
      currentUserHasPermissionProvider('events.manage_registrations').future,
    );
    if (temPermissaoGlobal) return true;
    return ref.watch(isEventResponsibleProvider(eventId).future);
  },
);

