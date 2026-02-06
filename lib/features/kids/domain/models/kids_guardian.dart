enum KidsGuardianRelationship {
  father,
  mother,
  uncle,
  aunt,
  grandfather,
  grandmother,
  sibling,
  other
}

/// Representa um guardião autorizado (Tio, Avó, etc)
class KidsAuthorizedGuardian {
  final String id;
  final String childId;
  final String guardianId;
  final String? guardianName; // Computed/Joined
  final String? guardianPhoto; // Computed/Joined
  final String relationship;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool isTemporary;
  final DateTime? validUntil;
  final DateTime createdAt;

  KidsAuthorizedGuardian({
    required this.id,
    required this.childId,
    required this.guardianId,
    this.guardianName,
    this.guardianPhoto,
    required this.relationship,
    this.canCheckIn = true,
    this.canCheckOut = true,
    this.isTemporary = false,
    this.validUntil,
    required this.createdAt,
  });

  factory KidsAuthorizedGuardian.fromJson(Map<String, dynamic> json) {
    return KidsAuthorizedGuardian(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      guardianId: json['guardian_id'] as String,
      guardianName: json['guardian_name'] as String?,
      guardianPhoto: json['guardian_photo'] as String?,
      relationship: json['relationship'] as String,
      canCheckIn: json['can_checkin'] as bool? ?? true,
      canCheckOut: json['can_checkout'] as bool? ?? true,
      isTemporary: json['is_temporary'] as bool? ?? false,
      validUntil: json['valid_until'] != null ? DateTime.parse(json['valid_until']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'guardian_id': guardianId,
      'relationship': relationship,
      'can_checkin': canCheckIn,
      'can_checkout': canCheckOut,
      'is_temporary': isTemporary,
      'valid_until': validUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
