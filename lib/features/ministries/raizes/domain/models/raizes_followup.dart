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

/// Casa de Vida (Grupo de Comunhão) para encaminhar o visitante (005400).
class RaizesLifeHouse {
  final String id;
  final String name;
  final String? address;
  final int? dayOfWeek;
  final String? time;
  final String? leaderName;

  const RaizesLifeHouse({
    required this.id,
    required this.name,
    this.address,
    this.dayOfWeek,
    this.time,
    this.leaderName,
  });

  factory RaizesLifeHouse.fromJson(Map<String, dynamic> j) => RaizesLifeHouse(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Casa de Vida',
    address: j['meeting_address'] as String?,
    dayOfWeek: j['meeting_day_of_week'] as int?,
    time: (j['meeting_time'] as String?)?.substring(0, 5),
    leaderName: j['leader_name'] as String?,
  );

  static const _days = [
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
  ];

  /// "Quarta 20:00 · Rua X · Líder: Ana" (só o que existir).
  String get details => [
    if (dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7)
      '${_days[dayOfWeek!]}${time == null ? '' : ' $time'}',
    if ((address ?? '').trim().isNotEmpty) address!.trim(),
    if ((leaderName ?? '').trim().isNotEmpty) 'Líder: ${leaderName!.trim()}',
  ].join(' · ');

  /// Mesmo bairro: o endereço do grupo cita o bairro do visitante.
  bool isNear(String? neighborhood) {
    final n = (neighborhood ?? '').trim().toLowerCase();
    return n.isNotEmpty && (address ?? '').toLowerCase().contains(n);
  }
}

/// Mais perto primeiro (mesmo bairro), depois por nome.
List<RaizesLifeHouse> sortLifeHouses(
  List<RaizesLifeHouse> houses,
  String? neighborhood,
) => [...houses]
  ..sort((a, b) {
    final na = a.isNear(neighborhood), nb = b.isNear(neighborhood);
    if (na != nb) return na ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

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

/// Relatório do Raízes (RPC `raizes_report`, 005500): só números.
class RaizesReport {
  /// Primeiro dia do período (o 1º do mês, [months] meses atrás).
  final DateTime since;

  /// Pessoas por etapa; quem não tem etapa conta como Visitante novo.
  final Map<RaizesStage, int> funnel;

  /// Cadastrados no período que querem contato (e já passaram de 24h).
  final int contactTotal;
  final int contactOnTime;
  final int contactLate;
  final int contactNone;

  /// Visitas no lar por responsável: (nome, total, feitas, em aberto).
  final List<({String name, int total, int completed, int open})> visits;

  /// Decisões por mês ('YYYY-MM') e tipo.
  final Map<String, Map<RaizesDecision, int>> decisionsByMonth;

  const RaizesReport({
    required this.since,
    required this.funnel,
    required this.contactTotal,
    required this.contactOnTime,
    required this.contactLate,
    required this.contactNone,
    required this.visits,
    required this.decisionsByMonth,
  });

  factory RaizesReport.fromJson(Map<String, dynamic> j) {
    final funnel = <RaizesStage, int>{};
    (j['funnel'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      final stage = RaizesStage.fromValue(k);
      funnel[stage] = (funnel[stage] ?? 0) + (v as num).toInt();
    });
    final c = j['contact_24h'] as Map<String, dynamic>? ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final decisions = <String, Map<RaizesDecision, int>>{};
    for (final d in (j['decisions'] as List? ?? const [])) {
      final type = RaizesDecision.fromValue(d['type'] as String?);
      if (type == null) continue;
      decisions.putIfAbsent(d['month'] as String, () => {})[type] = n(d['count']);
    }
    return RaizesReport(
      since: DateTime.parse(j['since'] as String),
      funnel: funnel,
      contactTotal: n(c['total']),
      contactOnTime: n(c['on_time']),
      contactLate: n(c['late']),
      contactNone: n(c['none']),
      visits: [
        for (final v in (j['visits'] as List? ?? const []))
          (
            name: v['name'] as String,
            total: n(v['total']),
            completed: n(v['completed']),
            open: n(v['open']),
          ),
      ],
      decisionsByMonth: decisions,
    );
  }
}
