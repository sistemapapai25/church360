/// Enums e Models para o sistema de visitantes
library;

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

/// Origem do visitante (Tipo de Membro para visitantes)
enum VisitorSource {
  church('church', 'Veio da Igreja (Culto)'),
  house('house', 'Veio da Casa (Grupo)'),
  evangelism('evangelism', 'Evangelismo'),
  event('event', 'Evento Especial'),
  online('online', 'Online (Redes Sociais)'),
  other('other', 'Outro');

  final String value;
  final String label;

  const VisitorSource(this.value, this.label);

  static VisitorSource fromValue(String value) {
    return VisitorSource.values.firstWhere(
      (source) => source.value == value,
      orElse: () => VisitorSource.church,
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
  final DateTime? firstVisitDate;
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

  // Origem do visitante (Tipo de Membro)
  final VisitorSource visitorSource;

  // Vinculação com reunião de grupo
  final String? meetingId;

  // Campos adicionais
  final int? age;
  final String? gender; // M, F
  final String? howFoundUs; // Texto livre
  final bool wantsContact;
  final bool wantsToReturn;

  // Campos de salvação
  final bool isSalvation;
  final DateTime? salvationDate;
  final String? testimony;

  // Campos de batismo
  final bool wantsBaptism;
  final String? baptismEventId;
  final String? baptismCourseId;

  // Campos de discipulado
  final bool wantsDiscipleship;
  final String? discipleshipCourseId;
  final String? assignedMentorId;
  final String? assignedMentorName; // Computed from join

  // Campos de acompanhamento
  final String followUpStatus; // pending, in_progress, completed
  final DateTime? lastContactDate;

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
    this.visitorSource = VisitorSource.church,
    this.meetingId,
    this.age,
    this.gender,
    this.howFoundUs,
    this.wantsContact = true,
    this.wantsToReturn = false,
    this.isSalvation = false,
    this.salvationDate,
    this.testimony,
    this.wantsBaptism = false,
    this.baptismEventId,
    this.baptismCourseId,
    this.wantsDiscipleship = false,
    this.discipleshipCourseId,
    this.assignedMentorId,
    this.assignedMentorName,
    this.followUpStatus = 'pending',
    this.lastContactDate,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  String get fullName => '$firstName $lastName';

  String get displayName => fullName;

  String? get nickname => null; // Visitors don't have nicknames in the current schema

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  String? get photoUrl => null; // Visitors don't have photos in the current schema

  String get followUpStatusLabel {
    switch (followUpStatus) {
      case 'pending': return 'Pendente';
      case 'in_progress': return 'Em Andamento';
      case 'completed': return 'Concluído';
      default: return followUpStatus;
    }
  }

  factory Visitor.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      final text = value.toString();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    String asNonNullString(dynamic value) {
      return value?.toString() ?? '';
    }

    final rawFirstName = json['first_name']?.toString();
    final rawLastName = json['last_name']?.toString();

    var firstName = rawFirstName ?? '';
    var lastName = rawLastName ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      final fullName = json['name']?.toString() ?? '';
      final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        firstName = parts.first;
        lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }

    String? assignedMentorName;
    final mentor = json['mentor'];
    if (mentor is Map<String, dynamic>) {
      final mentorFirstName = mentor['first_name']?.toString();
      final mentorLastName = mentor['last_name']?.toString();
      assignedMentorName = [mentorFirstName, mentorLastName].where((p) => (p ?? '').trim().isNotEmpty).join(' ').trim();
      if (assignedMentorName.isEmpty) assignedMentorName = null;
    }

    return Visitor(
      id: asNonNullString(json['id']),
      firstName: firstName,
      lastName: lastName,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthDate: parseDate(json['birthdate'] ?? json['birth_date']),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      firstVisitDate: parseDate(json['first_visit_date']),
      lastVisitDate: parseDate(json['last_visit_date']),
      totalVisits: json['total_visits'] as int? ?? 1,
      status: VisitorStatus.fromValue(json['status'] as String? ?? 'first_visit'),
      howFound: json['how_found'] != null
          ? HowFoundChurch.fromValue(json['how_found'] as String)
          : null,
      prayerRequest: json['prayer_request'] as String?,
      interests: json['interests'] as String?,
      notes: json['notes'] as String?,
      convertedToMemberId: (json['converted_to_user_id'] ?? json['converted_to_member_id']) as String?,
      convertedAt: parseDate(json['converted_at']),
      assignedTo: json['assigned_to'] as String?,
      visitorSource: json['visitor_source'] != null
          ? VisitorSource.fromValue(json['visitor_source'] as String)
          : VisitorSource.church,
      meetingId: json['meeting_id'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      howFoundUs: json['how_found_us'] as String?,
      wantsContact: json['wants_contact'] as bool? ?? true,
      wantsToReturn: json['wants_to_return'] as bool? ?? false,
      isSalvation: json['is_salvation'] as bool? ?? false,
      salvationDate: parseDate(json['salvation_date']),
      testimony: json['testimony'] as String?,
      wantsBaptism: json['wants_baptism'] as bool? ?? false,
      baptismEventId: json['baptism_event_id'] as String?,
      baptismCourseId: json['baptism_course_id'] as String?,
      wantsDiscipleship: json['wants_discipleship'] as bool? ?? false,
      discipleshipCourseId: json['discipleship_course_id'] as String?,
      assignedMentorId: json['assigned_mentor_id'] as String?,
      assignedMentorName: assignedMentorName ?? json['assigned_mentor_name'] as String?,
      followUpStatus: json['follow_up_status'] as String? ?? 'pending',
      lastContactDate: parseDate(json['last_contact_date']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? parseDate(json['created_at']) ?? DateTime.now(),
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
      'first_visit_date': firstVisitDate?.toIso8601String().split('T')[0],
      'last_visit_date': lastVisitDate?.toIso8601String().split('T')[0],
      'total_visits': totalVisits,
      'status': status.value,
      'how_found': howFound?.value,
      'prayer_request': prayerRequest,
      'interests': interests,
      'notes': notes,
      'converted_to_user_id': convertedToMemberId,
      'converted_at': convertedAt?.toIso8601String(),
      'assigned_to': assignedTo,
      'visitor_source': visitorSource.value,
      'meeting_id': meetingId,
      'age': age,
      'gender': gender,
      'how_found_us': howFoundUs,
      'wants_contact': wantsContact,
      'wants_to_return': wantsToReturn,
      'is_salvation': isSalvation,
      'salvation_date': salvationDate?.toIso8601String().split('T')[0],
      'testimony': testimony,
      'wants_baptism': wantsBaptism,
      'baptism_event_id': baptismEventId,
      'baptism_course_id': baptismCourseId,
      'wants_discipleship': wantsDiscipleship,
      'discipleship_course_id': discipleshipCourseId,
      'assigned_mentor_id': assignedMentorId,
      'follow_up_status': followUpStatus,
      'last_contact_date': lastContactDate?.toIso8601String().split('T')[0],
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
