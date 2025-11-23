// =====================================================
// CHURCH 360 - ANALYTICS MODELS
// =====================================================

/// Resumo geral do dashboard
class DashboardSummary {
  final int totalMembers;
  final int activeMembers;
  final int newMembersThisMonth;
  final int totalGroups;
  final int activeGroups;
  final int totalMinistries;
  final int totalVisitors;
  final int newVisitorsThisMonth;
  final int servicesThisMonth;
  final double? averageAttendance;
  final double contributionsThisMonth;
  final double expensesThisMonth;
  final double netBalanceThisMonth;

  DashboardSummary({
    required this.totalMembers,
    required this.activeMembers,
    required this.newMembersThisMonth,
    required this.totalGroups,
    required this.activeGroups,
    required this.totalMinistries,
    required this.totalVisitors,
    required this.newVisitorsThisMonth,
    required this.servicesThisMonth,
    this.averageAttendance,
    required this.contributionsThisMonth,
    required this.expensesThisMonth,
    required this.netBalanceThisMonth,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalMembers: json['total_members'] as int,
      activeMembers: json['active_members'] as int,
      newMembersThisMonth: json['new_members_this_month'] as int,
      totalGroups: json['total_groups'] as int,
      activeGroups: json['active_groups'] as int,
      totalMinistries: json['total_ministries'] as int,
      totalVisitors: json['total_visitors'] as int,
      newVisitorsThisMonth: json['new_visitors_this_month'] as int,
      servicesThisMonth: json['services_this_month'] as int,
      averageAttendance: json['average_attendance'] != null
          ? (json['average_attendance'] as num).toDouble()
          : null,
      contributionsThisMonth: (json['contributions_this_month'] as num).toDouble(),
      expensesThisMonth: (json['expenses_this_month'] as num).toDouble(),
      netBalanceThisMonth: (json['net_balance_this_month'] as num).toDouble(),
    );
  }
}

/// Estatísticas de membros
class MemberStatistics {
  final int totalMembers;
  final int activeMembers;
  final int inactiveMembers;
  final int newThisMonth;
  final int conversionsThisMonth;
  final int baptismsThisMonth;
  final double? averageAge;
  final int maleCount;
  final int femaleCount;

  MemberStatistics({
    required this.totalMembers,
    required this.activeMembers,
    required this.inactiveMembers,
    required this.newThisMonth,
    required this.conversionsThisMonth,
    required this.baptismsThisMonth,
    this.averageAge,
    required this.maleCount,
    required this.femaleCount,
  });

  factory MemberStatistics.fromJson(Map<String, dynamic> json) {
    return MemberStatistics(
      totalMembers: json['total_members'] as int,
      activeMembers: json['active_members'] as int,
      inactiveMembers: json['inactive_members'] as int,
      newThisMonth: json['new_this_month'] as int,
      conversionsThisMonth: json['conversions_this_month'] as int,
      baptismsThisMonth: json['baptisms_this_month'] as int,
      averageAge: json['average_age'] != null
          ? (json['average_age'] as num).toDouble()
          : null,
      maleCount: json['male_count'] as int,
      femaleCount: json['female_count'] as int,
    );
  }
}

/// Ponto de dados para gráfico de crescimento de membros
class MemberGrowthData {
  final String period;
  final int newMembers;
  final int conversions;
  final int baptisms;
  final int totalMembers;

  MemberGrowthData({
    required this.period,
    required this.newMembers,
    required this.conversions,
    required this.baptisms,
    required this.totalMembers,
  });

  factory MemberGrowthData.fromJson(Map<String, dynamic> json) {
    return MemberGrowthData(
      period: json['period'] as String,
      newMembers: json['new_members'] as int,
      conversions: json['conversions'] as int,
      baptisms: json['baptisms'] as int,
      totalMembers: json['total_members'] as int,
    );
  }
}

/// Estatísticas financeiras
class FinancialStatistics {
  final double totalContributionsMonth;
  final double totalDonationsMonth;
  final double totalExpensesMonth;
  final double netBalanceMonth;
  final double totalContributionsYear;
  final double totalDonationsYear;
  final double totalExpensesYear;
  final double netBalanceYear;
  final int activeGoals;
  final int completedGoals;

  FinancialStatistics({
    required this.totalContributionsMonth,
    required this.totalDonationsMonth,
    required this.totalExpensesMonth,
    required this.netBalanceMonth,
    required this.totalContributionsYear,
    required this.totalDonationsYear,
    required this.totalExpensesYear,
    required this.netBalanceYear,
    required this.activeGoals,
    required this.completedGoals,
  });

  factory FinancialStatistics.fromJson(Map<String, dynamic> json) {
    return FinancialStatistics(
      totalContributionsMonth: (json['total_contributions_month'] as num).toDouble(),
      totalDonationsMonth: (json['total_donations_month'] as num).toDouble(),
      totalExpensesMonth: (json['total_expenses_month'] as num).toDouble(),
      netBalanceMonth: (json['net_balance_month'] as num).toDouble(),
      totalContributionsYear: (json['total_contributions_year'] as num).toDouble(),
      totalDonationsYear: (json['total_donations_year'] as num).toDouble(),
      totalExpensesYear: (json['total_expenses_year'] as num).toDouble(),
      netBalanceYear: (json['net_balance_year'] as num).toDouble(),
      activeGoals: json['active_goals'] as int,
      completedGoals: json['completed_goals'] as int,
    );
  }
}

/// Ponto de dados para relatório financeiro
class FinancialReportData {
  final String period;
  final double totalContributions;
  final double totalDonations;
  final double totalExpenses;
  final double netBalance;
  final double goalProgress;

  FinancialReportData({
    required this.period,
    required this.totalContributions,
    required this.totalDonations,
    required this.totalExpenses,
    required this.netBalance,
    required this.goalProgress,
  });

  factory FinancialReportData.fromJson(Map<String, dynamic> json) {
    return FinancialReportData(
      period: json['period'] as String,
      totalContributions: (json['total_contributions'] as num).toDouble(),
      totalDonations: (json['total_donations'] as num).toDouble(),
      totalExpenses: (json['total_expenses'] as num).toDouble(),
      netBalance: (json['net_balance'] as num).toDouble(),
      goalProgress: (json['goal_progress'] as num).toDouble(),
    );
  }
}

/// Estatísticas de cultos
class WorshipStatistics {
  final int totalServicesMonth;
  final int totalAttendanceMonth;
  final double? averageAttendanceMonth;
  final int totalServicesYear;
  final int totalAttendanceYear;
  final double? averageAttendanceYear;
  final String? mostAttendedServiceType;
  final String? leastAttendedServiceType;

  WorshipStatistics({
    required this.totalServicesMonth,
    required this.totalAttendanceMonth,
    this.averageAttendanceMonth,
    required this.totalServicesYear,
    required this.totalAttendanceYear,
    this.averageAttendanceYear,
    this.mostAttendedServiceType,
    this.leastAttendedServiceType,
  });

  factory WorshipStatistics.fromJson(Map<String, dynamic> json) {
    return WorshipStatistics(
      totalServicesMonth: json['total_services_month'] as int,
      totalAttendanceMonth: json['total_attendance_month'] as int,
      averageAttendanceMonth: json['average_attendance_month'] != null
          ? (json['average_attendance_month'] as num).toDouble()
          : null,
      totalServicesYear: json['total_services_year'] as int,
      totalAttendanceYear: json['total_attendance_year'] as int,
      averageAttendanceYear: json['average_attendance_year'] != null
          ? (json['average_attendance_year'] as num).toDouble()
          : null,
      mostAttendedServiceType: json['most_attended_service_type'] as String?,
      leastAttendedServiceType: json['least_attended_service_type'] as String?,
    );
  }
}

/// Ponto de dados para relatório de frequência em cultos
class WorshipAttendanceData {
  final String period;
  final int totalServices;
  final int totalAttendance;
  final double? averageAttendance;
  final int? maxAttendance;
  final int? minAttendance;

  WorshipAttendanceData({
    required this.period,
    required this.totalServices,
    required this.totalAttendance,
    this.averageAttendance,
    this.maxAttendance,
    this.minAttendance,
  });

  factory WorshipAttendanceData.fromJson(Map<String, dynamic> json) {
    return WorshipAttendanceData(
      period: json['period'] as String,
      totalServices: json['total_services'] as int,
      totalAttendance: json['total_attendance'] as int,
      averageAttendance: json['average_attendance'] != null
          ? (json['average_attendance'] as num).toDouble()
          : null,
      maxAttendance: json['max_attendance'] as int?,
      minAttendance: json['min_attendance'] as int?,
    );
  }
}

/// Estatísticas de grupos
class GroupStatistics {
  final int totalGroups;
  final int activeGroups;
  final int totalMembers;
  final double? averageMembersPerGroup;
  final int meetingsThisMonth;
  final double? averageAttendanceThisMonth;

  GroupStatistics({
    required this.totalGroups,
    required this.activeGroups,
    required this.totalMembers,
    this.averageMembersPerGroup,
    required this.meetingsThisMonth,
    this.averageAttendanceThisMonth,
  });

  factory GroupStatistics.fromJson(Map<String, dynamic> json) {
    return GroupStatistics(
      totalGroups: json['total_groups'] as int,
      activeGroups: json['active_groups'] as int,
      totalMembers: json['total_members'] as int,
      averageMembersPerGroup: json['average_members_per_group'] != null
          ? (json['average_members_per_group'] as num).toDouble()
          : null,
      meetingsThisMonth: json['meetings_this_month'] as int,
      averageAttendanceThisMonth: json['average_attendance_this_month'] != null
          ? (json['average_attendance_this_month'] as num).toDouble()
          : null,
    );
  }
}

