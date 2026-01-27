import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/contribution.dart';
import '../providers/financial_provider.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela principal do sistema financeiro
class FinancialScreen extends ConsumerStatefulWidget {
  const FinancialScreen({super.key});

  @override
  ConsumerState<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends ConsumerState<FinancialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Atualiza o FAB quando a tab muda
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text('Financeiro', style: CommunityDesign.titleStyle(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              context.push('/financial-reports');
            },
            tooltip: 'Relatórios',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Contribuições', icon: Icon(Icons.attach_money)),
            Tab(text: 'Despesas', icon: Icon(Icons.money_off)),
            Tab(text: 'Metas', icon: Icon(Icons.flag)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ContributionsTab(),
          _ExpensesTab(),
          _GoalsTab(),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: _tabController.index == 0
            ? 'financial.create_contribution'
            : _tabController.index == 1
                ? 'financial.create_expense'
                : 'financial.manage_goals',
        showLoading: false,
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_tabController.index == 0) {
              // Criar contribuição
              context.push('/contributions/new');
            } else if (_tabController.index == 1) {
              // Criar despesa
              context.push('/expenses/new');
            } else {
              // Criar meta
              context.push('/financial-goals/new');
            }
          },
          icon: const Icon(Icons.add),
          label: Text(
            _tabController.index == 0
                ? 'Nova Contribuição'
                : _tabController.index == 1
                    ? 'Nova Despesa'
                    : 'Nova Meta',
          ),
        ),
      ),
    );
  }
}

/// Tab de contribuições
class _ContributionsTab extends ConsumerWidget {
  const _ContributionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(allContributionsProvider);
    final totalAsync = ref.watch(totalContributionsProvider);

    return contributionsAsync.when(
      data: (contributions) {
        return Column(
          children: [
            // Card de resumo
            totalAsync.when(
              data: (total) => _buildSummaryCard(
                context,
                'Total de Contribuições',
                total,
                Colors.green,
                Icons.trending_up,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),

            // Lista de contribuições
            Expanded(
              child: contributions.isEmpty
                  ? _buildEmptyState(
                      'Nenhuma contribuição registrada',
                      'Adicione a primeira contribuição',
                      Icons.attach_money,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: contributions.length,
                      itemBuilder: (context, index) {
                        final contribution = contributions[index];
                        return _ContributionCard(contribution: contribution);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(value),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de contribuição
class _ContributionCard extends StatelessWidget {
  final Contribution contribution;

  const _ContributionCard({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(contribution.type).withValues(alpha: 0.2),
          child: Icon(
            _getTypeIcon(contribution.type),
            color: _getTypeColor(contribution.type),
          ),
        ),
        title: Text(
          contribution.memberName ?? 'Anônimo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contribution.type.label),
            Text(
              dateFormatter.format(contribution.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (contribution.description != null)
              Text(
                contribution.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatter.format(contribution.amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getTypeColor(contribution.type),
              ),
            ),
            Text(
              contribution.paymentMethod.label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          context.push('/contributions/${contribution.id}/edit');
        },
      ),
    );
  }

  Color _getTypeColor(ContributionType type) {
    switch (type) {
      case ContributionType.tithe:
        return Colors.green;
      case ContributionType.offering:
        return Colors.blue;
      case ContributionType.missions:
        return Colors.purple;
      case ContributionType.building:
        return Colors.orange;
      case ContributionType.special:
        return Colors.pink;
      case ContributionType.other:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(ContributionType type) {
    switch (type) {
      case ContributionType.tithe:
        return Icons.volunteer_activism;
      case ContributionType.offering:
        return Icons.card_giftcard;
      case ContributionType.missions:
        return Icons.public;
      case ContributionType.building:
        return Icons.construction;
      case ContributionType.special:
        return Icons.celebration;
      case ContributionType.other:
        return Icons.attach_money;
    }
  }
}

/// Tab de despesas
class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final totalAsync = ref.watch(totalExpensesProvider);

    return expensesAsync.when(
      data: (expenses) {
        return Column(
          children: [
            // Card de resumo
            totalAsync.when(
              data: (total) => _buildSummaryCard(
                context,
                'Total de Despesas',
                total,
                Colors.red,
                Icons.trending_down,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),

            // Lista de despesas
            Expanded(
              child: expenses.isEmpty
                  ? _buildEmptyState(
                      'Nenhuma despesa registrada',
                      'Adicione a primeira despesa',
                      Icons.money_off,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return _ExpenseCard(expense: expense);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(value),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de despesa (continua no próximo arquivo)
class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withValues(alpha: 0.2),
          child: const Icon(Icons.money_off, color: Colors.red),
        ),
        title: Text(
          expense.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.description),
            Text(
              dateFormatter.format(expense.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatter.format(expense.amount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            Text(
              expense.paymentMethod.label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          context.push('/expenses/${expense.id}/edit');
        },
      ),
    );
  }
}

/// Tab de metas (placeholder por enquanto)
class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma meta ativa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie metas financeiras para sua igreja',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            return _GoalCard(goal: goal);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

/// Card de meta
class _GoalCard extends StatelessWidget {
  final FinancialGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          context.push('/financial-goals/${goal.id}/edit');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${goal.progressPercentage}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            if (goal.description != null) ...[
              const SizedBox(height: 8),
              Text(
                goal.description!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: goal.progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arrecadado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      formatter.format(goal.currentAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Meta',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      formatter.format(goal.targetAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
