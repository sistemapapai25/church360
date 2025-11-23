import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/domain/models/event.dart';

/// Repository de Agenda
/// Responsável por buscar eventos por período de datas
class ScheduleRepository {
  final SupabaseClient _supabase;

  ScheduleRepository(this._supabase);

  /// Buscar eventos entre duas datas
  Future<List<Event>> getEventsByDateRange(DateTime start, DateTime end) async {
    try {
      // Converter para ISO 8601 string para comparação no Supabase
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      final response = await _supabase
          .from('event')
          .select()
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

