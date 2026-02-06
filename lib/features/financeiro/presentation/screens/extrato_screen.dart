// =====================================================
// CHURCH 360 - EXTRATO SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/lancamento.dart';
import '../../../../core/design/community_design.dart';

class ExtratoScreen extends ConsumerStatefulWidget {
  const ExtratoScreen({super.key});

  @override
  ConsumerState<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends ConsumerState<ExtratoScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Extrato'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/financial');
              }
            },
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildPeriodSelector(),
        Expanded(child: _buildExtrato()),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [CommunityDesign.overlayBaseShadow()],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectStartDate(),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'De',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(_dateFormat.format(_startDate)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _selectEndDate(),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Até',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(_dateFormat.format(_endDate)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrato() {
    final lancamentosAsync = ref.watch(filteredLancamentosProvider(
      LancamentosFilter(
        startDate: _startDate,
        endDate: _endDate,
      ),
    ));

    return lancamentosAsync.when(
      data: (lancamentos) => _buildExtratoLoaded(lancamentos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar extrato: $error'),
      ),
    );
  }

  Widget _buildExtratoLoaded(List<Lancamento> lancamentos) {
    if (lancamentos.isEmpty) {
      return const Center(
        child: Text('Nenhum lançamento no período selecionado'),
      );
    }

    final totalReceitas = lancamentos
        .where((l) => l.isReceita && l.isPago)
        .fold(0.0, (sum, l) => sum + l.valor);
    final totalDespesas = lancamentos
        .where((l) => l.isDespesa && l.isPago)
        .fold(0.0, (sum, l) => sum + l.valor);
    final saldo = totalReceitas - totalDespesas;

    return Column(
      children: [
        _buildSummary(totalReceitas, totalDespesas, saldo),
        Expanded(child: _buildLancamentosList(lancamentos)),
      ],
    );
  }

  Widget _buildSummary(double totalReceitas, double totalDespesas, double saldo) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Receitas', totalReceitas, Colors.green),
          _buildSummaryItem('Despesas', totalDespesas, Colors.red),
          _buildSummaryItem('Saldo', saldo, saldo >= 0 ? _financialGreen : Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLancamentosList(List<Lancamento> lancamentos) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: lancamentos.length,
      itemBuilder: (context, index) {
        final lancamento = lancamentos[index];
        return _buildLancamentoItem(lancamento);
      },
    );
  }

  Widget _buildLancamentoItem(Lancamento lancamento) {
    return ListTile(
      leading: Icon(
        lancamento.isDespesa ? Icons.arrow_downward : Icons.arrow_upward,
        color: lancamento.isDespesa ? Colors.red : Colors.green,
      ),
      title: Text(lancamento.descricao ?? '-'),
      subtitle: Text(_dateFormat.format(lancamento.vencimento)),
      trailing: Text(
        _currencyFormat.format(lancamento.valor),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: lancamento.isDespesa ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }
}

