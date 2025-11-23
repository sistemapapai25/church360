/// Modelo de Reunião de Grupo
class GroupMeeting {
  final String id;
  final String groupId;
  final DateTime meetingDate;
  final String? topic;
  final String? notes;
  final String? materialUrl; // URL do material ministrado
  final String? materialTitle; // Título do material
  final int totalAttendance;
  final DateTime createdAt;
  final String? createdBy;

  GroupMeeting({
    required this.id,
    required this.groupId,
    required this.meetingDate,
    this.topic,
    this.notes,
    this.materialUrl,
    this.materialTitle,
    required this.totalAttendance,
    required this.createdAt,
    this.createdBy,
  });

  /// Criar a partir de JSON
  factory GroupMeeting.fromJson(Map<String, dynamic> json) {
    return GroupMeeting(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      topic: json['topic'] as String?,
      notes: json['notes'] as String?,
      materialUrl: json['material_url'] as String?,
      materialTitle: json['material_title'] as String?,
      totalAttendance: json['total_attendance'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'meeting_date': meetingDate.toIso8601String().split('T')[0], // Apenas data
      'topic': topic,
      'notes': notes,
      'material_url': materialUrl,
      'material_title': materialTitle,
      'total_attendance': totalAttendance,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Copiar com alterações
  GroupMeeting copyWith({
    String? id,
    String? groupId,
    DateTime? meetingDate,
    String? topic,
    String? notes,
    String? materialUrl,
    String? materialTitle,
    int? totalAttendance,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return GroupMeeting(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      meetingDate: meetingDate ?? this.meetingDate,
      topic: topic ?? this.topic,
      notes: notes ?? this.notes,
      materialUrl: materialUrl ?? this.materialUrl,
      materialTitle: materialTitle ?? this.materialTitle,
      totalAttendance: totalAttendance ?? this.totalAttendance,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Modelo de Presença em Reunião
class GroupAttendance {
  final String id;
  final String meetingId;
  final String memberId;
  final String? memberName; // Computed from join
  final bool wasPresent;
  final String? notes;
  final DateTime createdAt;

  GroupAttendance({
    required this.id,
    required this.meetingId,
    required this.memberId,
    this.memberName,
    required this.wasPresent,
    this.notes,
    required this.createdAt,
  });

  /// Criar a partir de JSON
  factory GroupAttendance.fromJson(Map<String, dynamic> json) {
    return GroupAttendance(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      wasPresent: json['was_present'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_id': memberId,
      'was_present': wasPresent,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copiar com alterações
  GroupAttendance copyWith({
    String? id,
    String? meetingId,
    String? memberId,
    String? memberName,
    bool? wasPresent,
    String? notes,
    DateTime? createdAt,
  }) {
    return GroupAttendance(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      wasPresent: wasPresent ?? this.wasPresent,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

