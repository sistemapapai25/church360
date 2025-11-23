/// Modelo de Ministério
class Ministry {
  final String id;
  final String name;
  final String? description;
  final String? icon; // Nome do ícone Font Awesome
  final String color;
  final String? leaderId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Dados do líder (quando incluído na query)
  final String? leaderName;
  final String? leaderPhoto;

  // Contagem de membros (quando incluído na query)
  final int? memberCount;

  Ministry({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.color,
    this.leaderId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.leaderName,
    this.leaderPhoto,
    this.memberCount,
  });

  factory Ministry.fromJson(Map<String, dynamic> json) {
    return Ministry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String? ?? '#2196F3',
      leaderId: json['leader_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      leaderName: json['leader_name'] as String?,
      leaderPhoto: json['leader_photo'] as String?,
      memberCount: json['member_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'leader_id': leaderId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Ministry copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? leaderId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? leaderName,
    String? leaderPhoto,
    int? memberCount,
  }) {
    return Ministry(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      leaderId: leaderId ?? this.leaderId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      leaderName: leaderName ?? this.leaderName,
      leaderPhoto: leaderPhoto ?? this.leaderPhoto,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  String toString() {
    return 'Ministry(id: $id, name: $name, isActive: $isActive, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ministry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enum para função no ministério
enum MinistryRole {
  leader('leader', 'Líder'),
  coordinator('coordinator', 'Coordenador'),
  member('member', 'Membro');

  final String value;
  final String label;

  const MinistryRole(this.value, this.label);

  static MinistryRole fromString(String value) {
    return MinistryRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => MinistryRole.member,
    );
  }
}

/// Modelo de Membro do Ministério
class MinistryMember {
  final String id;
  final String ministryId;
  final String memberId;
  final String memberName;
  final MinistryRole role;
  final DateTime joinedAt;
  final String? notes;
  final DateTime createdAt;

  MinistryMember({
    required this.id,
    required this.ministryId,
    required this.memberId,
    required this.memberName,
    required this.role,
    required this.joinedAt,
    this.notes,
    required this.createdAt,
  });

  factory MinistryMember.fromJson(Map<String, dynamic> json) {
    return MinistryMember(
      id: json['id'] as String,
      ministryId: json['ministry_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String? ?? '',
      role: MinistryRole.fromString(json['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ministry_id': ministryId,
      'member_id': memberId,
      'member_name': memberName,
      'role': role.value,
      'joined_at': joinedAt.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MinistryMember copyWith({
    String? id,
    String? ministryId,
    String? memberId,
    String? memberName,
    MinistryRole? role,
    DateTime? joinedAt,
    String? notes,
    DateTime? createdAt,
  }) {
    return MinistryMember(
      id: id ?? this.id,
      ministryId: ministryId ?? this.ministryId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Modelo de Escala de Ministério
class MinistrySchedule {
  final String id;
  final String eventId;
  final String eventName;
  final String ministryId;
  final String ministryName;
  final String memberId;
  final String memberName;
  final String? notes;
  final DateTime createdAt;
  final String? createdBy;

  MinistrySchedule({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.ministryId,
    required this.ministryName,
    required this.memberId,
    required this.memberName,
    this.notes,
    required this.createdAt,
    this.createdBy,
  });

  factory MinistrySchedule.fromJson(Map<String, dynamic> json) {
    return MinistrySchedule(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String? ?? '',
      ministryId: json['ministry_id'] as String,
      ministryName: json['ministry_name'] as String? ?? '',
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_name': eventName,
      'ministry_id': ministryId,
      'ministry_name': ministryName,
      'member_id': memberId,
      'member_name': memberName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  MinistrySchedule copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? ministryId,
    String? ministryName,
    String? memberId,
    String? memberName,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return MinistrySchedule(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ministryId: ministryId ?? this.ministryId,
      ministryName: ministryName ?? this.ministryName,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

