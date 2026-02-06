// =====================================================
// CHURCH 360 - CONTAS SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/conta_financeira.dart';
import '../../../../core/design/community_design.dart';

class ContasScreen extends ConsumerWidget {
  const ContasScreen({super.key});

  static const _financialGreen = Color(0xFF1D6E45);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Contas Financeiras'),
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
        body: _buildBody(context, ref, currencyFormat),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, NumberFormat currencyFormat) {
    final contasAsync = ref.watch(allContasProvider);

    return contasAsync.when(
      data: (contas) => _buildContasList(context, contas, currencyFormat),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar contas: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildContasList(BuildContext context, List<ContaFinanceira> contas, NumberFormat currencyFormat) {
    if (contas.isEmpty) {
      return const Center(
        child: Text('Nenhuma conta encontrada'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contas.length,
      itemBuilder: (context, index) {
        final conta = contas[index];
        return _buildContaCard(context, conta, currencyFormat);
      },
    );
  }

  Widget _buildContaCard(BuildContext context, ContaFinanceira conta, NumberFormat currencyFormat) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: _financialGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conta.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (conta.hasInstituicao)
                      Text(
                        conta.instituicao!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tipo: ${conta.tipo}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              Text(
                currencyFormat.format(conta.saldoInicial),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _financialGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

