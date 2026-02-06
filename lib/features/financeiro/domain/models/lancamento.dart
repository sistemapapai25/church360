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
    this.beneficiarioNome,
    this.categoriaNome,
    this.contaNome,
  });

  factory Lancamento.fromJson(Map<String, dynamic> json) {
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
}

