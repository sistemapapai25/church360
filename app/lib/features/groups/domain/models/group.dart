/// Modelo de Grupo/Célula
class Group {
  final String id;
  final String name;
  final String? description;
  final String? leaderId;
  final String? leaderName; // Computed from join
  final String? campusId;
  final int? meetingDayOfWeek; // 0=Domingo, 6=Sábado
  final String? meetingTime;
  final String? meetingAddress;
  final bool isActive;
  final int? memberCount; // Computed from join
  final DateTime createdAt;
  final DateTime? updatedAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.leaderId,
    this.leaderName,
    this.campusId,
    this.meetingDayOfWeek,
    this.meetingTime,
    this.meetingAddress,
    this.isActive = true,
    this.memberCount,
    required this.createdAt,
    this.updatedAt,
  });

  /// Retorna o nome do dia da semana
  String? get meetingDayName {
    if (meetingDayOfWeek == null) return null;
    const days = [
      'Domingo',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
    ];
    return days[meetingDayOfWeek!];
  }

  /// Criar a partir de JSON
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      leaderId: json['leader_id'] as String?,
      leaderName: json['leader_name'] as String?,
      campusId: json['campus_id'] as String?,
      meetingDayOfWeek: json['meeting_day_of_week'] as int?,
      meetingTime: json['meeting_time'] as String?,
      meetingAddress: json['meeting_address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      memberCount: json['member_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'leader_id': leaderId,
      'campus_id': campusId,
      'meeting_day_of_week': meetingDayOfWeek,
      'meeting_time': meetingTime,
      'meeting_address': meetingAddress,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copiar com modificações
  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? leaderId,
    String? leaderName,
    String? campusId,
    int? meetingDayOfWeek,
    String? meetingTime,
    String? meetingAddress,
    bool? isActive,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      leaderId: leaderId ?? this.leaderId,
      leaderName: leaderName ?? this.leaderName,
      campusId: campusId ?? this.campusId,
      meetingDayOfWeek: meetingDayOfWeek ?? this.meetingDayOfWeek,
      meetingTime: meetingTime ?? this.meetingTime,
      meetingAddress: meetingAddress ?? this.meetingAddress,
      isActive: isActive ?? this.isActive,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo de Membro do Grupo
class GroupMember {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName; // Computed from join
  final String? role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    this.role,
    required this.joinedAt,
  });

  /// Criar a partir de JSON
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      role: json['role'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

/// Modelo de Reunião do Grupo
class GroupMeeting {
  final String id;
  final String groupId;
  final DateTime meetingDate;
  final String? topic;
  final String? notes;
  final int? attendanceCount; // Computed
  final DateTime createdAt;

  GroupMeeting({
    required this.id,
    required this.groupId,
    required this.meetingDate,
    this.topic,
    this.notes,
    this.attendanceCount,
    required this.createdAt,
  });

  /// Criar a partir de JSON
  factory GroupMeeting.fromJson(Map<String, dynamic> json) {
    return GroupMeeting(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      topic: json['topic'] as String?,
      notes: json['notes'] as String?,
      attendanceCount: json['attendance_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'meeting_date': meetingDate.toIso8601String(),
      'topic': topic,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

