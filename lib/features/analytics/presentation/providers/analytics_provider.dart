// =====================================================
// CHURCH 360 - ANALYTICS PROVIDERS
// =====================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/analytics_repository.dart';
import '../../domain/models/analytics_models.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(Supabase.instance.client);
});

// =====================================================
// DASHBOARD GERAL
// =====================================================

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getDashboardSummary();
});

// =====================================================
// MEMBROS
// =====================================================

final memberStatisticsProvider = FutureProvider<MemberStatistics>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getMemberStatistics();
});

final memberGrowthReportProvider = FutureProvider.family<List<MemberGrowthData>, DateRange>(
  (ref, dateRange) async {
    final repository = ref.watch(analyticsRepositoryProvider);
    return repository.getMemberGrowthReport(
      startDate: dateRange.startDate,
      endDate: dateRange.endDate,
    );
  },
);

// =====================================================
// FINANCEIRO
// =====================================================

final financialStatisticsProvider = FutureProvider<FinancialStatistics>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getFinancialStatistics();
});

final financialReportProvider = FutureProvider.family<List<FinancialReportData>, DateRange>(
  (ref, dateRange) async {
    final repository = ref.watch(analyticsRepositoryProvider);
    return repository.getFinancialReport(
      startDate: dateRange.startDate,
      endDate: dateRange.endDate,
    );
  },
);

// =====================================================
// CULTOS
// =====================================================

final worshipStatisticsProvider = FutureProvider<WorshipStatistics>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getWorshipStatistics();
});

final worshipAttendanceReportProvider = FutureProvider.family<List<WorshipAttendanceData>, DateRange>(
  (ref, dateRange) async {
    final repository = ref.watch(analyticsRepositoryProvider);
    return repository.getWorshipAttendanceReport(
      startDate: dateRange.startDate,
      endDate: dateRange.endDate,
    );
  },
);

// =====================================================
// GRUPOS
// =====================================================

final groupStatisticsProvider = FutureProvider<GroupStatistics>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getGroupStatistics();
});

// =====================================================
// HELPER CLASSES
// =====================================================

class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  DateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode;
}

