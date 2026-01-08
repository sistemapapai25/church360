/// Registro de presença de uma criança em um evento/culto
class KidsAttendance {
  final String id;
  final String childId;
  final String? childName; // Computed
  final String? childPhoto; // Computed
  final String worshipServiceId;
  final DateTime checkInTime;
  final String? checkInBy; // Voluntário ID
  final String? checkInByName; // Voluntário Nome
  final String? checkInTokenId;
  
  final DateTime? checkOutTime;
  final String? checkOutBy; // Voluntário ID
  final String? checkOutByName; // Voluntário Nome
  final String? pickedUpBy; // Responsável ID
  final String? pickedUpByName; // Responsável Nome
  final String? checkOutTokenId;
  
  final String? roomName;
  final String? notes;

  KidsAttendance({
    required this.id,
    required this.childId,
    this.childName,
    this.childPhoto,
    required this.worshipServiceId,
    required this.checkInTime,
    this.checkInBy,
    this.checkInByName,
    this.checkInTokenId,
    this.checkOutTime,
    this.checkOutBy,
    this.checkOutByName,
    this.pickedUpBy,
    this.pickedUpByName,
    this.checkOutTokenId,
    this.roomName,
    this.notes,
  });

  bool get isCheckedOut => checkOutTime != null;

  factory KidsAttendance.fromJson(Map<String, dynamic> json) {
    return KidsAttendance(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      childName: json['child_name'] as String?,
      childPhoto: json['child_photo'] as String?,
      worshipServiceId: json['worship_service_id'] as String,
      checkInTime: DateTime.parse(json['checkin_time']),
      checkInBy: json['checkin_by'] as String?,
      checkInByName: json['checkin_by_name'] as String?,
      checkInTokenId: json['checkin_token_id'] as String?,
      checkOutTime: json['checkout_time'] != null ? DateTime.parse(json['checkout_time']) : null,
      checkOutBy: json['checkout_by'] as String?,
      checkOutByName: json['checkout_by_name'] as String?,
      pickedUpBy: json['picked_up_by'] as String?,
      pickedUpByName: json['picked_up_by_name'] as String?,
      checkOutTokenId: json['checkout_token_id'] as String?,
      roomName: json['room_name'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'worship_service_id': worshipServiceId,
      'checkin_time': checkInTime.toIso8601String(),
      'checkin_by': checkInBy,
      'checkin_token_id': checkInTokenId,
      'checkout_time': checkOutTime?.toIso8601String(),
      'checkout_by': checkOutBy,
      'picked_up_by': pickedUpBy,
      'checkout_token_id': checkOutTokenId,
      'room_name': roomName,
      'notes': notes,
    };
  }
}
