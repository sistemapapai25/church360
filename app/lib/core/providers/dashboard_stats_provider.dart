import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Provider para estatísticas de crescimento de membros (últimos 6 meses)
final memberGrowthStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Buscar membros dos últimos 6 meses agrupados por mês
  final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
  
  final response = await supabase
      .from('member')
      .select('created_at')
      .gte('created_at', sixMonthsAgo.toIso8601String())
      .order('created_at', ascending: true);

  final members = response as List;
  
  // Agrupar por mês
  final Map<String, int> monthCounts = {};
  
  for (var member in members) {
    final createdAt = DateTime.parse(member['created_at'] as String);
    final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
    monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
  }
  
  // Converter para lista ordenada
  final result = monthCounts.entries.map((entry) {
    final parts = entry.key.split('-');
    return {
      'month': entry.key,
      'year': int.parse(parts[0]),
      'monthNumber': int.parse(parts[1]),
      'count': entry.value,
    };
  }).toList();
  
  result.sort((a, b) {
    final aDate = DateTime(a['year'] as int, a['monthNumber'] as int);
    final bDate = DateTime(b['year'] as int, b['monthNumber'] as int);
    return aDate.compareTo(bDate);
  });
  
  return result;
});

/// Provider para estatísticas de eventos
final eventsStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final now = DateTime.now();

  // Próximos eventos (publicados e com data futura)
  final upcomingResponse = await supabase
      .from('event')
      .select('id')
      .gte('start_date', now.toIso8601String())
      .eq('status', 'published');

  // Eventos ativos (em andamento)
  final activeResponse = await supabase
      .from('event')
      .select('id')
      .eq('status', 'ongoing');

  // Eventos finalizados (últimos 30 dias)
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final completedResponse = await supabase
      .from('event')
      .select('id')
      .eq('status', 'completed')
      .gte('end_date', thirtyDaysAgo.toIso8601String());

  return {
    'upcoming': (upcomingResponse as List).length,
    'active': (activeResponse as List).length,
    'completed': (completedResponse as List).length,
  };
});

/// Provider para grupos mais ativos (com mais reuniões)
final topActiveGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Buscar todos os grupos ativos
  final groupsResponse = await supabase
      .from('group')
      .select('id, name')
      .eq('is_active', true);

  final groups = groupsResponse as List;
  final groupStats = <Map<String, dynamic>>[];

  // Para cada grupo, contar reuniões
  for (var group in groups) {
    final meetingsResponse = await supabase
        .from('group_meeting')
        .select('id')
        .eq('group_id', group['id']);

    final meetingCount = (meetingsResponse as List).length;

    // Só adicionar grupos que têm pelo menos 1 reunião
    if (meetingCount > 0) {
      groupStats.add({
        'group_id': group['id'],
        'group_name': group['name'],
        'meeting_count': meetingCount,
      });
    }
  }

  // Ordenar por contagem de reuniões (decrescente)
  groupStats.sort((a, b) => (b['meeting_count'] as int).compareTo(a['meeting_count'] as int));

  // Retornar top 5
  return groupStats.take(5).toList();
});

/// Provider para frequência média nas reuniões
final averageAttendanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Buscar todas as reuniões dos últimos 3 meses
  final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
  
  final meetingsResponse = await supabase
      .from('group_meeting')
      .select('id, total_attendance')
      .gte('meeting_date', threeMonthsAgo.toIso8601String().split('T')[0]);
  
  final meetings = meetingsResponse as List;
  
  if (meetings.isEmpty) {
    return {
      'total_meetings': 0,
      'total_attendance': 0,
      'average_attendance': 0.0,
    };
  }
  
  final totalAttendance = meetings.fold<int>(
    0,
    (sum, meeting) => sum + ((meeting['total_attendance'] as int?) ?? 0),
  );
  
  return {
    'total_meetings': meetings.length,
    'total_attendance': totalAttendance,
    'average_attendance': totalAttendance / meetings.length,
  };
});

/// Provider para tags mais usadas
final topTagsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Buscar tags com contagem de membros
  final response = await supabase
      .from('tag')
      .select('''
        id,
        name,
        color,
        member_tag(count)
      ''');
  
  final tags = (response as List).map((tag) {
    final memberTagData = tag['member_tag'];
    final count = memberTagData is List ? memberTagData.length : 0;
    
    return {
      'id': tag['id'],
      'name': tag['name'],
      'color': tag['color'],
      'member_count': count,
    };
  }).toList();
  
  tags.sort((a, b) => (b['member_count'] as int).compareTo(a['member_count'] as int));
  
  return tags.take(5).toList();
});

