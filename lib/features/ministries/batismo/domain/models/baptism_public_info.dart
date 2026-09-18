/// O que o formulário público de inscrição sabe sobre o curso.
///
/// Vem inteiro da RPC `baptism_public_registration_info`, que é a única
/// porta do anônimo para `ministry` e `baptism_turma` — ele não lê nenhuma
/// das duas tabelas por policy. Por isso este model é deliberadamente
/// magro: nome do curso e as turmas abertas, nada de aluno.
class BaptismPublicInfo {
  final String ministryName;
  final String? ministryDescription;
  final List<BaptismPublicTurma> turmas;

  const BaptismPublicInfo({
    required this.ministryName,
    this.ministryDescription,
    required this.turmas,
  });

  factory BaptismPublicInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['turmas'];
    final list = raw is List ? raw : const [];

    return BaptismPublicInfo(
      ministryName: (json['ministry_name'] as String?)?.trim().isNotEmpty == true
          ? json['ministry_name'] as String
          : 'Batismo',
      ministryDescription: (json['ministry_description'] as String?)?.trim(),
      turmas: [
        for (final item in list)
          if (item is Map)
            BaptismPublicTurma.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  bool get hasTurmas => turmas.isNotEmpty;
}

/// Uma turma oferecida no formulário público.
class BaptismPublicTurma {
  final String id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Data do batismo em si (o evento da agenda que a turma aponta), quando
  /// já está marcada.
  final DateTime? eventDate;

  const BaptismPublicTurma({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.eventDate,
  });

  factory BaptismPublicTurma.fromJson(Map<String, dynamic> json) {
    return BaptismPublicTurma(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Turma',
      description: (json['description'] as String?)?.trim(),
      startDate: _parse(json['start_date']),
      endDate: _parse(json['end_date']),
      eventDate: _parse(json['event_date']),
    );
  }

  static DateTime? _parse(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse('$raw');
  }
}
