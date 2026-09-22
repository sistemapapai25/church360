import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/financeiro/domain/models/dashboard_data.dart';
import 'package:church360_app/features/financeiro/domain/models/financial_attachment.dart';
import 'package:church360_app/features/financeiro/presentation/providers/financeiro_providers.dart';
import 'package:church360_app/features/financeiro/presentation/screens/financeiro_dashboard_screen.dart';
import 'package:church360_app/features/financeiro/presentation/widgets/confidence_badge_widget.dart';

DashboardData _dashboard() {
  return const DashboardData(
    receitasPrevistas: 1800,
    receitasRecebidas: 1500,
    despesasPrevistas: 900,
    despesasPagas: 700,
    saldoPrevisto: 900,
    saldoRealizado: 800,
    totalReceitas: 1500,
    totalDespesas: 700,
    saldo: 800,
    lancamentosEmAberto: 2,
    lancamentosVencidos: 0,
    receitasPorCategoria: [
      ReceitaPorCategoria(
        categoriaId: 'dizimos',
        categoriaNome: 'Dízimos',
        total: 1500,
      ),
    ],
    despesasPorCategoria: [
      DespesaPorCategoria(
        categoriaId: 'aluguel',
        categoriaNome: 'Aluguel',
        total: 700,
      ),
    ],
    saldosPorConta: [
      SaldoPorConta(contaId: 'principal', contaNome: 'Caixa', saldo: 800),
    ],
  );
}

void main() {
  testWidgets(
    'dashboard financeiro usa cards GlassCard nas superfícies principais',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardDataProvider.overrideWith((ref) async => _dashboard()),
          ],
          child: const MaterialApp(home: FinanceiroDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(7));
      expect(find.text('Recebidas'), findsOneWidget);
      expect(find.text('Receitas por Categoria'), findsOneWidget);
      expect(find.text('Dízimos'), findsOneWidget);
    },
  );

  testWidgets('badge de confiança financeiro preserva o status visual', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConfidenceBadgeWidget(
              level: ConfidenceLevel.high,
              score: 0.94,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Alta Confiança'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
  });
}
