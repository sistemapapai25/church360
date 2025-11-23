/// Modelo de Visitante de Grupo
class GroupVisitor {
  final String id;
  final String meetingId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int? age;
  final String? gender;
  final String? howFoundUs; // Como conheceu o grupo
  final bool wantsContact;
  final bool wantsToReturn;
  final String? notes;
  final DateTime createdAt;
  final String? createdBy;

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

  GroupVisitor({
    required this.id,
    required this.meetingId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.age,
    this.gender,
    this.howFoundUs,
    this.wantsContact = true,
    this.wantsToReturn = false,
    this.notes,
    required this.createdAt,
    this.createdBy,
    // Salvação
    this.isSalvation = false,
    this.salvationDate,
    this.testimony,
    // Batismo
    this.wantsBaptism = false,
    this.baptismEventId,
    this.baptismCourseId,
    // Discipulado
    this.wantsDiscipleship = false,
    this.discipleshipCourseId,
    this.assignedMentorId,
    this.assignedMentorName,
    // Acompanhamento
    this.followUpStatus = 'pending',
    this.lastContactDate,
  });

  /// Criar a partir de JSON
  factory GroupVisitor.fromJson(Map<String, dynamic> json) {
    // Computed field: mentor name
    String? mentorName;
    if (json['mentor'] != null) {
      final mentor = json['mentor'] as Map<String, dynamic>;
      mentorName = '${mentor['first_name']} ${mentor['last_name']}';
    }

    // Nome completo (visitor table tem first_name e last_name separados)
    String fullName;
    if (json['name'] != null) {
      // Compatibilidade com dados antigos que tinham 'name'
      fullName = json['name'] as String;
    } else {
      // Novo formato com first_name e last_name
      final firstName = json['first_name'] as String? ?? '';
      final lastName = json['last_name'] as String? ?? '';
      fullName = '$firstName $lastName'.trim();
    }

    return GroupVisitor(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      name: fullName,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      howFoundUs: json['how_found_us'] as String?,
      wantsContact: json['wants_contact'] as bool? ?? true,
      wantsToReturn: json['wants_to_return'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      // Salvação
      isSalvation: json['is_salvation'] as bool? ?? false,
      salvationDate: json['salvation_date'] != null
          ? DateTime.parse(json['salvation_date'] as String)
          : null,
      testimony: json['testimony'] as String?,
      // Batismo
      wantsBaptism: json['wants_baptism'] as bool? ?? false,
      baptismEventId: json['baptism_event_id'] as String?,
      baptismCourseId: json['baptism_course_id'] as String?,
      // Discipulado
      wantsDiscipleship: json['wants_discipleship'] as bool? ?? false,
      discipleshipCourseId: json['discipleship_course_id'] as String?,
      assignedMentorId: json['assigned_mentor_id'] as String?,
      assignedMentorName: mentorName,
      // Acompanhamento
      followUpStatus: json['follow_up_status'] as String? ?? 'pending',
      lastContactDate: json['last_contact_date'] != null
          ? DateTime.parse(json['last_contact_date'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'age': age,
      'gender': gender,
      'how_found_us': howFoundUs,
      'wants_contact': wantsContact,
      'wants_to_return': wantsToReturn,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      // Salvação
      'is_salvation': isSalvation,
      'salvation_date': salvationDate?.toIso8601String().split('T')[0],
      'testimony': testimony,
      // Batismo
      'wants_baptism': wantsBaptism,
      'baptism_event_id': baptismEventId,
      'baptism_course_id': baptismCourseId,
      // Discipulado
      'wants_discipleship': wantsDiscipleship,
      'discipleship_course_id': discipleshipCourseId,
      'assigned_mentor_id': assignedMentorId,
      // Acompanhamento
      'follow_up_status': followUpStatus,
      'last_contact_date': lastContactDate?.toIso8601String().split('T')[0],
    };
  }

  /// Helper para obter label do status de acompanhamento
  String get followUpStatusLabel {
    switch (followUpStatus) {
      case 'pending':
        return 'Pendente';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      default:
        return followUpStatus;
    }
  }

  /// Copiar com alterações
  GroupVisitor copyWith({
    String? id,
    String? meetingId,
    String? name,
    String? phone,
    String? email,
    String? address,
    int? age,
    String? gender,
    String? howFoundUs,
    bool? wantsContact,
    bool? wantsToReturn,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    bool? isSalvation,
    DateTime? salvationDate,
    String? testimony,
    bool? wantsBaptism,
    String? baptismEventId,
    String? baptismCourseId,
    bool? wantsDiscipleship,
    String? discipleshipCourseId,
    String? assignedMentorId,
    String? assignedMentorName,
    String? followUpStatus,
    DateTime? lastContactDate,
  }) {
    return GroupVisitor(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      howFoundUs: howFoundUs ?? this.howFoundUs,
      wantsContact: wantsContact ?? this.wantsContact,
      wantsToReturn: wantsToReturn ?? this.wantsToReturn,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isSalvation: isSalvation ?? this.isSalvation,
      salvationDate: salvationDate ?? this.salvationDate,
      testimony: testimony ?? this.testimony,
      wantsBaptism: wantsBaptism ?? this.wantsBaptism,
      baptismEventId: baptismEventId ?? this.baptismEventId,
      baptismCourseId: baptismCourseId ?? this.baptismCourseId,
      wantsDiscipleship: wantsDiscipleship ?? this.wantsDiscipleship,
      discipleshipCourseId: discipleshipCourseId ?? this.discipleshipCourseId,
      assignedMentorId: assignedMentorId ?? this.assignedMentorId,
      assignedMentorName: assignedMentorName ?? this.assignedMentorName,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      lastContactDate: lastContactDate ?? this.lastContactDate,
    );
  }
}

