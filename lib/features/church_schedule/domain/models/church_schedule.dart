/// Modelo de Agenda da Igreja
class ChurchSchedule {
  final String id;
  final String title;
  final String? description;
  final String scheduleType;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String? location;
  final String? responsibleId;
  final String? responsibleName;
  final String recurrenceType;
  final DateTime? recurrenceEndDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const ChurchSchedule({
    required this.id,
    required this.title,
    this.description,
    required this.scheduleType,
    required this.startDatetime,
    required this.endDatetime,
    this.location,
    this.responsibleId,
    this.responsibleName,
    this.recurrenceType = 'none',
    this.recurrenceEndDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory ChurchSchedule.fromJson(Map<String, dynamic> json) {
    return ChurchSchedule(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduleType: json['schedule_type'] as String,
      startDatetime: DateTime.parse(json['start_datetime'] as String),
      endDatetime: DateTime.parse(json['end_datetime'] as String),
      location: json['location'] as String?,
      responsibleId: json['responsible_id'] as String?,
      responsibleName: json['responsible_name'] as String?,
      recurrenceType: json['recurrence_type'] as String? ?? 'none',
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.parse(json['recurrence_end_date'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'schedule_type': scheduleType,
      'start_datetime': startDatetime.toIso8601String(),
      'end_datetime': endDatetime.toIso8601String(),
      'location': location,
      'responsible_id': responsibleId,
      'recurrence_type': recurrenceType,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

/// Tipos de agenda
enum ScheduleType {
  rehearsal('rehearsal', 'Ensaio'),
  meeting('meeting', 'Reunião'),
  study('study', 'Estudo'),
  prayer('prayer', 'Oração'),
  other('other', 'Outro');

  final String value;
  final String label;

  const ScheduleType(this.value, this.label);

  static ScheduleType fromValue(String value) {
    return ScheduleType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ScheduleType.other,
    );
  }
}

/// Tipos de recorrência
enum RecurrenceType {
  none('none', 'Não se repete'),
  daily('daily', 'Diariamente'),
  weekly('weekly', 'Semanalmente'),
  monthly('monthly', 'Mensalmente');

  final String value;
  final String label;

  const RecurrenceType(this.value, this.label);

  static RecurrenceType fromValue(String value) {
    return RecurrenceType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RecurrenceType.none,
    );
  }
}

