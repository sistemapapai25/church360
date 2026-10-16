// Modelos do Balcão do Infantil (K3): o que as RPCs `kids_board`,
// `kids_scan`, `kids_checkin`, `kids_search_children` e
// `kids_checkout_options` devolvem.

/// A criança como o Balcão vê: nome, sala, selos e o que falta no cadastro.
class KidsChildCard {
  final String childId;
  final String name;
  final String? avatarUrl;
  final int? age;
  final String? allergies;
  final String? intolerances;
  final String? medications;
  final String? specialNeeds;
  final bool foodAlert;
  final bool imageConsent;

  /// O que falta para o cadastro ficar completo (cartilha §6).
  final List<String> missing;

  /// Check-in aberto no culto de hoje (presente na sala).
  final String? attendanceId;
  final String? roomName;
  final DateTime? checkInTime;

  /// Só no `kids_scan`: o código lido e quem o gerou.
  final String? token;
  final String? generatedBy;

  const KidsChildCard({
    required this.childId,
    required this.name,
    this.avatarUrl,
    this.age,
    this.allergies,
    this.intolerances,
    this.medications,
    this.specialNeeds,
    this.foodAlert = false,
    this.imageConsent = false,
    this.missing = const [],
    this.attendanceId,
    this.roomName,
    this.checkInTime,
    this.token,
    this.generatedBy,
  });

  bool get isPresent => attendanceId != null;

  /// Texto do alerta de saúde (alergias, intolerâncias, remédios, cuidados).
  String get healthAlert => [
    if (allergies?.trim().isNotEmpty ?? false) 'Alergia: $allergies',
    if (intolerances?.trim().isNotEmpty ?? false) 'Intolerância: $intolerances',
    if (medications?.trim().isNotEmpty ?? false) 'Remédios: $medications',
    if (specialNeeds?.trim().isNotEmpty ?? false) 'Cuidados: $specialNeeds',
  ].join('\n');

  factory KidsChildCard.fromJson(Map<String, dynamic> json) {
    return KidsChildCard(
      childId: json['child_id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Criança',
      avatarUrl: json['avatar_url'] as String?,
      age: (json['age'] as num?)?.toInt(),
      allergies: json['allergies'] as String?,
      intolerances: json['intolerances'] as String?,
      medications: json['medications'] as String?,
      specialNeeds: json['special_needs'] as String?,
      foodAlert: json['food_alert'] as bool? ?? false,
      imageConsent: json['image_consent'] as bool? ?? false,
      missing: [for (final m in (json['missing'] as List? ?? const [])) '$m'],
      attendanceId: json['attendance_id'] as String?,
      roomName: json['room_name'] as String?,
      checkInTime: json['checkin_time'] != null
          ? DateTime.parse(json['checkin_time'] as String).toLocal()
          : null,
      token: json['token'] as String?,
      generatedBy: json['generated_by'] as String?,
    );
  }
}

/// Painel do Balcão: o culto de hoje e quem está na sala agora.
class KidsBoard {
  final String? eventId;
  final String? eventName;
  final List<KidsChildCard> present;
  final int checkedOut;

  const KidsBoard({
    this.eventId,
    this.eventName,
    this.present = const [],
    this.checkedOut = 0,
  });

  bool get hasEvent => eventId != null;

  factory KidsBoard.fromJson(Map<String, dynamic> json) {
    final event = json['event'] as Map?;
    return KidsBoard(
      eventId: event?['id'] as String?,
      eventName: event?['name'] as String?,
      present: [
        for (final row in (json['present'] as List? ?? const []))
          KidsChildCard.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      checkedOut: (json['checked_out'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Quem pode retirar a criança (pai/mãe/tutor, responsável autorizado).
class KidsPicker {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? relationship;

  const KidsPicker({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.relationship,
  });

  factory KidsPicker.fromJson(Map<String, dynamic> json) => KidsPicker(
    userId: json['user_id'] as String,
    name: json['full_name'] as String? ?? 'Sem nome',
    avatarUrl: json['avatar_url'] as String?,
    relationship: json['relationship'] as String?,
  );
}

/// Sala do Infantil, configurada pela igreja (nome + faixa etária).
class KidsRoom {
  final String? id;
  final String name;
  final int? minAge;
  final int? maxAge;
  final bool isActive;
  final int sortOrder;

  const KidsRoom({
    this.id,
    required this.name,
    this.minAge,
    this.maxAge,
    this.isActive = true,
    this.sortOrder = 0,
  });

  String get ageLabel {
    if (minAge == null && maxAge == null) return 'Qualquer idade';
    if (minAge == null) return 'Até $maxAge anos';
    if (maxAge == null) return 'A partir de $minAge anos';
    return '$minAge a $maxAge anos';
  }

  factory KidsRoom.fromJson(Map<String, dynamic> json) => KidsRoom(
    id: json['id'] as String?,
    name: json['name'] as String,
    minAge: (json['min_age'] as num?)?.toInt(),
    maxAge: (json['max_age'] as num?)?.toInt(),
    isActive: json['is_active'] as bool? ?? true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}
