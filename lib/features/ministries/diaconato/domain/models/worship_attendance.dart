// Modelos do checklist de presença do Diaconato (Lote MD.1/MD.2 do roadmap
// "Ministérios — telas próprias"). Reflete as tabelas paralelas
// `worship_attendance_count` e `worship_attendance_person` introduzidas em
// `supabase/migrations/20260515000000_diaconato_attendance_count_and_person.sql`.

/// Tipo da pessoa marcada — snapshotado no momento do checklist para preservar
/// histórico mesmo que o `user_account.status` mude depois.
enum DiaconatoPersonType {
  member('member'),
  visitor('visitor');

  final String value;
  const DiaconatoPersonType(this.value);

  static DiaconatoPersonType fromValue(String value) {
    return DiaconatoPersonType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DiaconatoPersonType.member,
    );
  }
}

/// Triagem da ausência. `none` é o default; valores de ação só fazem sentido
/// quando `present = false`.
enum DiaconatoAbsentAction {
  none('none', 'Sem ação'),
  call('call', 'Ligar'),
  communion('communion', 'Levar ceia'),
  callAndCommunion('call_and_communion', 'Ligar + ceia');

  final String value;
  final String label;

  const DiaconatoAbsentAction(this.value, this.label);

  static DiaconatoAbsentAction fromValue(String value) {
    return DiaconatoAbsentAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DiaconatoAbsentAction.none,
    );
  }
}

/// Contagem oficial de presença num culto, feita por um ministério.
class WorshipAttendanceCount {
  final String id;
  final String tenantId;
  final String worshipServiceId;
  final String ministryId;
  final DateTime serviceDate;
  final int totalMembersPresent;
  final int totalRegisteredVisitorsPresent;
  final int totalUnregisteredVisitors;
  final int totalPeople;
  final String? countedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorshipAttendanceCount({
    required this.id,
    required this.tenantId,
    required this.worshipServiceId,
    required this.ministryId,
    required this.serviceDate,
    required this.totalMembersPresent,
    required this.totalRegisteredVisitorsPresent,
    required this.totalUnregisteredVisitors,
    required this.totalPeople,
    this.countedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorshipAttendanceCount.fromJson(Map<String, dynamic> json) {
    return WorshipAttendanceCount(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      worshipServiceId: json['worship_service_id'] as String,
      ministryId: json['ministry_id'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      totalMembersPresent: (json['total_members_present'] as num?)?.toInt() ?? 0,
      totalRegisteredVisitorsPresent:
          (json['total_registered_visitors_present'] as num?)?.toInt() ?? 0,
      totalUnregisteredVisitors:
          (json['total_unregistered_visitors'] as num?)?.toInt() ?? 0,
      totalPeople: (json['total_people'] as num?)?.toInt() ?? 0,
      countedBy: json['counted_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Marcação individual no checklist do Diaconato. 1 linha por pessoa
/// (`member` ou `visitor`).
class WorshipAttendancePerson {
  final String id;
  final String tenantId;
  final String attendanceCountId;
  final String userId;
  final DiaconatoPersonType personType;
  final bool present;
  final DiaconatoAbsentAction absentAction;
  final String? absenceReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorshipAttendancePerson({
    required this.id,
    required this.tenantId,
    required this.attendanceCountId,
    required this.userId,
    required this.personType,
    required this.present,
    required this.absentAction,
    this.absenceReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorshipAttendancePerson.fromJson(Map<String, dynamic> json) {
    return WorshipAttendancePerson(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      attendanceCountId: json['attendance_count_id'] as String,
      userId: json['user_id'] as String,
      personType: DiaconatoPersonType.fromValue(json['person_type'] as String),
      present: json['present'] as bool? ?? false,
      absentAction: DiaconatoAbsentAction.fromValue(
        (json['absent_action'] as String?) ?? 'none',
      ),
      absenceReason: json['absence_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Triagem de uma pessoa ausente (MD.3): a ação escolhida + o tipo da pessoa
/// (snapshot, mesmo motivo do `WorshipAttendancePerson.personType`).
class AbsenteeTriage {
  final DiaconatoAbsentAction action;
  final DiaconatoPersonType personType;

  const AbsenteeTriage({required this.action, required this.personType});
}

/// Pessoa elegível para aparecer no checklist (membro ativo ou visitante já
/// cadastrado em `user_account`). Derivada de `user_account` no carregamento;
/// não persiste em tabela própria.
class DiaconatoEligiblePerson {
  final String userId;
  final String firstName;
  final String? lastName;
  final String? photoUrl;
  final DiaconatoPersonType personType;

  const DiaconatoEligiblePerson({
    required this.userId,
    required this.firstName,
    this.lastName,
    this.photoUrl,
    required this.personType,
  });

  String get displayName {
    final last = (lastName ?? '').trim();
    if (last.isEmpty) return firstName.trim();
    return '${firstName.trim()} $last'.trim();
  }

  /// Inicial usada para o avatar quando não há foto.
  String get initial {
    final first = firstName.trim();
    if (first.isEmpty) return '?';
    return first.substring(0, 1).toUpperCase();
  }

  factory DiaconatoEligiblePerson.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String?) ?? 'member_active';
    final type = status == 'member_active'
        ? DiaconatoPersonType.member
        : DiaconatoPersonType.visitor;

    return DiaconatoEligiblePerson(
      userId: json['id'] as String,
      firstName: (json['first_name'] as String?)?.trim().isNotEmpty == true
          ? (json['first_name'] as String).trim()
          : 'Sem nome',
      lastName: json['last_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      personType: type,
    );
  }
}
