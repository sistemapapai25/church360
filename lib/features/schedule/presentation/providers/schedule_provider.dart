import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/schedule_repository.dart';
import '../../../events/domain/models/event.dart';

/// Provider do repository de Schedule
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(Supabase.instance.client);
});

/// Provider que retorna os eventos de um mês específico
final eventsOfMonthProvider = FutureProvider.family<List<Event>, DateTime>((ref, date) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getEventsByMonth(date.year, date.month);
});

/// Provider que retorna os eventos de um dia específico
final eventsOfDateProvider = FutureProvider.family<List<Event>, DateTime>((ref, date) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getEventsByDate(date);
});

