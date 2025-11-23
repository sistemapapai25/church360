/// Modelo de Aula de Curso
class CourseLesson {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int orderIndex;
  final String? content; // Transcrição/descrição da aula
  final String? videoUrl;
  final int? videoDuration; // Duração em segundos
  final String? fileUrl;
  final String? fileName;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  CourseLesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.content,
    this.videoUrl,
    this.videoDuration,
    this.fileUrl,
    this.fileName,
    this.coverImageUrl,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  /// Criar a partir de JSON
  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    return CourseLesson(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderIndex: json['order_index'] as int,
      content: json['content'] as String?,
      videoUrl: json['video_url'] as String?,
      videoDuration: json['video_duration'] as int?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'content': content,
      'video_url': videoUrl,
      'video_duration': videoDuration,
      'file_url': fileUrl,
      'file_name': fileName,
      'cover_image_url': coverImageUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// Copiar com alterações
  CourseLesson copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? orderIndex,
    String? content,
    String? videoUrl,
    int? videoDuration,
    String? fileUrl,
    String? fileName,
    String? coverImageUrl,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CourseLesson(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      content: content ?? this.content,
      videoUrl: videoUrl ?? this.videoUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Propriedades computadas
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get hasCover => coverImageUrl != null && coverImageUrl!.isNotEmpty;
  bool get hasContent => content != null && content!.isNotEmpty;

  String get durationText {
    if (videoDuration == null) return '';
    final minutes = videoDuration! ~/ 60;
    final seconds = videoDuration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CourseLesson &&
        other.id == id &&
        other.courseId == courseId &&
        other.title == title &&
        other.description == description &&
        other.orderIndex == orderIndex &&
        other.content == content &&
        other.videoUrl == videoUrl &&
        other.videoDuration == videoDuration &&
        other.fileUrl == fileUrl &&
        other.fileName == fileName &&
        other.coverImageUrl == coverImageUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      courseId,
      title,
      description,
      orderIndex,
      content,
      videoUrl,
      videoDuration,
      fileUrl,
      fileName,
      coverImageUrl,
    );
  }
}

