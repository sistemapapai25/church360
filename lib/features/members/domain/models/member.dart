/// Modelo de Member (agora baseado em user_account unificado)
/// Representa um usuário do sistema (visitante, membro, líder, etc.)
class Member {
  // Campos de autenticação (user_account)
  final String id;
  final String email;
  final String? fullName; // Mantido para compatibilidade com auth
  final String? avatarUrl;
  final bool isActive;
  final bool showBirthday;
  final bool showContact;

  // Dados pessoais (member)
  final String? firstName;
  final String? lastName;
  final String? nickname;
  final String? phone;
  final String? cpf;
  final DateTime? birthdate;
  final String? gender;
  final String? maritalStatus;
  final DateTime? marriageDate;
  final String? profession;

  // Endereço (member)
  final String? address;
  final String? addressComplement;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zipCode;

  // Status e tipo (member)
  final String status;
  final String? memberType;
  final String? photoUrl;
  final String? fichaPdf;

  // Relacionamentos (member)
  final String? householdId;
  final String? campusId;
  final String? createdBy;

  // Datas espirituais (member)
  final DateTime? conversionDate;
  final DateTime? baptismDate;
  final DateTime? membershipDate;
  final DateTime? credentialDate;

  // Jornada do visitante (visitor)
  final DateTime? firstVisitDate;
  final DateTime? lastVisitDate;
  final int? totalVisits;
  final String? howFound;
  final String? visitorSource;

  // Acompanhamento espiritual (visitor)
  final String? prayerRequest;
  final String? interests;
  final bool? isSalvation;
  final DateTime? salvationDate;
  final String? testimony;

  // Discipulado e batismo (visitor)
  final bool? wantsBaptism;
  final String? baptismEventId;
  final String? baptismCourseId;
  final bool? wantsDiscipleship;
  final String? discipleshipCourseId;

  // Mentoria e acompanhamento (visitor)
  final String? assignedMentorId;
  final String? followUpStatus;
  final DateTime? lastContactDate;
  final bool? wantsContact;
  final bool? wantsToReturn;

  // Outros
  final bool? entrevista;
  final bool? entrevistador;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Member({
    // Autenticação
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.isActive = true,
    this.showBirthday = false,
    this.showContact = false,

    // Dados pessoais
    this.firstName,
    this.lastName,
    this.nickname,
    this.phone,
    this.cpf,
    this.birthdate,
    this.gender,
    this.maritalStatus,
    this.marriageDate,
    this.profession,

    // Endereço
    this.address,
    this.addressComplement,
    this.neighborhood,
    this.city,
    this.state,
    this.zipCode,

    // Status e tipo
    this.status = 'visitor',
    this.memberType,
    this.photoUrl,
    this.fichaPdf,

    // Relacionamentos
    this.householdId,
    this.campusId,
    this.createdBy,

    // Datas espirituais
    this.conversionDate,
    this.baptismDate,
    this.membershipDate,
    this.credentialDate,

    // Jornada do visitante
    this.firstVisitDate,
    this.lastVisitDate,
    this.totalVisits,
    this.howFound,
    this.visitorSource,

    // Acompanhamento espiritual
    this.prayerRequest,
    this.interests,
    this.isSalvation,
    this.salvationDate,
    this.testimony,

    // Discipulado e batismo
    this.wantsBaptism,
    this.baptismEventId,
    this.baptismCourseId,
    this.wantsDiscipleship,
    this.discipleshipCourseId,

    // Mentoria e acompanhamento
    this.assignedMentorId,
    this.followUpStatus,
    this.lastContactDate,
    this.wantsContact,
    this.wantsToReturn,

    // Outros
    this.entrevista,
    this.entrevistador,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Nome completo computado
  String get computedFullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  /// Nome para exibição (sempre retorna um valor)
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (computedFullName.isNotEmpty) return computedFullName;
    if (email.isNotEmpty) return email;
    return id;
  }

  /// Iniciais para avatar
  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName![0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return id[0].toUpperCase();
  }

  /// Idade (se tiver data de nascimento)
  int? get age {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  /// Criar a partir do JSON do Supabase
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      // Autenticação
      id: json['id'] as String,
      email: json['email'] is String ? json['email'] as String : '',
      fullName: json['full_name'] is String ? json['full_name'] as String : null,
      avatarUrl: json['avatar_url'] is String ? json['avatar_url'] as String : null,
      isActive: json['is_active'] as bool? ?? true,
      showBirthday: json['show_birthday'] as bool? ?? false,
      showContact: json['show_contact'] as bool? ?? false,

      // Dados pessoais
      firstName: json['first_name'] is String ? json['first_name'] as String : null,
      lastName: json['last_name'] is String ? json['last_name'] as String : null,
      nickname: json['nickname'] is String
          ? json['nickname'] as String
          : (json['apelido'] is String ? json['apelido'] as String : null),
      phone: json['phone'] is String ? json['phone'] as String : null,
      cpf: json['cpf'] is String ? json['cpf'] as String : null,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'] as String)
          : null,
      gender: json['gender'] is String ? json['gender'] as String : null,
      maritalStatus: json['marital_status'] is String ? json['marital_status'] as String : null,
      marriageDate: json['marriage_date'] != null
          ? DateTime.parse(json['marriage_date'] as String)
          : null,
      profession: json['profession'] is String ? json['profession'] as String : null,

      // Endereço
      address: json['address'] is String ? json['address'] as String : null,
      addressComplement: json['address_complement'] is String ? json['address_complement'] as String : null,
      neighborhood: json['neighborhood'] is String ? json['neighborhood'] as String : null,
      city: json['city'] is String ? json['city'] as String : null,
      state: json['state'] is String ? json['state'] as String : null,
      zipCode: json['zip_code'] is String ? json['zip_code'] as String : null,

      // Status e tipo
      status: (() {
        final s = json['status'];
        if (s is bool) return s ? 'member_active' : 'member_inactive';
        if (s is String) {
          final t = s.trim().toLowerCase();
          switch (t) {
            case 'visitor':
            case 'visitante':
              return 'visitor';
            case 'new_convert':
            case 'novo_convertido':
            case 'novo-convertido':
            case 'novo convertido':
              return 'new_convert';
            case 'member_active':
            case 'active':
            case 'ativo':
            case 'membro':
              return 'member_active';
            case 'member_inactive':
            case 'inactive':
            case 'inativo':
              return 'member_inactive';
            case 'transferred':
            case 'transferido':
              return 'transferred';
            case 'deceased':
            case 'falecido':
              return 'deceased';
            default:
              return t.isEmpty ? 'visitor' : t;
          }
        }
        return 'visitor';
      })(),
      memberType: json['member_type'] is String ? json['member_type'] as String : null,
      photoUrl: json['photo_url'] is String ? json['photo_url'] as String : null,
      fichaPdf: json['ficha_pdf'] is String ? json['ficha_pdf'] as String : null,

      // Relacionamentos
      householdId: json['household_id'] is String ? json['household_id'] as String : null,
      campusId: json['campus_id'] is String ? json['campus_id'] as String : null,
      createdBy: json['created_by'] is String ? json['created_by'] as String : null,

      // Datas espirituais
      conversionDate: json['conversion_date'] != null
          ? DateTime.parse(json['conversion_date'] as String)
          : null,
      baptismDate: json['baptism_date'] != null
          ? DateTime.parse(json['baptism_date'] as String)
          : null,
      membershipDate: json['membership_date'] != null
          ? DateTime.parse(json['membership_date'] as String)
          : null,
      credentialDate: json['credencial_date'] != null
          ? DateTime.parse(json['credencial_date'] as String)
          : null,

      // Jornada do visitante
      firstVisitDate: json['first_visit_date'] != null
          ? DateTime.parse(json['first_visit_date'] as String)
          : null,
      lastVisitDate: json['last_visit_date'] != null
          ? DateTime.parse(json['last_visit_date'] as String)
          : null,
      totalVisits: json['total_visits'] as int?,
      howFound: json['how_found'] is String ? json['how_found'] as String : null,
      visitorSource: json['visitor_source'] is String ? json['visitor_source'] as String : null,

      // Acompanhamento espiritual
      prayerRequest: json['prayer_request'] is String ? json['prayer_request'] as String : null,
      interests: json['interests'] is String ? json['interests'] as String : null,
      isSalvation: json['is_salvation'] as bool?,
      salvationDate: json['salvation_date'] != null
          ? DateTime.parse(json['salvation_date'] as String)
          : null,
      testimony: json['testimony'] is String ? json['testimony'] as String : null,

      // Discipulado e batismo
      wantsBaptism: json['wants_baptism'] as bool?,
      baptismEventId: json['baptism_event_id'] is String ? json['baptism_event_id'] as String : null,
      baptismCourseId: json['baptism_course_id'] is String ? json['baptism_course_id'] as String : null,
      wantsDiscipleship: json['wants_discipleship'] as bool?,
      discipleshipCourseId: json['discipleship_course_id'] is String ? json['discipleship_course_id'] as String : null,

      // Mentoria e acompanhamento
      assignedMentorId: json['assigned_mentor_id'] is String ? json['assigned_mentor_id'] as String : null,
      followUpStatus: json['follow_up_status'] is String ? json['follow_up_status'] as String : null,
      lastContactDate: json['last_contact_date'] != null
          ? DateTime.parse(json['last_contact_date'] as String)
          : null,
      wantsContact: json['wants_contact'] as bool?,
      wantsToReturn: json['wants_to_return'] as bool?,

      // Outros
      entrevista: (() {
        final v = json['entrevista'];
        if (v is bool) return v;
        if (v is String) {
          final s = v.trim().toLowerCase();
          if (s == 'sim' || s == 'true' || s == '1') return true;
          if (s == 'nao' || s == 'não' || s == 'false' || s == '0') return false;
        }
        return null;
      })(),
      notes: json['notes'] is String ? json['notes'] as String : null,
      entrevistador: json['entrevistador'] is bool ? json['entrevistador'] as bool : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      // Autenticação
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'show_birthday': showBirthday,
      'show_contact': showContact,

      // Dados pessoais
      'first_name': firstName,
      'last_name': lastName,
      'nickname': nickname,
      'phone': phone,
      'cpf': cpf,
      'birthdate': birthdate?.toIso8601String(),
      'gender': gender,
      'marital_status': maritalStatus,
      'marriage_date': marriageDate?.toIso8601String(),
      'profession': profession,

      // Endereço
      'address': address,
      'address_complement': addressComplement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zip_code': zipCode,

      // Status e tipo
      'status': status,
      'member_type': memberType,
      'photo_url': photoUrl,
      'ficha_pdf': fichaPdf,

      // Relacionamentos
      'household_id': householdId,
      'campus_id': campusId,
      'created_by': createdBy,

      // Datas espirituais
      'conversion_date': conversionDate?.toIso8601String(),
      'baptism_date': baptismDate?.toIso8601String(),
      'membership_date': membershipDate?.toIso8601String(),
      'credencial_date': credentialDate?.toIso8601String(),

      // Jornada do visitante
      'first_visit_date': firstVisitDate?.toIso8601String(),
      'last_visit_date': lastVisitDate?.toIso8601String(),
      'total_visits': totalVisits,
      'how_found': howFound,
      'visitor_source': visitorSource,

      // Acompanhamento espiritual
      'prayer_request': prayerRequest,
      'interests': interests,
      'is_salvation': isSalvation,
      'salvation_date': salvationDate?.toIso8601String(),
      'testimony': testimony,

      // Discipulado e batismo
      'wants_baptism': wantsBaptism,
      'baptism_event_id': baptismEventId,
      'baptism_course_id': baptismCourseId,
      'wants_discipleship': wantsDiscipleship,
      'discipleship_course_id': discipleshipCourseId,

      // Mentoria e acompanhamento
      'assigned_mentor_id': assignedMentorId,
      'follow_up_status': followUpStatus,
      'last_contact_date': lastContactDate?.toIso8601String(),
      'wants_contact': wantsContact,
      'wants_to_return': wantsToReturn,

      // Outros
      'entrevista': entrevista,
      'entrevistador': entrevistador,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copiar com modificações
  Member copyWith({
    String? id,
    String? householdId,
    String? campusId,
    String? fullName,
    String? avatarUrl,
    bool? isActive,
    bool? showBirthday,
    bool? showContact,
    String? firstName,
    String? lastName,
    String? nickname,
    String? email,
    String? phone,
    String? cpf,
    DateTime? birthdate,
    String? gender,
    String? maritalStatus,
    DateTime? marriageDate,
    String? profession,
    String? status,
    String? memberType,
    DateTime? membershipDate,
    DateTime? credentialDate,
    DateTime? conversionDate,
    DateTime? baptismDate,
    String? photoUrl,
    String? fichaPdf,
    String? address,
    String? addressComplement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    bool? entrevista,
    bool? entrevistador,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      campusId: campusId ?? this.campusId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      showBirthday: showBirthday ?? this.showBirthday,
      showContact: showContact ?? this.showContact,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cpf: cpf ?? this.cpf,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      marriageDate: marriageDate ?? this.marriageDate,
      profession: profession ?? this.profession,
      status: status ?? this.status,
      memberType: memberType ?? this.memberType,
      membershipDate: membershipDate ?? this.membershipDate,
      credentialDate: credentialDate ?? this.credentialDate,
      conversionDate: conversionDate ?? this.conversionDate,
      baptismDate: baptismDate ?? this.baptismDate,
      photoUrl: photoUrl ?? this.photoUrl,
      fichaPdf: fichaPdf ?? this.fichaPdf,
      address: address ?? this.address,
      addressComplement: addressComplement ?? this.addressComplement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      entrevista: entrevista ?? this.entrevista,
      entrevistador: entrevistador ?? this.entrevistador,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se é membro ativo (status)
  bool get isMemberActive => status == 'member_active';

  /// Verificar se é visitante
  bool get isVisitor => status == 'visitor';

  /// Verificar se é novo convertido
  bool get isNewConvert => status == 'new_convert';

  /// Verificar se é membro inativo
  bool get isInactive => status == 'member_inactive';

  /// Verificar se foi transferido
  bool get isTransferred => status == 'transferred';
}

class ProfessionOption {
  final String id;
  final String label;

  const ProfessionOption({
    required this.id,
    required this.label,
  });
}
