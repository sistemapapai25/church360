/// Enums e Models para o sistema de visitantes

/// Status do visitante
enum VisitorStatus {
  firstVisit('first_visit', 'Primeira Visita'),
  returning('returning', 'Retornando'),
  regular('regular', 'Frequentando'),
  converted('converted', 'Convertido'),
  inactive('inactive', 'Inativo');

  final String value;
  final String label;

  const VisitorStatus(this.value, this.label);

  static VisitorStatus fromValue(String value) {
    return VisitorStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => VisitorStatus.firstVisit,
    );
  }
}

/// Como conheceu a igreja
enum HowFoundChurch {
  friendInvitation('friend_invitation', 'Convite de Amigo'),
  family('family', 'Família'),
  socialMedia('social_media', 'Redes Sociais'),
  googleSearch('google_search', 'Busca no Google'),
  passingBy('passing_by', 'Passando pela Rua'),
  event('event', 'Evento Especial'),
  other('other', 'Outro');

  final String value;
  final String label;

  const HowFoundChurch(this.value, this.label);

  static HowFoundChurch fromValue(String value) {
    return HowFoundChurch.values.firstWhere(
      (how) => how.value == value,
      orElse: () => HowFoundChurch.other,
    );
  }
}

/// Model de Visitante
class Visitor {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;

  // Informações da visita
  final DateTime firstVisitDate;
  final DateTime? lastVisitDate;
  final int totalVisits;
  final VisitorStatus status;
  final HowFoundChurch? howFound;

  // Informações adicionais
  final String? prayerRequest;
  final String? interests;
  final String? notes;

  // Conversão
  final String? convertedToMemberId;
  final DateTime? convertedAt;

  // Responsável
  final String? assignedTo;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  Visitor({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.birthDate,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    required this.firstVisitDate,
    this.lastVisitDate,
    required this.totalVisits,
    required this.status,
    this.howFound,
    this.prayerRequest,
    this.interests,
    this.notes,
    this.convertedToMemberId,
    this.convertedAt,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  String get fullName => '$firstName $lastName';

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      firstVisitDate: DateTime.parse(json['first_visit_date'] as String),
      lastVisitDate: json['last_visit_date'] != null
          ? DateTime.parse(json['last_visit_date'] as String)
          : null,
      totalVisits: json['total_visits'] as int? ?? 1,
      status: VisitorStatus.fromValue(json['status'] as String? ?? 'first_visit'),
      howFound: json['how_found'] != null
          ? HowFoundChurch.fromValue(json['how_found'] as String)
          : null,
      prayerRequest: json['prayer_request'] as String?,
      interests: json['interests'] as String?,
      notes: json['notes'] as String?,
      convertedToMemberId: json['converted_to_member_id'] as String?,
      convertedAt: json['converted_at'] != null
          ? DateTime.parse(json['converted_at'] as String)
          : null,
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'first_visit_date': firstVisitDate.toIso8601String().split('T')[0],
      'last_visit_date': lastVisitDate?.toIso8601String().split('T')[0],
      'total_visits': totalVisits,
      'status': status.value,
      'how_found': howFound?.value,
      'prayer_request': prayerRequest,
      'interests': interests,
      'notes': notes,
      'converted_to_member_id': convertedToMemberId,
      'converted_at': convertedAt?.toIso8601String(),
      'assigned_to': assignedTo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

/// Model de Visita
class VisitorVisit {
  final String id;
  final String visitorId;
  final DateTime visitDate;
  final String? worshipServiceId;
  final String? notes;
  final bool wasContacted;
  final DateTime? contactDate;
  final String? contactNotes;
  final DateTime createdAt;
  final String? createdBy;

  VisitorVisit({
    required this.id,
    required this.visitorId,
    required this.visitDate,
    this.worshipServiceId,
    this.notes,
    required this.wasContacted,
    this.contactDate,
    this.contactNotes,
    required this.createdAt,
    this.createdBy,
  });

  factory VisitorVisit.fromJson(Map<String, dynamic> json) {
    return VisitorVisit(
      id: json['id'] as String,
      visitorId: json['visitor_id'] as String,
      visitDate: DateTime.parse(json['visit_date'] as String),
      worshipServiceId: json['worship_service_id'] as String?,
      notes: json['notes'] as String?,
      wasContacted: json['was_contacted'] as bool? ?? false,
      contactDate: json['contact_date'] != null
          ? DateTime.parse(json['contact_date'] as String)
          : null,
      contactNotes: json['contact_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitorId,
      'visit_date': visitDate.toIso8601String().split('T')[0],
      'worship_service_id': worshipServiceId,
      'notes': notes,
      'was_contacted': wasContacted,
      'contact_date': contactDate?.toIso8601String().split('T')[0],
      'contact_notes': contactNotes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

/// Model de Follow-up
class VisitorFollowup {
  final String id;
  final String visitorId;
  final DateTime followupDate;
  final String? followupType;
  final String? description;
  final bool completed;
  final DateTime? completedAt;
  final String? completedBy;
  final String? assignedTo;
  final DateTime createdAt;
  final String? createdBy;

  VisitorFollowup({
    required this.id,
    required this.visitorId,
    required this.followupDate,
    this.followupType,
    this.description,
    required this.completed,
    this.completedAt,
    this.completedBy,
    this.assignedTo,
    required this.createdAt,
    this.createdBy,
  });

  factory VisitorFollowup.fromJson(Map<String, dynamic> json) {
    return VisitorFollowup(
      id: json['id'] as String,
      visitorId: json['visitor_id'] as String,
      followupDate: DateTime.parse(json['followup_date'] as String),
      followupType: json['followup_type'] as String?,
      description: json['description'] as String?,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedBy: json['completed_by'] as String?,
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitorId,
      'followup_date': followupDate.toIso8601String().split('T')[0],
      'followup_type': followupType,
      'description': description,
      'completed': completed,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'assigned_to': assignedTo,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

