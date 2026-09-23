// =====================================================
// CHURCH 360 - FINANCIAL MODELS: LANCAMENTO
// =====================================================

/// Tipo de lançamento
enum TipoLancamento {
  despesa('DESPESA', 'Despesa'),
  receita('RECEITA', 'Receita');

  final String value;
  final String label;

  const TipoLancamento(this.value, this.label);

  static TipoLancamento fromValue(String value) {
    return TipoLancamento.values.firstWhere(
      (tipo) => tipo.value == value,
      orElse: () => TipoLancamento.despesa,
    );
  }
}

/// Status do lançamento
enum StatusLancamento {
  emAberto('EM_ABERTO', 'Em Aberto'),
  pago('PAGO', 'Pago'),
  cancelado('CANCELADO', 'Cancelado');

  final String value;
  final String label;

  const StatusLancamento(this.value, this.label);

  static StatusLancamento fromValue(String value) {
    return StatusLancamento.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StatusLancamento.emAberto,
    );
  }
}

/// Situação de aprovação de um lançamento de ministério.
///
/// É uma coluna separada de [StatusLancamento] de propósito: `status` é o
/// ciclo de PAGAMENTO (em aberto / pago / cancelado), e reusá-lo faria
/// "pendente de aprovação" e "pendente de pagamento" virarem a mesma coisa.
///
/// Quem decide o valor é o banco, nunca o app: o trigger
/// `lancamentos_set_approval` sobrescreve o que vier no insert, e
/// `lancamentos_guard_approval` recusa (42501) quem tentar mudar a coluna
/// sem `ministry_finance.approve`.
enum AprovacaoLancamento {
  aprovado('APROVADO', 'Aprovado'),
  pendente('PENDENTE', 'Aguardando aprovação'),
  rejeitado('REJEITADO', 'Rejeitado');

  final String value;
  final String label;

  const AprovacaoLancamento(this.value, this.label);

  static AprovacaoLancamento fromValue(String? value) {
    return AprovacaoLancamento.values.firstWhere(
      (a) => a.value == value,
      // Lançamento da igreja nasce APROVADO; tratar desconhecido como
      // aprovado mantém o comportamento de antes desta coluna existir.
      orElse: () => AprovacaoLancamento.aprovado,
    );
  }
}

/// Que mudanca foi pedida num lancamento de ministerio e aguarda decisao.
///
/// Quem tem `ministry_finance.create` pede; quem tem `ministry_finance.approve`
/// decide. O lancamento vivo **nao muda** enquanto o pedido esta aberto — os
/// valores propostos ficam em `pendingPayload` e so sao aplicados na
/// aprovacao, o que e o que permite recusar sem precisar guardar o valor
/// anterior.
///
/// Quem decide e o banco: as colunas so sao escritas pelas RPCs
/// `request_lancamento_change` e `resolve_lancamento_change`, e o trigger
/// `lancamentos_guard_change_request` recusa (42501) UPDATE direto nelas.
enum PedidoLancamento {
  edicao('EDICAO', 'Edição aguardando aprovação'),
  exclusao('EXCLUSAO', 'Exclusão aguardando aprovação');

  final String value;
  final String label;

  const PedidoLancamento(this.value, this.label);

  static PedidoLancamento? fromValue(String? value) {
    if (value == null) return null;
    for (final p in PedidoLancamento.values) {
      if (p.value == value) return p;
    }
    return null;
  }
}

/// Forma de pagamento
enum FormaPagamento {
  pix('PIX', 'PIX'),
  dinheiro('DINHEIRO', 'Dinheiro'),
  cartao('CARTAO', 'Cartão'),
  boleto('BOLETO', 'Boleto'),
  transferencia('TRANSFERENCIA', 'Transferência'),
  outro('OUTRO', 'Outro');

  final String value;
  final String label;

  const FormaPagamento(this.value, this.label);

  static FormaPagamento fromValue(String value) {
    return FormaPagamento.values.firstWhere(
      (forma) => forma.value == value,
      orElse: () => FormaPagamento.outro,
    );
  }
}

/// Model: Lançamento Financeiro
class Lancamento {
  final String id;
  final TipoLancamento tipo;
  final String? beneficiarioId;
  final String categoriaId;
  final String? descricao;
  final double valor;
  final FormaPagamento? formaPagamento;
  final DateTime vencimento;
  final StatusLancamento status;
  final DateTime? dataPagamento;
  final double? valorPago;
  final String? observacoes;
  final String? boletoUrl;
  final String? comprovanteUrl;
  final int? reciboNumero;
  final int? reciboAno;
  final String? reciboPdfPath;
  final DateTime? reciboGeradoEm;
  final String? contaId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String tenantId;
  final String? createdBy;

  // Caixa do ministério (21/09). `ministryId` nulo é lançamento da igreja —
  // é ele que separa o livro-caixa geral do caixa do departamento.
  final String? ministryId;
  final AprovacaoLancamento approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;

  // Pedido de edicao/exclusao (23/09). Nulo = nenhum pedido em aberto.
  final PedidoLancamento? pendingChange;
  final Map<String, dynamic>? pendingPayload;
  final String? changeRequestedBy;
  final DateTime? changeRequestedAt;
  final String? changeReason;

  // Recorrência (opcional)
  final bool isRecurring;
  final String? recurrenceFrequency; // MONTHLY | WEEKLY | YEARLY
  final int recurrenceInterval;
  final int? recurrenceDayOfMonth;
  final DateTime? recurrenceEndDate;
  final List<int> notifyDaysBefore;
  final String? responsibleUserId;

  // Campos relacionados (joins)
  final String? beneficiarioNome;
  final String? categoriaNome;
  final String? contaNome;

  const Lancamento({
    required this.id,
    required this.tipo,
    this.beneficiarioId,
    required this.categoriaId,
    this.descricao,
    required this.valor,
    this.formaPagamento,
    required this.vencimento,
    required this.status,
    this.dataPagamento,
    this.valorPago,
    this.observacoes,
    this.boletoUrl,
    this.comprovanteUrl,
    this.reciboNumero,
    this.reciboAno,
    this.reciboPdfPath,
    this.reciboGeradoEm,
    this.contaId,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.tenantId,
    this.createdBy,
    this.ministryId,
    this.approvalStatus = AprovacaoLancamento.aprovado,
    this.approvedBy,
    this.approvedAt,
    this.pendingChange,
    this.pendingPayload,
    this.changeRequestedBy,
    this.changeRequestedAt,
    this.changeReason,
    this.isRecurring = false,
    this.recurrenceFrequency,
    this.recurrenceInterval = 1,
    this.recurrenceDayOfMonth,
    this.recurrenceEndDate,
    this.notifyDaysBefore = const [1, 0],
    this.responsibleUserId,
    this.beneficiarioNome,
    this.categoriaNome,
    this.contaNome,
  });

  factory Lancamento.fromJson(Map<String, dynamic> json) {
    List<int> parseNotifyDays(dynamic value) {
      if (value == null) return const [1, 0];
      if (value is List) {
        return value.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      }
      // Postgres array sometimes comes as "{1,0}"
      final raw = value.toString().replaceAll('{', '').replaceAll('}', '').trim();
      if (raw.isEmpty) return const [1, 0];
      return raw.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    }

    return Lancamento(
      id: json['id'] as String,
      tipo: TipoLancamento.fromValue(json['tipo'] as String),
      beneficiarioId: json['beneficiario_id'] as String?,
      categoriaId: json['categoria_id'] as String,
      descricao: json['descricao'] as String?,
      valor: (json['valor'] as num).toDouble(),
      formaPagamento: json['forma_pagamento'] != null
          ? FormaPagamento.fromValue(json['forma_pagamento'] as String)
          : null,
      vencimento: DateTime.parse(json['vencimento'] as String),
      status: StatusLancamento.fromValue(json['status'] as String? ?? 'EM_ABERTO'),
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'] as String)
          : null,
      valorPago: json['valor_pago'] != null ? (json['valor_pago'] as num).toDouble() : null,
      observacoes: json['observacoes'] as String?,
      boletoUrl: json['boleto_url'] as String?,
      comprovanteUrl: json['comprovante_url'] as String?,
      reciboNumero: json['recibo_numero'] as int?,
      reciboAno: json['recibo_ano'] as int?,
      reciboPdfPath: json['recibo_pdf_path'] as String?,
      reciboGeradoEm: json['recibo_gerado_em'] != null
          ? DateTime.parse(json['recibo_gerado_em'] as String)
          : null,
      contaId: json['conta_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String?,
      ministryId: json['ministry_id'] as String?,
      approvalStatus: AprovacaoLancamento.fromValue(
        json['approval_status'] as String?,
      ),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      pendingChange: PedidoLancamento.fromValue(
        json['pending_change'] as String?,
      ),
      pendingPayload: json['pending_payload'] as Map<String, dynamic>?,
      changeRequestedBy: json['change_requested_by'] as String?,
      changeRequestedAt: json['change_requested_at'] != null
          ? DateTime.parse(json['change_requested_at'] as String)
          : null,
      changeReason: json['change_reason'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceFrequency: json['recurrence_frequency'] as String?,
      recurrenceInterval: json['recurrence_interval'] as int? ?? 1,
      recurrenceDayOfMonth: json['recurrence_day_of_month'] as int?,
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.parse(json['recurrence_end_date'] as String)
          : null,
      notifyDaysBefore: parseNotifyDays(json['notify_days_before']),
      responsibleUserId: json['responsible_user_id'] as String?,
      // Campos relacionados (joins)
      beneficiarioNome: json['beneficiario'] != null
          ? json['beneficiario']['name'] as String?
          : null,
      categoriaNome: json['categoria'] != null
          ? json['categoria']['name'] as String?
          : null,
      contaNome: json['conta'] != null
          ? json['conta']['nome'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo.value,
      'beneficiario_id': beneficiarioId,
      'categoria_id': categoriaId,
      'descricao': descricao,
      'valor': valor,
      'forma_pagamento': formaPagamento?.value,
      'vencimento': vencimento.toIso8601String().split('T')[0], // Apenas data
      'status': status.value,
      'data_pagamento': dataPagamento?.toIso8601String().split('T')[0],
      'valor_pago': valorPago,
      'observacoes': observacoes,
      'boleto_url': boletoUrl,
      'comprovante_url': comprovanteUrl,
      'recibo_numero': reciboNumero,
      'recibo_ano': reciboAno,
      'recibo_pdf_path': reciboPdfPath,
      'recibo_gerado_em': reciboGeradoEm?.toIso8601String(),
      'conta_id': contaId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'tenant_id': tenantId,
      'created_by': createdBy,
      'ministry_id': ministryId,
      // `pending_change`, `pending_payload`, `change_requested_by` e
      // `change_requested_at` também ficam de fora, e pelo mesmo motivo:
      // quem escreve neles é o banco, pelas RPCs request_lancamento_change
      // e resolve_lancamento_change. UPDATE direto estoura 42501 no trigger
      // `lancamentos_guard_change_request`.
      // `approval_status`, `approved_by` e `approved_at` ficam de fora de
      // propósito: são escritos pelo banco. Mandar approval_status num
      // insert não adianta (o trigger sobrescreve) e mandá-lo num update
      // sem `ministry_finance.approve` estoura 42501 — o app não pode
      // eleger a si mesmo como aprovador.
      'is_recurring': isRecurring,
      'recurrence_frequency': recurrenceFrequency,
      'recurrence_interval': recurrenceInterval,
      'recurrence_day_of_month': recurrenceDayOfMonth,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String().split('T')[0],
      'notify_days_before': notifyDaysBefore,
      'responsible_user_id': responsibleUserId,
    };
  }

  Lancamento copyWith({
    String? id,
    TipoLancamento? tipo,
    String? beneficiarioId,
    String? categoriaId,
    String? descricao,
    double? valor,
    FormaPagamento? formaPagamento,
    DateTime? vencimento,
    StatusLancamento? status,
    DateTime? dataPagamento,
    double? valorPago,
    String? observacoes,
    String? boletoUrl,
    String? comprovanteUrl,
    int? reciboNumero,
    int? reciboAno,
    String? reciboPdfPath,
    DateTime? reciboGeradoEm,
    String? contaId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? tenantId,
    String? createdBy,
    String? ministryId,
    AprovacaoLancamento? approvalStatus,
    PedidoLancamento? pendingChange,
    Map<String, dynamic>? pendingPayload,
    String? changeRequestedBy,
    DateTime? changeRequestedAt,
    String? changeReason,
    String? approvedBy,
    DateTime? approvedAt,
    String? beneficiarioNome,
    String? categoriaNome,
    String? contaNome,
  }) {
    return Lancamento(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      beneficiarioId: beneficiarioId ?? this.beneficiarioId,
      categoriaId: categoriaId ?? this.categoriaId,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      vencimento: vencimento ?? this.vencimento,
      status: status ?? this.status,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      valorPago: valorPago ?? this.valorPago,
      observacoes: observacoes ?? this.observacoes,
      boletoUrl: boletoUrl ?? this.boletoUrl,
      comprovanteUrl: comprovanteUrl ?? this.comprovanteUrl,
      reciboNumero: reciboNumero ?? this.reciboNumero,
      reciboAno: reciboAno ?? this.reciboAno,
      reciboPdfPath: reciboPdfPath ?? this.reciboPdfPath,
      reciboGeradoEm: reciboGeradoEm ?? this.reciboGeradoEm,
      contaId: contaId ?? this.contaId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      ministryId: ministryId ?? this.ministryId,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      // Sem `?? this.x` teria efeito de apagar o pedido em aberto a cada
      // copyWith, em silêncio — o mesmo modo de falhar dos campos que o
      // PostgREST devolve NULL.
      pendingChange: pendingChange ?? this.pendingChange,
      pendingPayload: pendingPayload ?? this.pendingPayload,
      changeRequestedBy: changeRequestedBy ?? this.changeRequestedBy,
      changeRequestedAt: changeRequestedAt ?? this.changeRequestedAt,
      changeReason: changeReason ?? this.changeReason,
      beneficiarioNome: beneficiarioNome ?? this.beneficiarioNome,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      contaNome: contaNome ?? this.contaNome,
    );
  }

  // Propriedades computadas
  bool get isVencido => vencimento.isBefore(DateTime.now()) && status == StatusLancamento.emAberto;
  bool get isPago => status == StatusLancamento.pago;
  bool get isCancelado => status == StatusLancamento.cancelado;
  bool get isDespesa => tipo == TipoLancamento.despesa;
  bool get isReceita => tipo == TipoLancamento.receita;

  /// Lançamento de um departamento, e não do caixa geral da igreja.
  bool get isDeMinisterio => ministryId != null;
  bool get isPendenteAprovacao =>
      approvalStatus == AprovacaoLancamento.pendente;
  bool get isRejeitado => approvalStatus == AprovacaoLancamento.rejeitado;

  /// Tem pedido de edicao ou exclusao esperando decisao.
  bool get temPedidoAberto => pendingChange != null;
  bool get pediuExclusao => pendingChange == PedidoLancamento.exclusao;
  bool get pediuEdicao => pendingChange == PedidoLancamento.edicao;

  /// Precisa de alguem com `ministry_finance.approve`: ou nasceu pendente
  /// (saida de ministerio, trava D6) ou tem pedido de mudanca em aberto.
  bool get esperaDecisao => isPendenteAprovacao || temPedidoAberto;
}
