// =====================================================
// CHURCH 360 - ANALYTICS REPOSITORY
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../financeiro/data/lancamentos_scope.dart';
import '../domain/models/analytics_models.dart';

class AnalyticsRepository {
  final SupabaseClient _supabase;

  AnalyticsRepository(this._supabase);

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }

  bool _isCurrentMonth(dynamic value, DateTime now) {
    final parsed = _parseDate(value);
    if (parsed == null) return false;
    return parsed.year == now.year && parsed.month == now.month;
  }

  bool _isMissingSchemaDependency(PostgrestException error) {
    return error.code == '42P01' ||
        error.code == '42703' ||
        error.code == '42883';
  }

  // =====================================================
  // DASHBOARD GERAL
  // =====================================================

  /// Obter resumo geral do dashboard
  Future<DashboardSummary> getDashboardSummary() async {
    try {
      final response = await _supabase.rpc('get_dashboard_summary').single();
      return DashboardSummary.fromJson(response);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaDependency(error)) {
        return _getDashboardSummaryFallback();
      }
      rethrow;
    }
  }

  Future<DashboardSummary> _getDashboardSummaryFallback() async {
    final now = DateTime.now();
    final tenantId = SupabaseConstants.currentTenantId;

    int totalMembers = 0;
    int activeMembers = 0;
    int newMembersThisMonth = 0;
    try {
      final members = await _supabase
          .from('user_account')
          .select('status,created_at')
          .eq('tenant_id', tenantId);
      for (final raw in members as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        totalMembers += 1;
        if ((row['status']?.toString() ?? '') == 'member_active') {
          activeMembers += 1;
        }
        // novo membro = ficha de membro criada no mês (visitante não conta)
        if (_isCurrentMonth(row['created_at'], now) &&
            (row['status']?.toString() ?? '').startsWith('member_')) {
          newMembersThisMonth += 1;
        }
      }
    } catch (_) {}

    int totalGroups = 0;
    int activeGroups = 0;
    try {
      final groups = await _supabase
          .from('group')
          .select('is_active')
          .eq('tenant_id', tenantId);
      for (final raw in groups as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        totalGroups += 1;
        if (row['is_active'] == true) {
          activeGroups += 1;
        }
      }
    } catch (_) {}

    int totalMinistries = 0;
    try {
      final ministries = await _supabase
          .from('ministry')
          .select('id')
          .eq('tenant_id', tenantId);
      totalMinistries = (ministries as List).length;
    } catch (_) {}

    int totalVisitors = 0;
    int newVisitorsThisMonth = 0;
    try {
      final visitors = await _supabase
          .from('user_account')
          .select('created_at')
          .eq('tenant_id', tenantId)
          .eq('status', 'visitor');
      totalVisitors = (visitors as List).length;
      for (final raw in visitors) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (_isCurrentMonth(row['created_at'], now)) {
          newVisitorsThisMonth += 1;
        }
      }
    } catch (_) {}

    int servicesThisMonth = 0;
    int attendanceAccumulator = 0;
    int attendanceSamples = 0;
    try {
      final services = await _supabase
          .from('worship_service')
          .select('date,attendance_count')
          .eq('tenant_id', tenantId);
      for (final raw in services as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (_isCurrentMonth(row['date'], now)) {
          servicesThisMonth += 1;
          final attendance = row['attendance_count'];
          if (attendance is num) {
            attendanceAccumulator += attendance.toInt();
            attendanceSamples += 1;
          }
        }
      }
    } catch (_) {}

    // Financeiro do mês pela mesma base do módulo Financeiro (lancamentos pagos,
    // recorte da igreja). Antes lia contribution/donation/expense, que não
    // recebem mais lançamentos.
    double contributionsThisMonth = 0;
    double expensesThisMonth = 0;
    try {
      final rows = await _supabase
          .from('lancamentos')
          .select('tipo,valor,valor_pago,data_pagamento')
          .eq('tenant_id', tenantId)
          .eq('status', 'PAGO')
          .isFilter('deleted_at', null)
          .or(kLancamentosIgrejaScope);
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!_isCurrentMonth(row['data_pagamento'], now)) continue;
        final v = num.tryParse('${row['valor_pago'] ?? row['valor'] ?? 0}') ?? 0;
        if (row['tipo'] == 'RECEITA') contributionsThisMonth += v.toDouble();
        if (row['tipo'] == 'DESPESA') expensesThisMonth += v.toDouble();
      }
    } catch (_) {}

    final averageAttendance = attendanceSamples > 0
        ? attendanceAccumulator / attendanceSamples
        : null;

    return DashboardSummary(
      totalMembers: totalMembers,
      activeMembers: activeMembers,
      newMembersThisMonth: newMembersThisMonth,
      totalGroups: totalGroups,
      activeGroups: activeGroups,
      totalMinistries: totalMinistries,
      totalVisitors: totalVisitors,
      newVisitorsThisMonth: newVisitorsThisMonth,
      servicesThisMonth: servicesThisMonth,
      averageAttendance: averageAttendance,
      contributionsThisMonth: contributionsThisMonth,
      expensesThisMonth: expensesThisMonth,
      netBalanceThisMonth: contributionsThisMonth - expensesThisMonth,
    );
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
    final response = await _supabase.rpc(
      'get_member_growth_report',
      params: {
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      },
    );
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
    final response = await _supabase.rpc(
      'get_financial_report',
      params: {
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      },
    );
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
    final response = await _supabase.rpc(
      'get_worship_attendance_report',
      params: {
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      },
    );
    return (response as List)
        .map((json) => WorshipAttendanceData.fromJson(json))
        .toList();
  }
}
