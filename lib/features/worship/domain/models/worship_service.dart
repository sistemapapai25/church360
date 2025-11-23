/// Modelo de culto/serviço religioso
class WorshipService {
  final String id;
  final DateTime serviceDate;
  final String? serviceTime; // HH:mm format
  final WorshipType serviceType;
  final String? theme;
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

  factory WorshipService.fromJson(Map<String, dynamic> json) {
    return WorshipService(
      id: json['id'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      serviceTime: json['service_time'] as String?,
      serviceType: WorshipType.fromValue(json['service_type'] as String),
      theme: json['theme'] as String?,
      speaker: json['speaker'] as String?,
      totalAttendance: json['total_attendance'] as int? ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_date': serviceDate.toIso8601String().split('T')[0],
      'service_time': serviceTime,
      'service_type': serviceType.value,
      'theme': theme,
      'speaker': speaker,
      'total_attendance': totalAttendance,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WorshipService copyWith({
    String? id,
    DateTime? serviceDate,
    String? serviceTime,
    WorshipType? serviceType,
    String? theme,
    String? speaker,
    int? totalAttendance,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorshipService(
      id: id ?? this.id,
      serviceDate: serviceDate ?? this.serviceDate,
      serviceTime: serviceTime ?? this.serviceTime,
      serviceType: serviceType ?? this.serviceType,
      theme: theme ?? this.theme,
      speaker: speaker ?? this.speaker,
      totalAttendance: totalAttendance ?? this.totalAttendance,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Tipo de culto
enum WorshipType {
  sundayMorning('sunday_morning', 'Domingo Manhã'),
  sundayEvening('sunday_evening', 'Domingo Noite'),
  wednesday('wednesday', 'Quarta-feira'),
  friday('friday', 'Sexta-feira'),
  special('special', 'Especial'),
  other('other', 'Outro');

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

  const WorshipAttendance({
    required this.id,
    required this.worshipServiceId,
    required this.memberId,
    this.memberName,
    required this.checkedInAt,
    this.notes,
    required this.createdAt,
  });

  factory WorshipAttendance.fromJson(Map<String, dynamic> json) {
    return WorshipAttendance(
      id: json['id'] as String,
      worshipServiceId: json['worship_service_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'worship_service_id': worshipServiceId,
      'member_id': memberId,
      'checked_in_at': checkedInAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

