/// Modelo de Member
/// Representa um membro da igreja
class Member {
  final String id;
  final String? householdId;
  final String? campusId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final DateTime? birthdate;
  final String? gender;
  final String? maritalStatus;
  final String status;
  final DateTime? membershipDate;
  final DateTime? conversionDate;
  final DateTime? baptismDate;
  final String? photoUrl;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Member({
    required this.id,
    this.householdId,
    this.campusId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.birthdate,
    this.gender,
    this.maritalStatus,
    required this.status,
    this.membershipDate,
    this.conversionDate,
    this.baptismDate,
    this.photoUrl,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Nome completo
  String get fullName => '$firstName $lastName';

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
      id: json['id'] as String,
      householdId: json['household_id'] as String?,
      campusId: json['campus_id'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'] as String)
          : null,
      gender: json['gender'] as String?,
      maritalStatus: json['marital_status'] as String?,
      status: json['status'] as String,
      membershipDate: json['membership_date'] != null
          ? DateTime.parse(json['membership_date'] as String)
          : null,
      conversionDate: json['conversion_date'] != null
          ? DateTime.parse(json['conversion_date'] as String)
          : null,
      baptismDate: json['baptism_date'] != null
          ? DateTime.parse(json['baptism_date'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      notes: json['notes'] as String?,
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
      'household_id': householdId,
      'campus_id': campusId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'birthdate': birthdate?.toIso8601String(),
      'gender': gender,
      'marital_status': maritalStatus,
      'status': status,
      'membership_date': membershipDate?.toIso8601String(),
      'conversion_date': conversionDate?.toIso8601String(),
      'baptism_date': baptismDate?.toIso8601String(),
      'photo_url': photoUrl,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
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
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? birthdate,
    String? gender,
    String? maritalStatus,
    String? status,
    DateTime? membershipDate,
    DateTime? conversionDate,
    DateTime? baptismDate,
    String? photoUrl,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      campusId: campusId ?? this.campusId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      status: status ?? this.status,
      membershipDate: membershipDate ?? this.membershipDate,
      conversionDate: conversionDate ?? this.conversionDate,
      baptismDate: baptismDate ?? this.baptismDate,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se é membro ativo
  bool get isActive => status == 'member_active';

  /// Verificar se é visitante
  bool get isVisitor => status == 'visitor';

  /// Verificar se é novo convertido
  bool get isNewConvert => status == 'new_convert';

  /// Verificar se é membro inativo
  bool get isInactive => status == 'member_inactive';

  /// Verificar se foi transferido
  bool get isTransferred => status == 'transferred';
}

