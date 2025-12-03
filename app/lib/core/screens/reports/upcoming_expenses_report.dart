import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/financial/domain/models/contribution.dart';

/// Enum para períodos de filtro
enum ExpensePeriod {
  next7Days('Próximos 7 dias'),
  next15Days('Próximos 15 dias'),
  next30Days('Próximos 30 dias'),
  next60Days('Próximos 60 dias'),
  next90Days('Próximos 90 dias'),
  custom('Personalizado');

  final String label;
  const ExpensePeriod(this.label);
}

/// Provider para despesas futuras com filtro de período
final upcomingExpensesByPeriodProvider = FutureProvider.family<List<Expense>, (DateTime, DateTime)>(
  (ref, dates) async {
    final supabase = ref.watch(supabaseClientProvider);
    final (startDate, endDate) = dates;

    final response = await supabase
        .from('expense')
        .select()
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0])
        .order('date', ascending: true);

    return (response as List).map((json) => Expense.fromJson(json)).toList();
  },
);

/// Tela de relatório de próximas despesas/contas a pagar
class UpcomingExpensesReportScreen extends ConsumerStatefulWidget {
  const UpcomingExpensesReportScreen({super.key});

  @override
  ConsumerState<UpcomingExpensesReportScreen> createState() =>
      _UpcomingExpensesReportScreenState();
}

class _UpcomingExpensesReportScreenState
    extends ConsumerState<UpcomingExpensesReportScreen> {
  ExpensePeriod _selectedPeriod = ExpensePeriod.next30Days;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();
    final expensesAsync = ref.watch(upcomingExpensesByPeriodProvider((startDate, endDate)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximas Contas a Pagar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(upcomingExpensesByPeriodProvider);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de Período
          _buildPeriodFilter(),

          // Lista de Despesas
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(upcomingExpensesByPeriodProvider);
              },
              child: expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'Nenhuma despesa agendada',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Não há contas a pagar neste período',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Calcular total
                  final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
                  final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

                  // Agrupar por categoria
                  final Map<String, List<Expense>> expensesByCategory = {};
                  for (final expense in expenses) {
                    expensesByCategory.putIfAbsent(expense.category, () => []).add(expense);
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Card de Resumo
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total a Pagar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    formatter.format(total),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${expenses.length} ${expenses.length == 1 ? 'despesa' : 'despesas'}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  Text(
                                    '${expensesByCategory.length} ${expensesByCategory.length == 1 ? 'categoria' : 'categorias'}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de Despesas
                      ...expenses.map((expense) {
                        final now = DateTime.now();
                        final daysUntil = expense.date.difference(now).inDays;
                        final isOverdue = expense.date.isBefore(now);
                        final isToday = daysUntil == 0;
                        final isThisWeek = daysUntil <= 7 && daysUntil > 0;

                        Color statusColor = Colors.blue;
                        String statusText = 'Em $daysUntil dias';

                        if (isOverdue) {
                          statusColor = Colors.red;
                          statusText = 'VENCIDA';
                        } else if (isToday) {
                          statusColor = Colors.orange;
                          statusText = 'HOJE';
                        } else if (isThisWeek) {
                          statusColor = Colors.amber;
                          statusText = 'Esta semana';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                color: statusColor,
                              ),
                            ),
                            title: Text(
                              expense.description,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.category, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(expense.category),
                                    const SizedBox(width: 12),
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(DateFormat('dd/MM/yyyy').format(expense.date)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              formatter.format(expense.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro: $error'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o intervalo de datas baseado no período selecionado
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case ExpensePeriod.next7Days:
        return (now, now.add(const Duration(days: 7)));
      case ExpensePeriod.next15Days:
        return (now, now.add(const Duration(days: 15)));
      case ExpensePeriod.next30Days:
        return (now, now.add(const Duration(days: 30)));
      case ExpensePeriod.next60Days:
        return (now, now.add(const Duration(days: 60)));
      case ExpensePeriod.next90Days:
        return (now, now.add(const Duration(days: 90)));
      case ExpensePeriod.custom:
        return (
          _customStartDate ?? now,
          _customEndDate ?? now.add(const Duration(days: 30)),
        );
    }
  }

  /// Filtro de período
  Widget _buildPeriodFilter() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpensePeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == ExpensePeriod.custom) {
                        _showCustomDatePicker();
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostrar seletor de datas personalizado
  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Data Inicial',
    );

    if (startDate != null && mounted) {
      final endDate = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? startDate.add(const Duration(days: 30)),
        firstDate: startDate,
        lastDate: DateTime(now.year + 2),
        helpText: 'Data Final',
      );

      if (endDate != null && mounted) {
        setState(() {
          _customStartDate = startDate;
          _customEndDate = endDate;
        });
      }
    }
  }
}
