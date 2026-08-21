/// Uma unidade (matriz ou filial) da rede do usuário atual, conforme
/// devolvido pela RPC `listar_minhas_igrejas()` (CHU-299).
class TenantUnit {
  final String tenantId;
  final String name;
  final String kind; // 'matriz' | 'filial' | 'independente'
  final String? parentTenantId;
  final bool isCurrent;

  const TenantUnit({
    required this.tenantId,
    required this.name,
    required this.kind,
    this.parentTenantId,
    required this.isCurrent,
  });

  factory TenantUnit.fromJson(Map<String, dynamic> json) => TenantUnit(
        tenantId: json['tenant_id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
        parentTenantId: json['parent_tenant_id'] as String?,
        isCurrent: json['is_current'] as bool? ?? false,
      );

  bool get isMatriz => kind == 'matriz';
  bool get isFilial => kind == 'filial';
}
