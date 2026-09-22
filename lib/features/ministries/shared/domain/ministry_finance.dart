import '../../../financeiro/domain/models/lancamento.dart';

/// Uma opção do catálogo de apoio do caixa do ministério: categoria ou
/// beneficiário.
///
/// Só id e nome. É o que a RPC `ministry_finance_catalog` devolve, e é de
/// propósito que não haja mais nada aqui: `beneficiaries` guarda documento,
/// telefone e e-mail, e nada disso precisa sair da tabela para um formulário
/// de departamento funcionar.
class MinistryFinanceOption {
  final String id;
  final String name;

  /// Só para categoria: `DESPESA`, `RECEITA` ou `TRANSFERENCIA`, cru como
  /// vem do banco. Beneficiário não tem tipo.
  final String? tipo;

  const MinistryFinanceOption({
    required this.id,
    required this.name,
    this.tipo,
  });
}

/// O catálogo inteiro, como a aba precisa dele.
class MinistryFinanceCatalog {
  final List<MinistryFinanceOption> categorias;
  final List<MinistryFinanceOption> beneficiarios;

  const MinistryFinanceCatalog({
    required this.categorias,
    required this.beneficiarios,
  });

  static const empty = MinistryFinanceCatalog(
    categorias: [],
    beneficiarios: [],
  );

  /// Categorias que servem a um tipo de lançamento. `TRANSFERENCIA` entra
  /// nas duas listas: é rubrica de movimentação, não de entrada ou saída.
  List<MinistryFinanceOption> categoriasDe(TipoLancamento tipo) {
    return categorias
        .where((c) => c.tipo == tipo.value || c.tipo == 'TRANSFERENCIA')
        .toList();
  }

  String? nomeDeCategoria(String? id) => _nome(categorias, id);

  String? nomeDeBeneficiario(String? id) => _nome(beneficiarios, id);

  static String? _nome(List<MinistryFinanceOption> onde, String? id) {
    if (id == null) return null;
    for (final o in onde) {
      if (o.id == id) return o.name;
    }
    return null;
  }
}

/// Os números do caixa do departamento, calculados sobre a lista já lida.
///
/// Não existe view nem RPC de saldo: a conta é feita aqui, como o dashboard
/// da igreja também faz. A régua é explícita:
///
/// - entrada e saída só entram no saldo quando estão **aprovadas** e não
///   canceladas — o que espera confirmação não é dinheiro do departamento
///   ainda, é pedido;
/// - a fila é só de saída `PENDENTE`, que é a única coisa que o trigger
///   `lancamentos_set_approval` deixa nascer pendente.
class MinistryFinanceSummary {
  final double entradas;
  final double saidas;
  final int pendentesCount;
  final double pendentesTotal;

  const MinistryFinanceSummary({
    required this.entradas,
    required this.saidas,
    required this.pendentesCount,
    required this.pendentesTotal,
  });

  double get saldo => entradas - saidas;

  factory MinistryFinanceSummary.from(List<Lancamento> lancamentos) {
    double entradas = 0;
    double saidas = 0;
    int pendentesCount = 0;
    double pendentesTotal = 0;

    for (final l in lancamentos) {
      if (l.isCancelado) continue;

      if (l.isPendenteAprovacao) {
        pendentesCount++;
        pendentesTotal += l.valor;
        continue;
      }
      if (l.isRejeitado) continue;

      // Aprovado: o realizado manda quando existe, como no dashboard da
      // igreja (`valor_pago` quando pago, senão o previsto).
      final valor = l.isPago ? (l.valorPago ?? l.valor) : l.valor;
      if (l.isReceita) {
        entradas += valor;
      } else {
        saidas += valor;
      }
    }

    return MinistryFinanceSummary(
      entradas: entradas,
      saidas: saidas,
      pendentesCount: pendentesCount,
      pendentesTotal: pendentesTotal,
    );
  }
}
