// =====================================================
// CHURCH 360 - ACCESS LEVEL MODELS
// =====================================================

/// Enum de tipos de nível de acesso
enum AccessLevelType {
  visitor,      // 0: Visitante
  attendee,     // 1: Frequentador
  member,       // 2: Membro
  leader,       // 3: Líder
  coordinator,  // 4: Coordenador
  admin;        // 5: Administrativo

  /// Converter para número
  int toNumber() {
    switch (this) {
      case AccessLevelType.visitor:
        return 0;
      case AccessLevelType.attendee:
        return 1;
      case AccessLevelType.member:
        return 2;
      case AccessLevelType.leader:
        return 3;
      case AccessLevelType.coordinator:
        return 4;
      case AccessLevelType.admin:
        return 5;
    }
  }

  /// Converter de número
  static AccessLevelType fromNumber(int number) {
    switch (number) {
      case 0:
        return AccessLevelType.visitor;
      case 1:
        return AccessLevelType.attendee;
      case 2:
        return AccessLevelType.member;
      case 3:
        return AccessLevelType.leader;
      case 4:
        return AccessLevelType.coordinator;
      case 5:
        return AccessLevelType.admin;
      default:
        return AccessLevelType.visitor;
    }
  }

  /// Converter de string
  static AccessLevelType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'visitor':
        return AccessLevelType.visitor;
      case 'attendee':
        return AccessLevelType.attendee;
      case 'member':
        return AccessLevelType.member;
      case 'leader':
        return AccessLevelType.leader;
      case 'coordinator':
        return AccessLevelType.coordinator;
      case 'admin':
        return AccessLevelType.admin;
      default:
        return AccessLevelType.visitor;
    }
  }

  /// Nome em português
  String get displayName {
    switch (this) {
      case AccessLevelType.visitor:
        return 'Visitante';
      case AccessLevelType.attendee:
        return 'Membro';
      case AccessLevelType.member:
        return 'Voluntário';
      case AccessLevelType.leader:
        return 'Líder';
      case AccessLevelType.coordinator:
        return 'Coordenador';
      case AccessLevelType.admin:
        return 'Administrativo';
    }
  }

  /// Descrição do nível
  String get description {
    switch (this) {
      case AccessLevelType.visitor:
        return 'Acesso público; participa de grupos/estudos; sem Dashboard';
      case AccessLevelType.attendee:
        return 'Membro - Participa de grupos/estudos; sem Dashboard';
      case AccessLevelType.member:
        return 'Voluntário - Escalas e áreas com restrições; com Dashboard';
      case AccessLevelType.leader:
        return 'Líder - Tudo do voluntário, com mais responsabilidades';
      case AccessLevelType.coordinator:
        return 'Coordenador - Responsável pelo ministério; líder de líderes';
      case AccessLevelType.admin:
        return 'Administrativo/Owner - Acesso amplo; controlado por permissões';
    }
  }

  /// Ícone do nível
  String get icon {
    switch (this) {
      case AccessLevelType.visitor:
        return '👤';
      case AccessLevelType.attendee:
        return '🧑‍🤝‍🧑';
      case AccessLevelType.member:
        return '🤝';
      case AccessLevelType.leader:
        return '👨‍🏫';
      case AccessLevelType.coordinator:
        return '🎖️';
      case AccessLevelType.admin:
        return '👑';
    }
  }
}

/// Model de nível de acesso do usuário
class UserAccessLevel {
  final String id;
  final String userId;
  final AccessLevelType accessLevel;
  final int accessLevelNumber;
  final DateTime? promotedAt;
  final String? promotedBy;
  final String? promotionReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAccessLevel({
    required this.id,
    required this.userId,
    required this.accessLevel,
    required this.accessLevelNumber,
    this.promotedAt,
    this.promotedBy,
    this.promotionReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar de JSON
  factory UserAccessLevel.fromJson(Map<String, dynamic> json) {
    return UserAccessLevel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accessLevel: AccessLevelType.fromString(json['access_level'] as String),
      accessLevelNumber: json['access_level_number'] as int,
      promotedAt: json['promoted_at'] != null
          ? DateTime.parse(json['promoted_at'] as String)
          : null,
      promotedBy: json['promoted_by'] as String?,
      promotionReason: json['promotion_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'access_level': accessLevel.name,
      'access_level_number': accessLevelNumber,
      'promoted_at': promotedAt?.toIso8601String(),
      'promoted_by': promotedBy,
      'promotion_reason': promotionReason,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copiar com modificações
  UserAccessLevel copyWith({
    String? id,
    String? userId,
    AccessLevelType? accessLevel,
    int? accessLevelNumber,
    DateTime? promotedAt,
    String? promotedBy,
    String? promotionReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccessLevel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accessLevel: accessLevel ?? this.accessLevel,
      accessLevelNumber: accessLevelNumber ?? this.accessLevelNumber,
      promotedAt: promotedAt ?? this.promotedAt,
      promotedBy: promotedBy ?? this.promotedBy,
      promotionReason: promotionReason ?? this.promotionReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se tem permissão (nível >= requerido)
  bool hasPermission(AccessLevelType requiredLevel) {
    return accessLevelNumber >= requiredLevel.toNumber();
  }

  /// Verificar se é admin
  bool get isAdmin => accessLevel == AccessLevelType.admin;

  /// Verificar se é coordenador ou superior
  bool get isCoordinatorOrAbove => accessLevelNumber >= 4;

  /// Verificar se é líder ou superior
  bool get isLeaderOrAbove => accessLevelNumber >= 3;

  /// Verificar se é membro ou superior
  bool get isMemberOrAbove => accessLevelNumber >= 2;
}

/// Model de histórico de mudanças de nível
class AccessLevelHistory {
  final String id;
  final String userId;
  final AccessLevelType? fromLevel;
  final int? fromLevelNumber;
  final AccessLevelType toLevel;
  final int toLevelNumber;
  final String? reason;
  final String? promotedBy;
  final DateTime createdAt;

  AccessLevelHistory({
    required this.id,
    required this.userId,
    this.fromLevel,
    this.fromLevelNumber,
    required this.toLevel,
    required this.toLevelNumber,
    this.reason,
    this.promotedBy,
    required this.createdAt,
  });

  /// Criar de JSON
  factory AccessLevelHistory.fromJson(Map<String, dynamic> json) {
    return AccessLevelHistory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fromLevel: json['from_level'] != null
          ? AccessLevelType.fromString(json['from_level'] as String)
          : null,
      fromLevelNumber: json['from_level_number'] as int?,
      toLevel: AccessLevelType.fromString(json['to_level'] as String),
      toLevelNumber: json['to_level_number'] as int,
      reason: json['reason'] as String?,
      promotedBy: json['promoted_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_level': fromLevel?.name,
      'from_level_number': fromLevelNumber,
      'to_level': toLevel.name,
      'to_level_number': toLevelNumber,
      'reason': reason,
      'promoted_by': promotedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Verificar se foi promoção (subiu de nível)
  bool get isPromotion =>
      fromLevelNumber != null && toLevelNumber > fromLevelNumber!;

  /// Verificar se foi rebaixamento (desceu de nível)
  bool get isDemotion =>
      fromLevelNumber != null && toLevelNumber < fromLevelNumber!;

  /// Descrição da mudança
  String get changeDescription {
    if (fromLevel == null) {
      return 'Criação inicial como ${toLevel.displayName}';
    } else if (isPromotion) {
      return 'Promovido de ${fromLevel!.displayName} para ${toLevel.displayName}';
    } else if (isDemotion) {
      return 'Rebaixado de ${fromLevel!.displayName} para ${toLevel.displayName}';
    } else {
      return 'Nível mantido como ${toLevel.displayName}';
    }
  }
}
