import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/supabase_constants.dart';

/// Provider para estatísticas de crescimento de membros (últimos 6 meses)
final memberGrowthStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Buscar membros dos últimos 6 meses agrupados por mês
  final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));

  final response = await supabase
      .from('user_account')
      .select('created_at, status')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .gte('created_at', sixMonthsAgo.toIso8601String())
      .inFilter('status', ['member_active', 'member_inactive']) // Apenas membros
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
      .eq('status', 'published')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  // Eventos ativos (em andamento)
  final activeResponse = await supabase
      .from('event')
      .select('id')
      .eq('status', 'ongoing')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  // Eventos finalizados (últimos 30 dias)
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final completedResponse = await supabase
      .from('event')
      .select('id')
      .eq('status', 'completed')
      .gte('end_date', thirtyDaysAgo.toIso8601String())
      .eq('tenant_id', SupabaseConstants.currentTenantId);

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
      .eq('is_active', true)
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  final groups = groupsResponse as List;
  final groupStats = <Map<String, dynamic>>[];

  // Para cada grupo, contar reuniões
  for (var group in groups) {
    // Verificar se o grupo tem nome (null safety)
    final groupName = group['name'] as String?;
    if (groupName == null || groupName.isEmpty) continue;

    final meetingsResponse = await supabase
        .from('group_meeting')
        .select('id')
        .eq('group_id', group['id'])
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    final meetingCount = (meetingsResponse as List).length;

    // Só adicionar grupos que têm pelo menos 1 reunião
    if (meetingCount > 0) {
      groupStats.add({
        'group_id': group['id'] as String,
        'group_name': groupName,
        'meeting_count': meetingCount,
      });
    }
  }

  // Ordenar por contagem de reuniões (decrescente)
  groupStats.sort((a, b) {
    final countA = a['meeting_count'] as int? ?? 0;
    final countB = b['meeting_count'] as int? ?? 0;
    return countB.compareTo(countA);
  });

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
      .gte('meeting_date', threeMonthsAgo.toIso8601String().split('T')[0])
      .eq('tenant_id', SupabaseConstants.currentTenantId);
  
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
      ''')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

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

/// Provider para aniversariantes do mês atual (todos os usuários)
final birthdaysThisMonthProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final now = DateTime.now();
  final currentMonth = now.month;

  // Buscar TODOS os usuários com data de nascimento
  final response = await supabase
      .from('user_account')
      .select('id, first_name, last_name, photo_url, status')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .not('birthdate', 'is', null)
      .order('birthdate', ascending: true);

  final allBirthdays = (response as List).where((user) {
    final birthdateStr = user['birthdate'] as String?;
    if (birthdateStr == null) return false;
    try {
      final birthDate = DateTime.parse(birthdateStr);
      return birthDate.month == currentMonth;
    } catch (e) {
      return false;
    }
  }).map((user) {
    final birthDate = DateTime.parse(user['birthdate'] as String);
    final status = user['status'] as String?;

    // Determinar tipo baseado no status
    String type = 'Visitante';
    if (status != null) {
      if (status.startsWith('member_')) {
        type = 'Membro';
      } else if (status == 'new_convert') {
        type = 'Novo Convertido';
      }
    }

    return {
      'id': user['id'],
      'first_name': user['first_name'] ?? '',
      'last_name': user['last_name'] ?? '',
      'birthdate': birthDate,
      'photo_url': user['photo_url'],
      'day': birthDate.day,
      'type': type,
    };
  }).toList();

  // Ordenar por dia do mês
  allBirthdays.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));

  return allBirthdays;
});

/// Provider para próximas despesas (próximos 30 dias)
final upcomingExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final now = DateTime.now();
  final thirtyDaysFromNow = now.add(const Duration(days: 30));

  // Buscar despesas com data futura (próximos 30 dias)
  final response = await supabase
      .from('expense')
      .select('id, category, amount, date, description')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .gte('date', now.toIso8601String().split('T')[0])
      .lte('date', thirtyDaysFromNow.toIso8601String().split('T')[0])
      .order('date', ascending: true);

  final expenses = (response as List).map((expense) {
    final date = DateTime.parse(expense['date'] as String);
    final isOverdue = date.isBefore(now);

    return {
      'id': expense['id'],
      'category': expense['category'],
      'amount': (expense['amount'] as num).toDouble(),
      'date': date,
      'description': expense['description'],
      'is_overdue': isOverdue,
    };
  }).toList();

  return expenses;
});

/// Provider para novos membros (últimos 30 dias)
final recentMembersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  // Buscar membros criados nos últimos 30 dias
  final response = await supabase
      .from('user_account')
      .select('id, first_name, last_name, photo_url, created_at')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .gte('created_at', thirtyDaysAgo.toIso8601String())
      .order('created_at', ascending: false);

  final members = (response as List).map((member) {
    return {
      'id': member['id'],
      'first_name': member['first_name'],
      'last_name': member['last_name'],
      'photo_url': member['photo_url'],
      'created_at': DateTime.parse(member['created_at'] as String),
    };
  }).toList();

  return members;
});

/// Provider para próximos eventos (próximos 7 dias)
final upcomingEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final now = DateTime.now();
  final sevenDaysFromNow = now.add(const Duration(days: 7));

  // Buscar eventos publicados nos próximos 7 dias
  final response = await supabase
      .from('event')
      .select('id, name, start_date, location')
      .eq('status', 'published')
      .gte('start_date', now.toIso8601String())
      .lte('start_date', sevenDaysFromNow.toIso8601String())
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .order('start_date', ascending: true);

  final events = (response as List).map((event) {
    return {
      'id': event['id'],
      'title': event['name'], // Campo correto é 'name', mas mantemos 'title' na chave para compatibilidade
      'start_date': DateTime.parse(event['start_date'] as String),
      'location': event['location'],
    };
  }).toList();

  return events;
});

/// Provider para crescimento anual de membros
final annualMemberGrowthProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Buscar todos os membros com data de criação
  final response = await supabase
      .from('user_account')
      .select('created_at, status')
      .inFilter('status', ['member_active', 'member_inactive']) // Apenas membros
      .order('created_at', ascending: true);

  final members = response as List;

  // Agrupar por ano e mês
  final Map<String, int> monthCounts = {};

  for (var member in members) {
    final createdAt = DateTime.parse(member['created_at'] as String);
    final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
    monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
  }

  // Converter para lista ordenada com total acumulado
  int accumulated = 0;
  final result = monthCounts.entries.map((entry) {
    accumulated += entry.value;
    final parts = entry.key.split('-');
    return {
      'month': entry.key,
      'year': int.parse(parts[0]),
      'monthNumber': int.parse(parts[1]),
      'count': entry.value,
      'accumulated': accumulated,
    };
  }).toList();

  result.sort((a, b) {
    final aDate = DateTime(a['year'] as int, a['monthNumber'] as int);
    final bDate = DateTime(b['year'] as int, b['monthNumber'] as int);
    return aDate.compareTo(bDate);
  });

  return result;
});

/// Provider para estatísticas gerais de membros
final memberStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Total de membros ativos
  final activeResponse = await supabase
      .from('user_account')
      .select('id')
      .eq('status', 'member_active')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  // Total de membros inativos
  final inactiveResponse = await supabase
      .from('user_account')
      .select('id')
      .eq('status', 'member_inactive')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  // Novos membros (últimos 30 dias)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  final recentResponse = await supabase
      .from('user_account')
      .select('id')
      .gte('created_at', thirtyDaysAgo.toIso8601String())
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  // Membros por gênero
  final maleResponse = await supabase
      .from('user_account')
      .select('id')
      .inFilter('status', ['member_active', 'member_inactive']) // Apenas membros
      .eq('gender', 'male')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  final femaleResponse = await supabase
      .from('user_account')
      .select('id')
      .inFilter('status', ['member_active', 'member_inactive']) // Apenas membros
      .eq('gender', 'female')
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  return {
    'total_active': (activeResponse as List).length,
    'total_inactive': (inactiveResponse as List).length,
    'recent_30_days': (recentResponse as List).length,
    'male_count': (maleResponse as List).length,
    'female_count': (femaleResponse as List).length,
  };
});

/// Provider para relatório detalhado de presença por grupo
final attendanceByGroupProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Buscar todas as reuniões dos últimos 3 meses com informações do grupo
  final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

  final meetingsResponse = await supabase
      .from('group_meeting')
      .select('''
        id,
        total_attendance,
        communion_group(id, name),
        study_group(id, name)
      ''')
      .gte('meeting_date', threeMonthsAgo.toIso8601String().split('T')[0])
      .eq('tenant_id', SupabaseConstants.currentTenantId);

  final meetings = meetingsResponse as List;

  if (meetings.isEmpty) {
    return [];
  }

  // Agrupar por grupo
  final Map<String, Map<String, dynamic>> groupStats = {};

  for (var meeting in meetings) {
    String? groupId;
    String? groupName;

    if (meeting['communion_group'] != null) {
      groupId = meeting['communion_group']['id'];
      groupName = meeting['communion_group']['name'];
    } else if (meeting['study_group'] != null) {
      groupId = meeting['study_group']['id'];
      groupName = meeting['study_group']['name'];
    }

    if (groupId != null && groupName != null) {
      if (!groupStats.containsKey(groupId)) {
        groupStats[groupId] = {
          'group_name': groupName,
          'total_present': 0,
          'total_meetings': 0,
        };
      }

      groupStats[groupId]!['total_present'] =
          (groupStats[groupId]!['total_present'] as int) +
          ((meeting['total_attendance'] as int?) ?? 0);
      groupStats[groupId]!['total_meetings'] =
          (groupStats[groupId]!['total_meetings'] as int) + 1;
    }
  }

  // Converter para lista e calcular média
  final result = groupStats.values.map((stats) {
    final totalPresent = stats['total_present'] as int;
    final totalMeetings = stats['total_meetings'] as int;

    return {
      'group_name': stats['group_name'],
      'total_present': totalPresent,
      'total_expected': totalMeetings * 10, // Estimativa de 10 pessoas por reunião
      'average_attendance': totalMeetings > 0 ? totalPresent / totalMeetings : 0.0,
    };
  }).toList();

  // Ordenar por média de presença
  result.sort((a, b) =>
    (b['average_attendance'] as double).compareTo(a['average_attendance'] as double)
  );

  return result;
});
