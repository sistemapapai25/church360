// =====================================================
// CHURCH 360 - FINANCIAL MODELS: CONTA FINANCEIRA
// =====================================================

/// Model: Conta Financeira
class ContaFinanceira {
  final String id;
  final String nome;
  final String tipo;
  final String? instituicao;
  final String? agencia;
  final String? numero;
  final double saldoInicial;
  final DateTime? saldoInicialEm;
  final String? logo;
  final DateTime createdAt;
  final String tenantId;
  final String? createdBy;

  // Campos computados (não vêm do banco)
  final double? saldoAtual;

  const ContaFinanceira({
    required this.id,
    required this.nome,
    required this.tipo,
    this.instituicao,
    this.agencia,
    this.numero,
    required this.saldoInicial,
    this.saldoInicialEm,
    this.logo,
    required this.createdAt,
    required this.tenantId,
    this.createdBy,
    this.saldoAtual,
  });

  factory ContaFinanceira.fromJson(Map<String, dynamic> json) {
    return ContaFinanceira(
      id: json['id'] as String,
      nome: json['nome'] as String,
      tipo: json['tipo'] as String,
      instituicao: json['instituicao'] as String?,
      agencia: json['agencia'] as String?,
      numero: json['numero'] as String?,
      saldoInicial: (json['saldo_inicial'] as num?)?.toDouble() ?? 0.0,
      saldoInicialEm: json['saldo_inicial_em'] != null
          ? DateTime.parse(json['saldo_inicial_em'] as String)
          : null,
      logo: json['logo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String?,
      saldoAtual: json['saldo_atual'] != null
          ? (json['saldo_atual'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'instituicao': instituicao,
      'agencia': agencia,
      'numero': numero,
      'saldo_inicial': saldoInicial,
      'saldo_inicial_em': saldoInicialEm?.toIso8601String().split('T')[0],
      'logo': logo,
      'created_at': createdAt.toIso8601String(),
      'tenant_id': tenantId,
      'created_by': createdBy,
    };
  }

  ContaFinanceira copyWith({
    String? id,
    String? nome,
    String? tipo,
    String? instituicao,
    String? agencia,
    String? numero,
    double? saldoInicial,
    DateTime? saldoInicialEm,
    String? logo,
    DateTime? createdAt,
    String? tenantId,
    String? createdBy,
    double? saldoAtual,
  }) {
    return ContaFinanceira(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      instituicao: instituicao ?? this.instituicao,
      agencia: agencia ?? this.agencia,
      numero: numero ?? this.numero,
      saldoInicial: saldoInicial ?? this.saldoInicial,
      saldoInicialEm: saldoInicialEm ?? this.saldoInicialEm,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      saldoAtual: saldoAtual ?? this.saldoAtual,
    );
  }

  // Propriedades computadas
  bool get hasLogo => logo != null && logo!.isNotEmpty;
  bool get hasInstituicao => instituicao != null && instituicao!.isNotEmpty;
  String get displayName {
    if (hasInstituicao) {
      return '$nome - $instituicao';
    }
    return nome;
  }
}

