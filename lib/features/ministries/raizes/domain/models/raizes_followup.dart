/// Acompanhamento do Projeto Raízes (migration 004900): etapa atual,
/// histórico de etapas e contatos. Etapa, decisão e contato são coisas
/// diferentes: a etapa é marcada à mão; o contato é um acontecimento.
library;

/// Os 11 status do manual (§13). `null` no banco = visitante novo.
enum RaizesStage {
  visitanteNovo('visitante_novo', 'Visitante novo'),
  contactado('contactado', 'Contactado'),
  retornou('retornou', 'Retornou'),
  emAcompanhamento('em_acompanhamento', 'Em acompanhamento'),
  aceitouJesus('aceitou_jesus', 'Aceitou Jesus'),
  reconciliacao('reconciliacao', 'Reconciliação'),
  encaminhadoCasaVida('encaminhado_casa_vida', 'Encaminhado para Casa de Vida'),
  emDiscipulado('em_discipulado', 'Em discipulado'),
  emAulasBatismo('em_aulas_batismo', 'Em aulas de batismo'),
  novoMembro('novo_membro', 'Novo membro'),
  integradoDepartamento('integrado_departamento', 'Integrado em departamento');

  final String value;
  final String label;
  const RaizesStage(this.value, this.label);

  /// Etapa do banco; `null` ou desconhecida vira Visitante novo.
  static RaizesStage fromValue(String? value) => RaizesStage.values.firstWhere(
    (s) => s.value == value,
    orElse: () => RaizesStage.visitanteNovo,
  );
}

/// Decisão espiritual (manual §11), separada da etapa.
enum RaizesDecision {
  acceptedJesus('accepted_jesus', 'Aceitou Jesus'),
  reconciliation('reconciliation', 'Reconciliação'),
  pastoralSupport('pastoral_support', 'Apoio pastoral');

  final String value;
  final String label;
  const RaizesDecision(this.value, this.label);

  static RaizesDecision? fromValue(String? value) {
    for (final d in RaizesDecision.values) {
      if (d.value == value) return d;
    }
    return null;
  }

  /// Etapa que o app sugere depois de registrar a decisão.
  RaizesStage? get suggestedStage => switch (this) {
    RaizesDecision.acceptedJesus => RaizesStage.aceitouJesus,
    RaizesDecision.reconciliation => RaizesStage.reconciliacao,
    RaizesDecision.pastoralSupport => null,
  };
}

enum RaizesContactKind {
  whatsapp('whatsapp', 'WhatsApp'),
  ligacao('ligacao', 'Ligação'),
  visita('visita', 'Visita'),
  presencial('presencial', 'Presencial'),
  outro('outro', 'Outro');

  final String value;
  final String label;
  const RaizesContactKind(this.value, this.label);

  static RaizesContactKind fromValue(String? value) =>
      RaizesContactKind.values.firstWhere(
        (k) => k.value == value,
        orElse: () => RaizesContactKind.outro,
      );
}

/// Um item da linha do tempo: contato registrado ou mudança de etapa.
class RaizesTimelineEntry {
  final DateTime when;
  final String title;
  final String? detail;
  final String? byName;
  final bool isContact;

  const RaizesTimelineEntry({
    required this.when,
    required this.title,
    this.detail,
    this.byName,
    required this.isContact,
  });

  static String? _name(Object? row) {
    if (row is! Map) return null;
    final full = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
    return full.isEmpty ? null : full;
  }

  factory RaizesTimelineEntry.fromContact(Map<String, dynamic> j) =>
      RaizesTimelineEntry(
        when: DateTime.parse(j['followup_date'] as String),
        title:
            'Contato: ${RaizesContactKind.fromValue(j['followup_type'] as String?).label}',
        detail: j['description'] as String?,
        byName: _name(j['by']),
        isContact: true,
      );

  factory RaizesTimelineEntry.fromStage(Map<String, dynamic> j) =>
      RaizesTimelineEntry(
        when: DateTime.parse(j['changed_at'] as String).toLocal(),
        title:
            'Etapa: ${RaizesStage.fromValue(j['from_stage'] as String?).label} → '
            '${RaizesStage.fromValue(j['to_stage'] as String?).label}',
        detail: j['note'] as String?,
        byName: _name(j['by']),
        isContact: false,
      );
}
