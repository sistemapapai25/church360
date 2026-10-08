import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../../events/domain/models/event.dart';

/// Repository de Agenda
/// Responsável por buscar eventos por período de datas
class ScheduleRepository {
  final SupabaseClient _supabase;

  ScheduleRepository(this._supabase);

  /// Buscar eventos entre duas datas
  Future<List<Event>> getEventsByDateRange(DateTime start, DateTime end) async {
    try {
      // Se `end` chegou no início do dia (00:00:00), expandir para fim do dia
      // para incluir eventos que acontecem mais tarde no último dia do range.
      // Caller que passa horário explícito (`getEventsByMonth`, `getEventsByDate`)
      // não é afetado.
      final normalizedEnd =
          (end.hour == 0 && end.minute == 0 && end.second == 0 && end.millisecond == 0)
              ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
              : end;

      final startStr = start.toIso8601String();
      final endStr = normalizedEnd.toIso8601String();

      final response = await _supabase
          .from('event')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          // Notícia é event_type 'news' e não é evento de agenda; neq sozinho
          // tiraria também os eventos sem event_type.
          .or('event_type.is.null,event_type.neq.news')
          .gte('start_date', startStr)
          .lte('start_date', endStr)
          .order('start_date', ascending: true);

      return (response as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Dos [eventIds], os que só outros ministérios veem: têm público
  /// `visibility` com ministério e nenhum deles é [ministryId] (ex.: Ensaio
  /// da Dança com público = Dança não entra na escala do Louvor).
  Future<Set<String>> eventsVisibleOnlyToOtherMinistries(
    List<String> eventIds,
    String ministryId,
  ) async {
    if (eventIds.isEmpty) return {};
    final rows = await _supabase
        .from('event_audience')
        .select('event_id, ministry_id')
        .eq('role', 'visibility')
        .not('ministry_id', 'is', null)
        .inFilter('event_id', eventIds);
    final byEvent = <String, Set<String>>{};
    for (final r in rows as List) {
      byEvent
          .putIfAbsent(r['event_id'].toString(), () => {})
          .add(r['ministry_id'].toString());
    }
    return {
      for (final e in byEvent.entries)
        if (!e.value.contains(ministryId)) e.key,
    };
  }

  /// Buscar eventos de um mês específico
  Future<List<Event>> getEventsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    
    return getEventsByDateRange(start, end);
  }

  /// Buscar eventos de um dia específico
  Future<List<Event>> getEventsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return getEventsByDateRange(start, end);
  }
}
