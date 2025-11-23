// =====================================================
// CHURCH 360 - ANALYTICS REPOSITORY
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/analytics_models.dart';

class AnalyticsRepository {
  final SupabaseClient _supabase;

  AnalyticsRepository(this._supabase);

  // =====================================================
  // DASHBOARD GERAL
  // =====================================================

  /// Obter resumo geral do dashboard
  Future<DashboardSummary> getDashboardSummary() async {
    final response = await _supabase.rpc('get_dashboard_summary').single();
    return DashboardSummary.fromJson(response);
  }

  // =====================================================
  // MEMBROS
  // =====================================================

  /// Obter estatísticas de membros
  Future<MemberStatistics> getMemberStatistics() async {
    final response = await _supabase.rpc('get_member_statistics').single();
    return MemberStatistics.fromJson(response);
  }

  /// Obter relatório de crescimento de membros
  Future<List<MemberGrowthData>> getMemberGrowthReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase.rpc('get_member_growth_report', params: {
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    return (response as List)
        .map((json) => MemberGrowthData.fromJson(json))
        .toList();
  }

  // =====================================================
  // FINANCEIRO
  // =====================================================

  /// Obter estatísticas financeiras
  Future<FinancialStatistics> getFinancialStatistics() async {
    final response = await _supabase.rpc('get_financial_statistics').single();
    return FinancialStatistics.fromJson(response);
  }

  /// Obter relatório financeiro
  Future<List<FinancialReportData>> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase.rpc('get_financial_report', params: {
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    return (response as List)
        .map((json) => FinancialReportData.fromJson(json))
        .toList();
  }

  // =====================================================
  // CULTOS
  // =====================================================

  /// Obter estatísticas de cultos
  Future<WorshipStatistics> getWorshipStatistics() async {
    final response = await _supabase.rpc('get_worship_statistics').single();
    return WorshipStatistics.fromJson(response);
  }

  /// Obter relatório de frequência em cultos
  Future<List<WorshipAttendanceData>> getWorshipAttendanceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase.rpc('get_worship_attendance_report', params: {
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    return (response as List)
        .map((json) => WorshipAttendanceData.fromJson(json))
        .toList();
  }

  // =====================================================
  // GRUPOS
  // =====================================================

  /// Obter estatísticas de grupos
  Future<GroupStatistics> getGroupStatistics() async {
    final response = await _supabase.rpc('get_group_statistics').single();
    return GroupStatistics.fromJson(response);
  }
}

