import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/dashboard_charts.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';

/// Tela de Dashboard com estatísticas e gráficos
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          NotificationBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gráfico de Crescimento de Membros
            MemberGrowthChart(),
            SizedBox(height: 16),

            // Estatísticas de Eventos
            EventsStatsCard(),
            SizedBox(height: 16),

            // Grupos Mais Ativos
            TopActiveGroupsCard(),
            SizedBox(height: 16),

            // Estatísticas de Presença
            AverageAttendanceCard(),
            SizedBox(height: 16),

            // Tags Mais Usadas
            TopTagsCard(),
            SizedBox(height: 16),

            // Resumo Financeiro
            FinancialSummaryCards(),
            SizedBox(height: 16),

            // Distribuição de Contribuições
            ContributionsByTypeChart(),
            SizedBox(height: 16),

            // Metas Financeiras
            FinancialGoalsWidget(),
          ],
        ),
      ),
    );
  }
}

