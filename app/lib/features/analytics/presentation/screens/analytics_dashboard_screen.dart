// =====================================================
// CHURCH 360 - ANALYTICS DASHBOARD SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/analytics_provider.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Relatórios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardSummaryProvider);
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (summary) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Visão Geral',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Resumo das principais métricas da igreja',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 24),

                // Membros Section
                _buildSectionTitle(context, 'Membros', Icons.people),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Total',
                        value: summary.totalMembers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Ativos',
                        value: summary.activeMembers.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  context,
                  title: 'Novos este mês',
                  value: summary.newMembersThisMonth.toString(),
                  icon: Icons.person_add,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),

                // Grupos e Ministérios Section
                _buildSectionTitle(context, 'Grupos & Ministérios', Icons.groups),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Grupos',
                        value: '${summary.activeGroups}/${summary.totalGroups}',
                        subtitle: 'Ativos/Total',
                        icon: Icons.group,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Ministérios',
                        value: summary.totalMinistries.toString(),
                        icon: Icons.volunteer_activism,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Visitantes Section
                _buildSectionTitle(context, 'Visitantes', Icons.person_search),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Total',
                        value: summary.totalVisitors.toString(),
                        icon: Icons.people_outline,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Novos este mês',
                        value: summary.newVisitorsThisMonth.toString(),
                        icon: Icons.person_add_outlined,
                        color: Colors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Cultos Section
                _buildSectionTitle(context, 'Cultos', Icons.church),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Cultos este mês',
                        value: summary.servicesThisMonth.toString(),
                        icon: Icons.event,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Média de presença',
                        value: summary.averageAttendance?.toStringAsFixed(0) ?? '0',
                        icon: Icons.trending_up,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Financeiro Section
                _buildSectionTitle(context, 'Financeiro', Icons.attach_money),
                const SizedBox(height: 12),
                _buildStatCard(
                  context,
                  title: 'Contribuições este mês',
                  value: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                      .format(summary.contributionsThisMonth),
                  icon: Icons.arrow_upward,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  context,
                  title: 'Despesas este mês',
                  value: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                      .format(summary.expensesThisMonth),
                  icon: Icons.arrow_downward,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  context,
                  title: 'Saldo líquido',
                  value: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                      .format(summary.netBalanceThisMonth),
                  icon: summary.netBalanceThisMonth >= 0
                      ? Icons.check_circle
                      : Icons.warning,
                  color: summary.netBalanceThisMonth >= 0
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(height: 24),

                // Relatórios Detalhados
                _buildSectionTitle(context, 'Relatórios Detalhados', Icons.analytics),
                const SizedBox(height: 12),
                _buildReportButton(
                  context,
                  title: 'Relatório de Membros',
                  subtitle: 'Crescimento, conversões e estatísticas',
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    context.push('/reports/members');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportButton(
                  context,
                  title: 'Relatório Financeiro',
                  subtitle: 'Receitas, despesas e metas',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  onTap: () {
                    context.push('/financial-reports');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportButton(
                  context,
                  title: 'Relatório de Cultos',
                  subtitle: 'Frequência e participação',
                  icon: Icons.church,
                  color: Colors.purple,
                  onTap: () {
                    context.push('/reports/attendance');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportButton(
                  context,
                  title: 'Relatório de Grupos',
                  subtitle: 'Participação e reuniões',
                  icon: Icons.groups,
                  color: Colors.orange,
                  onTap: () {
                    context.push('/reports/groups');
                  },
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar analytics: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
