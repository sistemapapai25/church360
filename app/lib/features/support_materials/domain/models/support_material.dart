/// Enum para tipo de material
enum SupportMaterialType {
  pdf('pdf', 'PDF'),
  powerpoint('powerpoint', 'PowerPoint'),
  video('video', 'Vídeo'),
  text('text', 'Texto'),
  audio('audio', 'Áudio'),
  link('link', 'Link'),
  other('other', 'Outro');

  final String value;
  final String label;

  const SupportMaterialType(this.value, this.label);

  static SupportMaterialType fromString(String value) {
    return SupportMaterialType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SupportMaterialType.other,
    );
  }
}

/// Modelo de Material de Apoio
class SupportMaterial {
  final String id;
  final String title;
  final String? description;
  final String? author;
  final SupportMaterialType materialType;
  
  // Arquivo
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  
  // Vídeo
  final String? videoUrl;
  final int? videoDuration; // em segundos
  
  // Texto transcrito
  final String? content;
  final String? transcription; // Alias para content (compatibilidade)

  // Link externo
  final String? externalLink;

  // Capa do material
  final String? coverImageUrl;

  // Organização
  final String? category;
  final List<String> tags;
  
  // Status
  final bool isActive;
  final bool isPublic;
  
  // Metadata
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  SupportMaterial({
    required this.id,
    required this.title,
    this.description,
    this.author,
    required this.materialType,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.videoUrl,
    this.videoDuration,
    this.content,
    this.transcription,
    this.externalLink,
    this.coverImageUrl,
    this.category,
    this.tags = const [],
    this.isActive = true,
    this.isPublic = false,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  /// Criar a partir de JSON
  factory SupportMaterial.fromJson(Map<String, dynamic> json) {
    return SupportMaterial(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      author: json['author'] as String?,
      materialType: SupportMaterialType.fromString(json['material_type'] as String),
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      videoUrl: json['video_url'] as String?,
      videoDuration: json['video_duration'] as int?,
      content: json['content'] as String?,
      transcription: json['transcription'] as String?,
      externalLink: json['external_link'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      category: json['category'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
      isActive: json['is_active'] as bool? ?? true,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'author': author,
      'material_type': materialType.value,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'video_url': videoUrl,
      'video_duration': videoDuration,
      'content': content,
      'transcription': transcription,
      'external_link': externalLink,
      'cover_image_url': coverImageUrl,
      'category': category,
      'tags': tags,
      'is_active': isActive,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// Helper para formatar tamanho do arquivo
  String get formattedFileSize {
    if (fileSize == null) return '';
    
    final kb = fileSize! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// Helper para formatar duração do vídeo
  String get formattedVideoDuration {
    if (videoDuration == null) return '';
    
    final hours = videoDuration! ~/ 3600;
    final minutes = (videoDuration! % 3600) ~/ 60;
    final seconds = videoDuration! % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Copiar com alterações
  SupportMaterial copyWith({
    String? id,
    String? title,
    String? description,
    String? author,
    SupportMaterialType? materialType,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? videoUrl,
    int? videoDuration,
    String? content,
    String? transcription,
    String? externalLink,
    String? coverImageUrl,
    String? category,
    List<String>? tags,
    bool? isActive,
    bool? isPublic,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SupportMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      materialType: materialType ?? this.materialType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      videoUrl: videoUrl ?? this.videoUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      content: content ?? this.content,
      transcription: transcription ?? this.transcription,
      externalLink: externalLink ?? this.externalLink,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

