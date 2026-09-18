/// Turma de um curso de batismo (`public.baptism_turma`).
///
/// O vínculo com a agenda é `eventTypeCode` + o período (`startDate` →
/// `endDate`): os eventos daquela categoria dentro daquela janela são os
/// encontros da turma. Um curso é uma série — as aulas MAIS a cerimônia —,
/// e a coluna de evento único que existia antes só comportava uma das duas.
///
/// O catálogo `event_type` é por igreja, e isso continua respeitado: a
/// categoria é escolhida por turma, na tela, a partir do catálogo daquela
/// igreja. O que não sobrevive à segunda igreja é um filtro FIXO por
/// rótulo, e não é o caso aqui.
class BaptismTurma {
  final String id;
  final String tenantId;
  final String ministryId;

  /// Categoria da agenda (`event_type.code`) cujos eventos contam como
  /// encontros desta turma. Nulo enquanto ninguém escolheu.
  final String? eventTypeCode;

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

  /// Rótulo da categoria, resolvido pelo catálogo carregado na tela. Não
  /// vem do banco: um embed por `event_type` conviveria com a FK que
  /// `event` também tem para o catálogo, e o PostgREST precisaria de
  /// desambiguação. O catálogo já é carregado de qualquer forma para o
  /// seletor, então casar o rótulo no cliente sai mais barato e não
  /// depende do formato do embed.
  final String? eventTypeLabel;

  const BaptismTurma({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    this.eventTypeCode,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.status,
    this.acceptsPublicRegistration = false,
    required this.createdAt,
    this.eventTypeLabel,
  });

  factory BaptismTurma.fromJson(Map<String, dynamic> json) {
    return BaptismTurma(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      eventTypeCode: json['event_type_code'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      status: BaptismTurmaStatus.fromCode(json['status'] as String?),
      acceptsPublicRegistration:
          json['accepts_public_registration'] as bool? ?? false,
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  /// Campos graváveis. `id`, `tenant_id` e `created_at` ficam de fora: o
  /// primeiro é a chave, os outros dois são do banco. `event_id` também
  /// fica de fora — a coluna ainda existe no banco (o DROP espera uma
  /// migration própria), e não mandá-la preserva o valor legado das
  /// turmas antigas em vez de zerá-lo a cada edição.
  Map<String, dynamic> toWriteJson() {
    return {
      'ministry_id': ministryId,
      'event_type_code': eventTypeCode,
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
    String? eventTypeCode,
    bool clearEventTypeCode = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    BaptismTurmaStatus? status,
    bool? acceptsPublicRegistration,
    String? eventTypeLabel,
  }) {
    return BaptismTurma(
      id: id,
      tenantId: tenantId,
      ministryId: ministryId,
      eventTypeCode:
          clearEventTypeCode ? null : (eventTypeCode ?? this.eventTypeCode),
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      acceptsPublicRegistration:
          acceptsPublicRegistration ?? this.acceptsPublicRegistration,
      createdAt: createdAt,
      eventTypeLabel: eventTypeLabel ?? this.eventTypeLabel,
    );
  }

  /// A turma tem janela fechada? Sem as duas pontas ela recolheria todo
  /// evento novo da categoria para sempre — é o "infinito" que o período
  /// existe para impedir. O formulário exige as duas; turmas criadas
  /// antes desta regra podem estar sem, e é isto que as denuncia.
  bool get hasWindow => startDate != null && endDate != null;

  /// Um evento da agenda é encontro desta turma? Recebe os campos soltos
  /// em vez do modelo `Event` de propósito: o domínio do batismo não
  /// precisa depender do módulo de eventos para responder isso.
  ///
  /// A comparação é feita em data de parede, sem conversão de fuso, e é
  /// o certo aqui: `event.start_date` guarda a hora de parede de São
  /// Paulo rotulada como UTC, e `start_date`/`end_date` da turma são
  /// `DATE`. Converter para instante deslocaria o evento em 3h e faria
  /// uma aula das 20h de uma quinta cair na sexta seguinte.
  bool coversEvent({String? eventTypeCode, DateTime? eventStart}) {
    final code = this.eventTypeCode;
    if (code == null || eventTypeCode != code) return false;
    if (eventStart == null || !hasWindow) return false;

    final day = DateTime(eventStart.year, eventStart.month, eventStart.day);
    final from = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final to = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !day.isBefore(from) && !day.isAfter(to);
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
