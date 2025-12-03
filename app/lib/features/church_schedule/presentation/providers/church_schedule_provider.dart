import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/church_schedule.dart';

/// Provider para listar todas as agendas ativas
final activeChurchSchedulesProvider = StreamProvider.autoDispose<List<ChurchSchedule>>((ref) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('church_schedule')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('start_datetime', ascending: true)
      .map((data) {
        return data.map((json) {
          // Buscar nome do responsável se houver
          if (json['responsible_id'] != null) {
            // Nota: Aqui seria ideal fazer um join, mas por simplicidade vamos deixar null
            // e buscar o nome separadamente quando necessário
          }
          return ChurchSchedule.fromJson(json);
        }).toList();
      });
});

/// Provider para listar todas as agendas (incluindo inativas)
final allChurchSchedulesProvider = StreamProvider.autoDispose<List<ChurchSchedule>>((ref) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('church_schedule')
      .stream(primaryKey: ['id'])
      .order('start_datetime', ascending: true)
      .map((data) {
        return data.map((json) => ChurchSchedule.fromJson(json)).toList();
      });
});

/// Provider para buscar agendas de um mês específico (apenas ativas)
final churchSchedulesOfMonthProvider = FutureProvider.autoDispose.family<List<ChurchSchedule>, DateTime>((ref, date) async {
  final supabase = Supabase.instance.client;

  final firstDay = DateTime(date.year, date.month, 1);
  final lastDay = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  final response = await supabase
      .from('church_schedule')
      .select()
      .eq('is_active', true)
      .gte('start_datetime', firstDay.toIso8601String())
      .lte('start_datetime', lastDay.toIso8601String())
      .order('start_datetime', ascending: true);

  return (response as List).map((json) => ChurchSchedule.fromJson(json)).toList();
});

/// Provider para buscar agendas de uma data específica (apenas ativas)
final churchSchedulesOfDateProvider = FutureProvider.autoDispose.family<List<ChurchSchedule>, DateTime>((ref, date) async {
  final supabase = Supabase.instance.client;

  final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
  final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

  final response = await supabase
      .from('church_schedule')
      .select()
      .eq('is_active', true)
      .gte('start_datetime', startOfDay.toIso8601String())
      .lte('start_datetime', endOfDay.toIso8601String())
      .order('start_datetime', ascending: true);

  return (response as List).map((json) => ChurchSchedule.fromJson(json)).toList();
});

/// Provider para buscar uma agenda específica por ID
final churchScheduleByIdProvider = FutureProvider.autoDispose.family<ChurchSchedule?, String>((ref, id) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('church_schedule')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (response == null) return null;

  return ChurchSchedule.fromJson(response);
});

/// Provider para criar uma nova agenda
final createChurchScheduleProvider = Provider((ref) {
  return (ChurchSchedule schedule) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    await supabase.from('church_schedule').insert({
      'title': schedule.title,
      'description': schedule.description,
      'schedule_type': schedule.scheduleType,
      'start_datetime': schedule.startDatetime.toIso8601String(),
      'end_datetime': schedule.endDatetime.toIso8601String(),
      'location': schedule.location,
      'responsible_id': schedule.responsibleId,
      'recurrence_type': schedule.recurrenceType,
      'recurrence_end_date': schedule.recurrenceEndDate?.toIso8601String(),
      'is_active': schedule.isActive,
      'created_by': userId,
    });

    // Invalidar providers para atualizar a lista
    ref.invalidate(activeChurchSchedulesProvider);
    ref.invalidate(allChurchSchedulesProvider);
  };
});

/// Provider para atualizar uma agenda existente
final updateChurchScheduleProvider = Provider((ref) {
  return (String id, ChurchSchedule schedule) async {
    final supabase = Supabase.instance.client;

    await supabase.from('church_schedule').update({
      'title': schedule.title,
      'description': schedule.description,
      'schedule_type': schedule.scheduleType,
      'start_datetime': schedule.startDatetime.toIso8601String(),
      'end_datetime': schedule.endDatetime.toIso8601String(),
      'location': schedule.location,
      'responsible_id': schedule.responsibleId,
      'recurrence_type': schedule.recurrenceType,
      'recurrence_end_date': schedule.recurrenceEndDate?.toIso8601String(),
      'is_active': schedule.isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // Invalidar providers para atualizar a lista
    ref.invalidate(activeChurchSchedulesProvider);
    ref.invalidate(allChurchSchedulesProvider);
    ref.invalidate(churchScheduleByIdProvider(id));
  };
});

/// Provider para deletar uma agenda
final deleteChurchScheduleProvider = Provider((ref) {
  return (String id) async {
    final supabase = Supabase.instance.client;

    await supabase.from('church_schedule').delete().eq('id', id);

    // Invalidar providers para atualizar a lista
    ref.invalidate(activeChurchSchedulesProvider);
    ref.invalidate(allChurchSchedulesProvider);
  };
});

/// Provider para alternar status ativo/inativo
final toggleChurchScheduleActiveProvider = Provider((ref) {
  return (String id, bool isActive) async {
    final supabase = Supabase.instance.client;

    await supabase.from('church_schedule').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // Invalidar providers para atualizar a lista
    ref.invalidate(activeChurchSchedulesProvider);
    ref.invalidate(allChurchSchedulesProvider);
    ref.invalidate(churchScheduleByIdProvider(id));
  };
});

