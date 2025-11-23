import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/visitors_repository.dart';
import '../../domain/models/visitor.dart';

/// Provider do repository
final visitorsRepositoryProvider = Provider<VisitorsRepository>((ref) {
  return VisitorsRepository(Supabase.instance.client);
});

/// Provider de todos os visitantes
final allVisitorsProvider = FutureProvider<List<Visitor>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.getAllVisitors();
});

/// Provider de visitantes por status
final visitorsByStatusProvider = FutureProvider.family<List<Visitor>, VisitorStatus>(
  (ref, status) async {
    final repo = ref.watch(visitorsRepositoryProvider);
    return repo.getVisitorsByStatus(status);
  },
);

/// Provider de visitante por ID
final visitorByIdProvider = FutureProvider.family<Visitor?, String>(
  (ref, id) async {
    final repo = ref.watch(visitorsRepositoryProvider);
    return repo.getVisitorById(id);
  },
);

/// Provider de visitantes recentes (últimos 30 dias)
final recentVisitorsProvider = FutureProvider<List<Visitor>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.getRecentVisitors();
});

/// Provider de visitantes inativos
final inactiveVisitorsProvider = FutureProvider<List<Visitor>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.getInactiveVisitors(days: 30);
});

/// Provider de contagem por status
final visitorCountByStatusProvider = FutureProvider<Map<VisitorStatus, int>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.countVisitorsByStatus();
});

/// Provider de visitas de um visitante
final visitorVisitsProvider = FutureProvider.family<List<VisitorVisit>, String>(
  (ref, visitorId) async {
    final repo = ref.watch(visitorsRepositoryProvider);
    return repo.getVisitorVisits(visitorId);
  },
);

/// Provider de follow-ups de um visitante
final visitorFollowupsProvider = FutureProvider.family<List<VisitorFollowup>, String>(
  (ref, visitorId) async {
    final repo = ref.watch(visitorsRepositoryProvider);
    return repo.getVisitorFollowups(visitorId);
  },
);

/// Provider de follow-ups pendentes
final pendingFollowupsProvider = FutureProvider<List<VisitorFollowup>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.getPendingFollowups();
});

/// Provider de follow-ups do dia
final todayFollowupsProvider = FutureProvider<List<VisitorFollowup>>((ref) async {
  final repo = ref.watch(visitorsRepositoryProvider);
  return repo.getTodayFollowups();
});

