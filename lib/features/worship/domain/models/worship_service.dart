import '../../../ministries/shared/domain/ministry_routine.dart' show cultoWallTime;

/// Culto da Agenda: um `event` com `event_type` `culto%` (migration 004700).
/// Não há mais cadastro próprio de culto; criar e editar é pela Agenda.
class WorshipService {
  final String id;
  final DateTime serviceDate;
  final String? serviceTime; // HH:mm, hora de parede
  final WorshipType serviceType;
  final String? theme; // nome do evento
  final String? speaker;
  final int totalAttendance;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorshipService({
    required this.id,
    required this.serviceDate,
    this.serviceTime,
    required this.serviceType,
    this.theme,
    this.speaker,
    required this.totalAttendance,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Colunas lidas de `event`; `WorshipRepository` usa este select.
  static const eventSelect =
      'id, name, description, event_type, start_date, created_at, updated_at, '
      'worship_attendance(count), worship_attendance_count(total_people)';

  /// Linha de `event` com as contagens embutidas de [eventSelect].
  /// Presença = o maior entre os check-ins e a contagem do Diaconato.
  factory WorshipService.fromEvent(Map<String, dynamic> json) {
    final (date, time) = cultoWallTime(json['start_date'] as String?);
    final checkins = json['worship_attendance'];
    final checkinCount = checkins is List && checkins.isNotEmpty
        ? (checkins.first['count'] as num? ?? 0).toInt()
        : 0;
    var census = 0;
    final counts = json['worship_attendance_count'];
    if (counts is List) {
      for (final c in counts) {
        final n = (c['total_people'] as num? ?? 0).toInt();
        if (n > census) census = n;
      }
    }
    final createdAt = DateTime.parse(json['created_at'] as String);
    return WorshipService(
      id: json['id'] as String,
      serviceDate: date ?? createdAt,
      serviceTime: time,
      serviceType: WorshipType.fromValue(json['event_type'] as String? ?? ''),
      theme: json['name'] as String?,
      totalAttendance: checkinCount > census ? checkinCount : census,
      notes: json['description'] as String?,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          createdAt,
    );
  }
}

/// Tipo de culto = o `event_type` da Agenda.
enum WorshipType {
  sunday('culto_normal', 'Culto Domingo'),
  wednesday('culto_quarta', 'Culto Quarta'),
  communion('culto_de_ceia', 'Culto de Ceia'),
  drops('culto_drops', 'Culto Drops'),
  other('other', 'Outro culto');

  final String value;
  final String label;

  const WorshipType(this.value, this.label);

  static WorshipType fromValue(String value) {
    return WorshipType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => WorshipType.other,
    );
  }
}

/// Modelo de presença em culto
class WorshipAttendance {
  final String id;
  final String worshipServiceId;
  final String memberId;
  final String? memberName; // Populated from join
  final DateTime checkedInAt;
  final String? notes;
  final DateTime createdAt;

  /// O que a pessoa achou do culto (tela /presenca): otimo | gostando |
  /// mais_ou_menos. Nulo se não respondeu.
  final String? reaction;

  /// `manual` (Check-in do módulo Cultos) ou `geo` (o próprio celular).
  final String source;
  final int? distanceM;

  /// Presença pelo celular conferida por quem tem `worship.attendance`
  /// (migration 007100). Nulo = ainda não validada.
  final DateTime? validatedAt;

  const WorshipAttendance({
    required this.id,
    required this.worshipServiceId,
    required this.memberId,
    this.memberName,
    required this.checkedInAt,
    this.notes,
    required this.createdAt,
    this.reaction,
    this.source = 'manual',
    this.distanceM,
    this.validatedAt,
  });

  bool get isGeo => source == 'geo';

  /// Estados da presença pelo celular (A4): detectada (geo sem reação),
  /// confirmada (reagiu, ou manual) e validada (diácono conferiu).
  bool get isValidated => validatedAt != null;
  bool get isConfirmed => reaction != null || !isGeo;

  factory WorshipAttendance.fromJson(Map<String, dynamic> json) {
    return WorshipAttendance(
      id: json['id'] as String,
      worshipServiceId: json['event_id'] as String,
      memberId: json['user_id'] as String,
      memberName: json['member_name'] as String?,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reaction: json['reaction'] as String?,
      source: json['source'] as String? ?? 'manual',
      distanceM: (json['distance_m'] as num?)?.toInt(),
      validatedAt: DateTime.tryParse(json['validated_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': worshipServiceId,
      'user_id': memberId,
      'checked_in_at': checkedInAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
