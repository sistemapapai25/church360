/// Modelo de configuracao do culto ao vivo
class LiveStreamConfig {
  final String id;
  final String? streamUrl;
  final String? message;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const LiveStreamConfig({
    required this.id,
    this.streamUrl,
    this.message,
    this.isActive = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory LiveStreamConfig.fromJson(Map<String, dynamic> json) {
    return LiveStreamConfig(
      id: json['id'] as String,
      streamUrl: json['stream_url'] as String?,
      message: json['message'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stream_url': streamUrl,
      'message': message,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  LiveStreamConfig copyWith({
    String? id,
    String? streamUrl,
    String? message,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return LiveStreamConfig(
      id: id ?? this.id,
      streamUrl: streamUrl ?? this.streamUrl,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveStreamConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LiveStreamConfig(id: $id, isActive: $isActive)';
  }
}
