import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/events_repository.dart';
import '../../domain/models/event.dart';

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

