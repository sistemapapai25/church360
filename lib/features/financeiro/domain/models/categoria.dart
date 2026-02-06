// =====================================================
// CHURCH 360 - FINANCIAL MODELS: CATEGORIA
// =====================================================

/// Tipo de categoria
enum TipoCategoria {
  despesa('DESPESA', 'Despesa'),
  receita('RECEITA', 'Receita'),
  transferencia('TRANSFERENCIA', 'Transferência');

  final String value;
  final String label;

  const TipoCategoria(this.value, this.label);

  static TipoCategoria fromValue(String value) {
    return TipoCategoria.values.firstWhere(
      (tipo) => tipo.value == value,
      orElse: () => TipoCategoria.despesa,
    );
  }
}

/// Model: Categoria Financeira
class Categoria {
  final String id;
  final String name;
  final TipoCategoria tipo;
  final String? parentId;
  final int ordem;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final String tenantId;
  final String? createdBy;

  // Campos relacionados (joins)
  final String? parentName;
  final List<Categoria>? subcategorias;

  const Categoria({
    required this.id,
    required this.name,
    required this.tipo,
    this.parentId,
    required this.ordem,
    this.deletedAt,
    required this.createdAt,
    required this.tenantId,
    this.createdBy,
    this.parentName,
    this.subcategorias,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as String,
      name: json['name'] as String,
      tipo: TipoCategoria.fromValue(json['tipo'] as String? ?? 'DESPESA'),
      parentId: json['parent_id'] as String?,
      ordem: json['ordem'] as int? ?? 0,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String?,
      // Campos relacionados
      parentName: json['parent'] != null
          ? json['parent']['name'] as String?
          : null,
      subcategorias: json['subcategorias'] != null
          ? (json['subcategorias'] as List)
              .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tipo': tipo.value,
      'parent_id': parentId,
      'ordem': ordem,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'tenant_id': tenantId,
      'created_by': createdBy,
    };
  }

  Categoria copyWith({
    String? id,
    String? name,
    TipoCategoria? tipo,
    String? parentId,
    int? ordem,
    DateTime? deletedAt,
    DateTime? createdAt,
    String? tenantId,
    String? createdBy,
    String? parentName,
    List<Categoria>? subcategorias,
  }) {
    return Categoria(
      id: id ?? this.id,
      name: name ?? this.name,
      tipo: tipo ?? this.tipo,
      parentId: parentId ?? this.parentId,
      ordem: ordem ?? this.ordem,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      parentName: parentName ?? this.parentName,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }

  // Propriedades computadas
  bool get isAtiva => deletedAt == null;
  bool get isSubcategoria => parentId != null;
  bool get hasSubcategorias => subcategorias != null && subcategorias!.isNotEmpty;
}

