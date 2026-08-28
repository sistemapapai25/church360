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

