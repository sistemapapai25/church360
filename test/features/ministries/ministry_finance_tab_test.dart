import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/financeiro/domain/models/lancamento.dart';
import 'package:church360_app/features/ministries/shared/domain/ministry_finance.dart';
import 'package:church360_app/features/ministries/shared/presentation/providers/ministry_finance_providers.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_finance_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

Lancamento _lancamento({
  required String id,
  TipoLancamento tipo = TipoLancamento.despesa,
  double valor = 100,
  AprovacaoLancamento aprovacao = AprovacaoLancamento.aprovado,
  StatusLancamento status = StatusLancamento.emAberto,
  double? valorPago,
  String? descricao,
  String? categoriaNome,
  String? beneficiarioNome,
}) {
  return Lancamento(
    id: id,
    tipo: tipo,
    categoriaId: 'cat-1',
    valor: valor,
    vencimento: DateTime(2026, 9, 20),
    status: status,
    valorPago: valorPago,
    createdAt: DateTime(2026, 9, 20),
    tenantId: 't1',
    ministryId: _ministryId,
    approvalStatus: aprovacao,
    descricao: descricao,
    categoriaNome: categoriaNome,
    beneficiarioNome: beneficiarioNome,
  );
}

Widget _host(
  List<Lancamento> lancamentos, {
  bool canView = true,
  bool canCreate = false,
  bool canApprove = false,
}) {
  return ProviderScope(
    overrides: [
      ministryFinanceAccessProvider(_ministryId).overrideWith(
        (ref) async => MinistryFinanceAccess(
          canView: canView,
          canCreate: canCreate,
          canApprove: canApprove,
        ),
      ),
      ministryFinanceLancamentosProvider(
        _ministryId,
      ).overrideWith((ref) async => lancamentos),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: MinistryFinanceTab(ministryId: _ministryId)),
    ),
  );
}

void main() {
  group('MinistryFinanceSummary', () {
    test('saida pendente fica fora do saldo e vai para a fila', () {
      final summary = MinistryFinanceSummary.from([
        _lancamento(id: '1', tipo: TipoLancamento.receita, valor: 500),
        _lancamento(
          id: '2',
          valor: 200,
          aprovacao: AprovacaoLancamento.pendente,
        ),
      ]);

      // O que espera aprovacao ainda nao e dinheiro do departamento.
      expect(summary.entradas, 500);
      expect(summary.saidas, 0);
      expect(summary.saldo, 500);
      expect(summary.pendentesCount, 1);
      expect(summary.pendentesTotal, 200);
    });

    test('rejeitado e cancelado nao entram em conta nenhuma', () {
      final summary = MinistryFinanceSummary.from([
        _lancamento(
          id: '1',
          valor: 300,
          aprovacao: AprovacaoLancamento.rejeitado,
        ),
        _lancamento(id: '2', valor: 400, status: StatusLancamento.cancelado),
      ]);

      expect(summary.saidas, 0);
      expect(summary.pendentesCount, 0);
      expect(summary.saldo, 0);
    });

    test('saida aprovada e paga usa o valor realizado', () {
      final summary = MinistryFinanceSummary.from([
        _lancamento(
          id: '1',
          valor: 100,
          status: StatusLancamento.pago,
          valorPago: 90,
        ),
      ]);

      expect(summary.saidas, 90);
      expect(summary.saldo, -90);
    });
  });

  testWidgets('sem permissao a aba diz por que, em vez de lista vazia', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const [], canView: false));
    await tester.pumpAndSettle();

    expect(find.text('Caixa do ministério fechado para você'), findsOneWidget);
    expect(find.text('Novo lançamento'), findsNothing);
  });

  testWidgets('quem so enxerga nao ganha o botao de lancar', (tester) async {
    await tester.pumpWidget(
      _host([_lancamento(id: '1', descricao: 'Aluguel do som')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aluguel do som'), findsOneWidget);
    expect(find.text('Novo lançamento'), findsNothing);
  });

  testWidgets('com ministry_finance.create o botao de lancar aparece', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const [], canCreate: true));
    await tester.pumpAndSettle();

    expect(find.text('Novo lançamento'), findsOneWidget);
  });

  testWidgets('saida pendente entra na fila sem botao para quem nao aprova', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _lancamento(
          id: '1',
          valor: 200,
          aprovacao: AprovacaoLancamento.pendente,
          descricao: 'Compra de camisetas',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('AGUARDANDO APROVAÇÃO (1)'), findsOneWidget);
    expect(find.text('Compra de camisetas'), findsOneWidget);
    // Sem ministry_finance.approve, nada de botao: a policy do banco
    // recusaria o update e o botao aceso seria mentira.
    expect(find.text('Aprovar'), findsNothing);
    expect(find.text('Rejeitar'), findsNothing);
  });

  testWidgets('com ministry_finance.approve os dois botoes entram', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _lancamento(
          id: '1',
          valor: 200,
          aprovacao: AprovacaoLancamento.pendente,
          descricao: 'Compra de camisetas',
        ),
      ], canApprove: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aprovar'), findsOneWidget);
    expect(find.text('Rejeitar'), findsOneWidget);
  });

  testWidgets('o resumo avisa quanto esta fora do saldo', (tester) async {
    await tester.pumpWidget(
      _host([
        _lancamento(id: '1', tipo: TipoLancamento.receita, valor: 500),
        _lancamento(
          id: '2',
          valor: 200,
          aprovacao: AprovacaoLancamento.pendente,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saldo do departamento'), findsOneWidget);
    expect(find.textContaining('1 saída espera aprovação'), findsOneWidget);
  });

  testWidgets('estado vazio nao promete botao que a pessoa nao tem', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(
      find.text('O caixa deste ministério ainda não tem lançamento nenhum.'),
      findsOneWidget,
    );
  });
}
