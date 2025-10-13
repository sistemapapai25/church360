/// Modelo de Evento
class Event {
  final String id;
  final String name;
  final String? description;
  final String? eventType;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final int? maxCapacity;
  final bool requiresRegistration;
  final String status; // 'draft', 'published', 'cancelled', 'completed'
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Campos computados do join
  final int? registrationCount;

  Event({
    required this.id,
    required this.name,
    this.description,
    this.eventType,
    required this.startDate,
    this.endDate,
    this.location,
    this.maxCapacity,
    this.requiresRegistration = false,
    this.status = 'draft',
    required this.createdAt,
    this.updatedAt,
    this.registrationCount,
  });

  /// Criar a partir de JSON
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      eventType: json['event_type'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      location: json['location'] as String?,
      maxCapacity: json['max_capacity'] as int?,
      requiresRegistration: json['requires_registration'] as bool? ?? false,
      status: json['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      registrationCount: json['registration_count'] as int?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'event_type': eventType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'location': location,
      'max_capacity': maxCapacity,
      'requires_registration': requiresRegistration,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Propriedades computadas
  bool get isPast {
    if (endDate != null) {
      return endDate!.isBefore(DateTime.now());
    }
    return startDate.isBefore(DateTime.now());
  }

  bool get isUpcoming {
    return startDate.isAfter(DateTime.now());
  }

  bool get isOngoing {
    final now = DateTime.now();
    if (endDate != null) {
      return startDate.isBefore(now) && endDate!.isAfter(now);
    }
    return false;
  }

  bool get isFull {
    if (maxCapacity == null || registrationCount == null) {
      return false;
    }
    return registrationCount! >= maxCapacity!;
  }

  bool get isActive {
    return status != 'cancelled';
  }

  String get statusText {
    if (status == 'cancelled') return 'Cancelado';
    if (status == 'completed') return 'Finalizado';
    if (isPast) return 'Finalizado';
    if (isOngoing) return 'Em andamento';
    if (isUpcoming) return 'Próximo';
    return 'Rascunho';
  }
}

/// Modelo de Inscrição em Evento
class EventRegistration {
  final String eventId;
  final String memberId;
  final String? memberName; // Computed from join
  final DateTime registeredAt;
  final DateTime? checkedInAt;

  EventRegistration({
    required this.eventId,
    required this.memberId,
    this.memberName,
    required this.registeredAt,
    this.checkedInAt,
  });

  bool get isCheckedIn => checkedInAt != null;

  /// Criar a partir de JSON
  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      eventId: json['event_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'member_id': memberId,
      'registered_at': registeredAt.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
    };
  }
}

