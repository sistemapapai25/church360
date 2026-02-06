/// Token temporário de Check-in/Check-out
class KidsCheckInToken {
  final String token;
  final String childId;
  final String? eventId;
  final String? generatedBy;
  final String type; // 'checkin' or 'checkout'
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  KidsCheckInToken({
    required this.token,
    required this.childId,
    this.eventId,
    this.generatedBy,
    this.type = 'checkin',
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
  });

  bool get isValid => usedAt == null && DateTime.now().isBefore(expiresAt);

  factory KidsCheckInToken.fromJson(Map<String, dynamic> json) {
    return KidsCheckInToken(
      token: json['token'] as String,
      childId: json['child_id'] as String,
      eventId: json['event_id'] as String?,
      generatedBy: json['generated_by'] as String?,
      type: json['token_type'] as String? ?? 'checkin',
      expiresAt: DateTime.parse(json['expires_at']),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'child_id': childId,
      'event_id': eventId,
      'generated_by': generatedBy,
      'token_type': type,
      'expires_at': expiresAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
