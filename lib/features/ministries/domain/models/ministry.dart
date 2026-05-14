/// Tipo de ministério usado para roteamento de submódulos especializados.
///
/// O valor `generic` é o default no banco para todo registro novo. Tipos
/// reconhecidos pelo app habilitam telas específicas (ex.: Raízes, Diaconato).
enum MinistryType {
  generic('generic'),
  raizes('raizes'),
  diaconato('diaconato'),
  kids('kids'),
  louvor('louvor'),
  midia('midia');

  final String value;
  const MinistryType(this.value);

  static MinistryType fromValue(String? value) {
    if (value == null) return MinistryType.generic;
    return MinistryType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => MinistryType.generic,
    );
  }
}

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

  // Categorização e configuração (Lote 2 do roadmap Ministérios)
  final String? slug;
  final MinistryType ministryType;
  final Map<String, dynamic> settings;

  // Dados do líder (quando incluído na query)
  final String? leaderName;
  final String? leaderPhoto;

  // Contagem de membros (quando incluído na query)
  final int? memberCount;
  final String? whatsappGroupNumber;

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
    this.slug,
    this.ministryType = MinistryType.generic,
    this.settings = const {},
    this.leaderName,
    this.leaderPhoto,
    this.memberCount,
    this.whatsappGroupNumber,
  });

  /// Rota do submódulo específico deste ministério, quando aplicável.
  /// Retorna `null` para tipos genéricos.
  String? specializedRoute() {
    switch (ministryType) {
      case MinistryType.raizes:
        return '/ministries/$id/raizes';
      case MinistryType.diaconato:
        return '/ministries/$id/diaconato';
      case MinistryType.generic:
      case MinistryType.kids:
      case MinistryType.louvor:
      case MinistryType.midia:
        return null;
    }
  }

  factory Ministry.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    final settings = rawSettings is Map<String, dynamic>
        ? rawSettings
        : (rawSettings is Map
            ? Map<String, dynamic>.from(rawSettings)
            : const <String, dynamic>{});

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
      slug: json['slug'] as String?,
      ministryType: MinistryType.fromValue(json['ministry_type'] as String?),
      settings: settings,
      leaderName: json['leader_name'] as String?,
      leaderPhoto: json['leader_photo'] as String?,
      memberCount: json['member_count'] as int?,
      whatsappGroupNumber: json['whatsapp_group_number'] as String?,
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
      'slug': slug,
      'ministry_type': ministryType.value,
      'settings': settings,
      'whatsapp_group_number': whatsappGroupNumber,
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
    String? slug,
    MinistryType? ministryType,
    Map<String, dynamic>? settings,
    String? leaderName,
    String? leaderPhoto,
    int? memberCount,
    String? whatsappGroupNumber,
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
      slug: slug ?? this.slug,
      ministryType: ministryType ?? this.ministryType,
      settings: settings ?? this.settings,
      leaderName: leaderName ?? this.leaderName,
      leaderPhoto: leaderPhoto ?? this.leaderPhoto,
      memberCount: memberCount ?? this.memberCount,
      whatsappGroupNumber: whatsappGroupNumber ?? this.whatsappGroupNumber,
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
  final String? cargoName;

  MinistryMember({
    required this.id,
    required this.ministryId,
    required this.memberId,
    required this.memberName,
    required this.role,
    required this.joinedAt,
    this.notes,
    required this.createdAt,
    this.cargoName,
  });

  factory MinistryMember.fromJson(Map<String, dynamic> json) {
    return MinistryMember(
      id: json['id'] as String,
      ministryId: json['ministry_id'] as String,
      memberId: json['user_id'] as String,
      memberName: json['member_name'] as String? ?? '',
      role: MinistryRole.fromString(json['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse((json['joined_at'] ?? json['created_at']) as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      cargoName: json['cargo_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ministry_id': ministryId,
      'user_id': memberId,
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
    String? cargoName,
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
      cargoName: cargoName ?? this.cargoName,
    );
  }
}

/// Modelo de Escala de Ministério
class MinistrySchedule {
  final String id;
  final String eventId;
  final String eventName;
  final DateTime? eventStartDate;
  final String ministryId;
  final String ministryName;
  final String memberId;
  final String memberName;
  final String? functionId;
  final String? functionName;
  final String? notes;
  final DateTime createdAt;
  final String? createdBy;

  MinistrySchedule({
    required this.id,
    required this.eventId,
    required this.eventName,
    this.eventStartDate,
    required this.ministryId,
    required this.ministryName,
    required this.memberId,
    required this.memberName,
    this.functionId,
    this.functionName,
    this.notes,
    required this.createdAt,
    this.createdBy,
  });

  factory MinistrySchedule.fromJson(Map<String, dynamic> json) {
    return MinistrySchedule(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String? ?? '',
      eventStartDate: json['event_start_date'] != null ? DateTime.parse(json['event_start_date'] as String) : null,
      ministryId: json['ministry_id'] as String,
      ministryName: json['ministry_name'] as String? ?? '',
      memberId: json['user_id'] as String,
      memberName: json['member_name'] as String? ?? '',
      functionId: json['function_id'] as String?,
      functionName: json['function_name'] as String?,
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
      'event_start_date': eventStartDate?.toIso8601String(),
      'ministry_id': ministryId,
      'ministry_name': ministryName,
      'user_id': memberId,
      'member_name': memberName,
      'function_id': functionId,
      'function_name': functionName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  MinistrySchedule copyWith({
    String? id,
    String? eventId,
    String? eventName,
    DateTime? eventStartDate,
    String? ministryId,
    String? ministryName,
    String? memberId,
    String? memberName,
    String? functionId,
    String? functionName,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return MinistrySchedule(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      ministryId: ministryId ?? this.ministryId,
      ministryName: ministryName ?? this.ministryName,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      functionId: functionId ?? this.functionId,
      functionName: functionName ?? this.functionName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
