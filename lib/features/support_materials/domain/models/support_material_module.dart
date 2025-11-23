/// Modelo de Módulo/Capítulo de Material de Apoio
class SupportMaterialModule {
  final String id;
  final String materialId;
  final String title;
  final String? description;
  final int orderIndex;
  
  // Conteúdo
  final String? content;
  
  // Arquivo específico do módulo
  final String? fileUrl;
  final String? fileName;
  
  // Vídeo específico do módulo
  final String? videoUrl;
  final int? videoDuration; // em segundos

  // Capa do módulo
  final String? coverImageUrl;

  // Metadata
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  SupportMaterialModule({
    required this.id,
    required this.materialId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.content,
    this.fileUrl,
    this.fileName,
    this.videoUrl,
    this.videoDuration,
    this.coverImageUrl,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  /// Criar a partir de JSON
  factory SupportMaterialModule.fromJson(Map<String, dynamic> json) {
    return SupportMaterialModule(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      content: json['content'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      videoUrl: json['video_url'] as String?,
      videoDuration: json['video_duration'] as int?,
      coverImageUrl: json['cover_image_url'] as String?,
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
      'material_id': materialId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'content': content,
      'file_url': fileUrl,
      'file_name': fileName,
      'video_url': videoUrl,
      'video_duration': videoDuration,
      'cover_image_url': coverImageUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
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
  SupportMaterialModule copyWith({
    String? id,
    String? materialId,
    String? title,
    String? description,
    int? orderIndex,
    String? content,
    String? fileUrl,
    String? fileName,
    String? videoUrl,
    int? videoDuration,
    String? coverImageUrl,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SupportMaterialModule(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      videoUrl: videoUrl ?? this.videoUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

