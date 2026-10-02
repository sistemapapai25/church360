import 'package:intl/intl.dart';

/// Unidades aceitas pelo banco (`ministry_stock_item_unit_check`).
const List<String> kStockUnits = ['un', 'kg', 'g', 'L', 'mL', 'cx', 'pct', 'm'];

/// Item do estoque de um ministério (`public.ministry_stock_item`).
///
/// `quantity` só muda por RPC: o cliente não tem escrita na tabela.
class StockItem {
  final String id;
  final String ministryId;
  final String name;
  final String? category;
  final String unit;
  final String? location;
  final String? notes;
  final double quantity;
  final double? minQuantity;
  final DateTime? archivedAt;

  const StockItem({
    required this.id,
    required this.ministryId,
    required this.name,
    this.category,
    required this.unit,
    this.location,
    this.notes,
    required this.quantity,
    this.minQuantity,
    this.archivedAt,
  });

  bool get archived => archivedAt != null;

  /// Mesma régua do alerta do banco: chegou no mínimo ou abaixo dele.
  bool get isLow => minQuantity != null && quantity <= minQuantity!;

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    ministryId: json['ministry_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String?,
    unit: json['unit'] as String,
    location: json['location'] as String?,
    notes: json['notes'] as String?,
    quantity: (json['quantity'] as num).toDouble(),
    minQuantity: (json['min_quantity'] as num?)?.toDouble(),
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
  );
}

/// Os cinco movimentos do banco. `correcao` é interno: nasce do "Corrigir".
enum StockMoveKind {
  saida('saida', 'Saída'),
  entrada('entrada', 'Entrada'),
  ajuste('ajuste', 'Ajuste'),
  conferencia('conferencia', 'Conferência'),
  correcao('correcao', 'Correção');

  final String value;
  final String label;

  const StockMoveKind(this.value, this.label);

  static StockMoveKind? from(String? value) {
    for (final k in values) {
      if (k.value == value) return k;
    }
    return null;
  }
}

/// Linha de `ministry_stock_history`.
class StockMovement {
  final String id;
  final StockMoveKind kind;
  final double delta;
  final double quantityAfter;
  final String? note;
  final String? reversesId;
  final bool reverted;
  final String? createdBy;
  final String? who;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.kind,
    required this.delta,
    required this.quantityAfter,
    this.note,
    this.reversesId,
    required this.reverted,
    this.createdBy,
    this.who,
    required this.createdAt,
  });

  /// Na conferência `delta = contado - esperado`.
  double get expected => quantityAfter - delta;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: json['id'] as String,
    kind: StockMoveKind.from(json['kind'] as String?) ?? StockMoveKind.ajuste,
    delta: (json['delta'] as num).toDouble(),
    quantityAfter: (json['quantity_after'] as num).toDouble(),
    note: json['note'] as String?,
    reversesId: json['reverses_id'] as String?,
    reverted: json['reverted'] as bool? ?? false,
    createdBy: json['created_by'] as String?,
    who: json['who'] as String?,
    // Carimbo de `now()`: UTC de verdade, então `toLocal()` é o certo aqui.
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

/// Linha de `ministry_audit_feed` (Caixa + Estoque).
class AuditEntry {
  final DateTime happenedAt;

  /// `caixa` ou `estoque`.
  final String area;

  /// `CREATE|UPDATE|DELETE|STATUS_CHANGE` (trilha da `auditoria`) ou o
  /// `kind` do movimento de estoque.
  final String action;
  final String? subject;
  final String? refId;
  final Map<String, dynamic>? antes;
  final Map<String, dynamic>? depois;
  final double? delta;
  final double? quantityAfter;
  final String? note;
  final String? who;

  const AuditEntry({
    required this.happenedAt,
    required this.area,
    required this.action,
    this.subject,
    this.refId,
    this.antes,
    this.depois,
    this.delta,
    this.quantityAfter,
    this.note,
    this.who,
  });

  bool get isCaixa => area == 'caixa';

  /// Movimento de estoque (não cadastro do item).
  bool get isMovement => !isCaixa && StockMoveKind.from(action) != null;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    happenedAt: DateTime.parse(json['happened_at'] as String).toLocal(),
    area: json['area'] as String,
    action: json['action'] as String,
    subject: json['subject'] as String?,
    refId: json['ref_id'] as String?,
    antes: json['antes'] as Map<String, dynamic>?,
    depois: json['depois'] as Map<String, dynamic>?,
    delta: (json['delta'] as num?)?.toDouble(),
    quantityAfter: (json['quantity_after'] as num?)?.toDouble(),
    note: json['note'] as String?,
    who: json['who'] as String?,
  );
}

/// Os lados da aba Financeiro.
enum FinanceSide { caixa, estoque, auditoria }

/// Lados que a pessoa pode abrir, na ordem da pílula (D1/D2): só aparece o
/// que ela pode abrir, sem botão bloqueado.
List<FinanceSide> financeSides({
  required bool caixa,
  required bool estoque,
  required bool auditoria,
}) => [
  if (caixa) FinanceSide.caixa,
  if (estoque) FinanceSide.estoque,
  if (auditoria) FinanceSide.auditoria,
];

/// Lê quantidade digitada no Brasil: `2,5`, `1.234,5`, `3`. Sem vírgula, o
/// ponto vale como decimal (`2.5`). Mesma lógica de `_parseValor` do caixa.
double? parseStockQuantity(String raw) {
  final limpo = raw.trim();
  if (limpo.isEmpty) return null;
  final normalizado = limpo.contains(',')
      ? limpo.replaceAll('.', '').replaceAll(',', '.')
      : limpo;
  return double.tryParse(normalizado);
}

final NumberFormat _qty = NumberFormat.decimalPattern('pt_BR')
  ..maximumFractionDigits = 3;

/// `1234.5` → `1.234,5`; `3.0` → `3`.
String formatStockQuantity(num value) => _qty.format(value);

/// Delta com sinal: `+500`, `−50`.
String formatStockDelta(num value) =>
    '${value > 0 ? '+' : (value < 0 ? '−' : '')}${formatStockQuantity(value.abs())}';
