// =====================================================
// CHURCH 360 - LANÇAMENTOS LIST SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/lancamento.dart';
import '../../../../core/design/community_design.dart';

class LancamentosListScreen extends ConsumerStatefulWidget {
  const LancamentosListScreen({super.key});

  @override
  ConsumerState<LancamentosListScreen> createState() => _LancamentosListScreenState();
}

class _LancamentosListScreenState extends ConsumerState<LancamentosListScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // Filtros
  TipoLancamento? _tipoFilter;
  StatusLancamento? _statusFilter;
  String? _categoriaFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/financial');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Builder(
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildDesktopLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Lançamentos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/financial/lancamentos/new'),
          ),
        ],
      ),
      body: _buildLancamentosList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/financial/lancamentos/new'),
        backgroundColor: _financialGreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Lançamentos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text('Filtros'),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/financial/lancamentos/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Lançamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _financialGreen,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _buildLancamentosList(),
        ),
      ),
    );
  }

  Widget _buildLancamentosList() {
    final lancamentosAsync = ref.watch(filteredLancamentosProvider(
      LancamentosFilter(
        startDate: _startDate,
        endDate: _endDate,
        tipo: _tipoFilter,
        status: _statusFilter,
        categoriaId: _categoriaFilter,
      ),
    ));

    return lancamentosAsync.when(
      data: (lancamentos) => _buildLancamentosLoaded(lancamentos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar lançamentos: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildLancamentosLoaded(List<Lancamento> lancamentos) {
    if (lancamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum lançamento encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/financial/lancamentos/new'),
              icon: const Icon(Icons.add),
              label: const Text('Criar Lançamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _financialGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (isDesktop) {
          return _buildDesktopTable(lancamentos);
        } else {
          return _buildMobileList(lancamentos);
        }
      },
    );
  }

  Widget _buildDesktopTable(List<Lancamento> lancamentos) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: CommunityDesign.overlayDecoration(colorScheme),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest,
          ),
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Descrição')),
            DataColumn(label: Text('Categoria')),
            DataColumn(label: Text('Beneficiário')),
            DataColumn(label: Text('Valor')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ações')),
          ],
          rows: lancamentos.map((lancamento) {
            return DataRow(
              cells: [
                DataCell(Text(_dateFormat.format(lancamento.vencimento))),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      lancamento.descricao ?? '-',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(lancamento.categoriaNome ?? '-')),
                DataCell(Text(lancamento.beneficiarioNome ?? '-')),
                DataCell(
                  Text(
                    _currencyFormat.format(lancamento.valor),
                    style: TextStyle(
                      color: lancamento.isDespesa ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(_buildStatusBadge(lancamento.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => context.push('/financial/lancamentos/${lancamento.id}'),
                        tooltip: 'Editar',
                      ),
                      if (lancamento.status == StatusLancamento.emAberto)
                        IconButton(
                          icon: const Icon(Icons.check_circle, size: 18),
                          onPressed: () => _pagarLancamento(lancamento),
                          tooltip: 'Pagar',
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<Lancamento> lancamentos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lancamentos.length,
      itemBuilder: (context, index) {
        final lancamento = lancamentos[index];
        return _buildLancamentoCard(lancamento);
      },
    );
  }

  Widget _buildLancamentoCard(Lancamento lancamento) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      child: InkWell(
        onTap: () => context.push('/financial/lancamentos/${lancamento.id}'),
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      lancamento.descricao ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(lancamento.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    lancamento.isDespesa ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                    color: lancamento.isDespesa ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currencyFormat.format(lancamento.valor),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: lancamento.isDespesa ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _dateFormat.format(lancamento.vencimento),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (lancamento.categoriaNome != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.category, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lancamento.categoriaNome!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StatusLancamento status) {
    Color color;
    String label;

    switch (status) {
      case StatusLancamento.pago:
        color = Colors.green;
        label = 'Pago';
        break;
      case StatusLancamento.emAberto:
        color = Colors.orange;
        label = 'Em Aberto';
        break;
      case StatusLancamento.cancelado:
        color = Colors.grey;
        label = 'Cancelado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '-';
    return _dateFormat.format(value);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final categoriasAsync = ref.watch(allCategoriasProvider);

          TipoLancamento? tipo = _tipoFilter;
          StatusLancamento? status = _statusFilter;
          String? categoriaId = _categoriaFilter;
          DateTime? startDate = _startDate;
          DateTime? endDate = _endDate;

          return StatefulBuilder(
            builder: (context, setLocalState) {
              Future<void> pickStartDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked == null) return;
                setLocalState(() => startDate = picked);
              }

              Future<void> pickEndDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? (startDate ?? DateTime.now()),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked == null) return;
                setLocalState(() => endDate = picked);
              }

              return AlertDialog(
                title: const Text('Filtros'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<TipoLancamento?>(
                          key: ValueKey(tipo),
                          initialValue: tipo,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...TipoLancamento.values.map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            ),
                          ],
                          onChanged: (value) => setLocalState(() => tipo = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<StatusLancamento?>(
                          key: ValueKey(status),
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...StatusLancamento.values.map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            ),
                          ],
                          onChanged: (value) => setLocalState(() => status = value),
                        ),
                        const SizedBox(height: 12),
                        categoriasAsync.when(
                          data: (categorias) {
                            final sorted = [...categorias]
                              ..sort((a, b) => a.name.compareTo(b.name));
                            return DropdownButtonFormField<String?>(
                              key: ValueKey(categoriaId),
                              initialValue: categoriaId,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todas'),
                                ),
                                ...sorted.map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setLocalState(() => categoriaId = value),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Erro ao carregar categorias: $e'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: pickStartDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Data inicial: ${_dateLabel(startDate)}'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: pickEndDate,
                          icon: const Icon(Icons.event),
                          label: Text('Data final: ${_dateLabel(endDate)}'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tipoFilter = null;
                        _statusFilter = null;
                        _categoriaFilter = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Limpar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      var nextStart = startDate;
                      var nextEnd = endDate;
                      if (nextStart != null &&
                          nextEnd != null &&
                          nextStart.isAfter(nextEnd)) {
                        final tmp = nextStart;
                        nextStart = nextEnd;
                        nextEnd = tmp;
                      }
                      setState(() {
                        _tipoFilter = tipo;
                        _statusFilter = status;
                        _categoriaFilter = categoriaId;
                        _startDate = nextStart;
                        _endDate = nextEnd;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Aplicar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pagarLancamento(Lancamento lancamento) async {
    try {
      final repo = ref.read(lancamentosRepositoryProvider);
      await repo.pagarLancamento(
        id: lancamento.id,
        dataPagamento: DateTime.now(),
        valorPago: lancamento.valor,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lançamento pago com sucesso!')),
        );
        ref.invalidate(filteredLancamentosProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao pagar lançamento: $e')),
        );
      }
    }
  }
}
