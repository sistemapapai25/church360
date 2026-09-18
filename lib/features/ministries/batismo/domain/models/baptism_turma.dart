/// Turma de um curso de batismo (`public.baptism_turma`).
///
/// O vínculo com a agenda é `eventId`, e é ele — não um `event_type` fixo —
/// que define "o evento de batismo daquela turma". O catálogo `event_type` é
/// por igreja (aqui o code em uso é `batismo_nas_águas`), então filtrar por
/// rótulo não sobreviveria à segunda igreja. Por isso a tela de turma tem um
/// seletor de evento, e não um filtro por tipo.
class BaptismTurma {
  final String id;
  final String tenantId;
  final String ministryId;

  /// Evento da agenda que é o batismo desta turma. Nulo enquanto a data
  /// ainda não foi marcada — a turma começa a ser montada antes disso.
  final String? eventId;

  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final BaptismTurmaStatus status;

  /// Quando `true`, a turma aparece no formulário público de inscrição e
  /// aceita gente entrando sem login. Nasce `false`: abrir é um ato
  /// explícito de quem cuida do ministério.
  final bool acceptsPublicRegistration;

  final DateTime createdAt;

  /// Nome do evento vindo do embed, quando a consulta o traz.
  final String? eventName;

  /// Data do evento vinda do embed, quando a consulta a traz.
  final DateTime? eventDate;

  const BaptismTurma({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    this.eventId,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.status,
    this.acceptsPublicRegistration = false,
    required this.createdAt,
    this.eventName,
    this.eventDate,
  });

  factory BaptismTurma.fromJson(Map<String, dynamic> json) {
    // O embed do evento chega como Map quando a consulta pede
    // `event(...)`; a lista vazia/ausente vira null sem estourar.
    final event = json['event'];
    final eventMap = event is Map<String, dynamic> ? event : null;

    return BaptismTurma(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      eventId: json['event_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      status: BaptismTurmaStatus.fromCode(json['status'] as String?),
      acceptsPublicRegistration:
          json['accepts_public_registration'] as bool? ?? false,
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      eventName: eventMap?['name'] as String?,
      eventDate: _parseDate(eventMap?['start_date']),
    );
  }

  /// Campos graváveis. `id`, `tenant_id` e `created_at` ficam de fora: o
  /// primeiro é a chave, os outros dois são do banco.
  Map<String, dynamic> toWriteJson() {
    return {
      'ministry_id': ministryId,
      'event_id': eventId,
      'name': name.trim(),
      'description': description?.trim(),
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'status': status.code,
      'accepts_public_registration': acceptsPublicRegistration,
    };
  }

  BaptismTurma copyWith({
    String? name,
    String? description,
    String? eventId,
    bool clearEventId = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    BaptismTurmaStatus? status,
    bool? acceptsPublicRegistration,
  }) {
    return BaptismTurma(
      id: id,
      tenantId: tenantId,
      ministryId: ministryId,
      eventId: clearEventId ? null : (eventId ?? this.eventId),
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      acceptsPublicRegistration:
          acceptsPublicRegistration ?? this.acceptsPublicRegistration,
      createdAt: createdAt,
      eventName: eventName,
      eventDate: eventDate,
    );
  }

  /// `start_date` e `end_date` são `DATE` no banco — de propósito, porque
  /// `DATE` escapa do contrato de "hora de parede rotulada como UTC" que
  /// vale para `event`. Mandar um timestamp aqui reintroduziria o problema.
  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse('$raw');
  }
}

/// Estados possíveis de uma turma — espelham o CHECK
/// `baptism_turma_status_valid`. Um valor fora desta lista é rejeitado pelo
/// banco, então [fromCode] cai em [ativa] em vez de estourar.
enum BaptismTurmaStatus {
  ativa('ativa', 'Ativa'),
  encerrada('encerrada', 'Encerrada'),
  cancelada('cancelada', 'Cancelada');

  final String code;
  final String label;

  const BaptismTurmaStatus(this.code, this.label);

  static BaptismTurmaStatus fromCode(String? code) {
    return BaptismTurmaStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => BaptismTurmaStatus.ativa,
    );
  }
}
