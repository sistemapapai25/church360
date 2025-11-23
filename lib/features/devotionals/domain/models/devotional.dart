/// Modelo de domínio para Devocional
class Devotional {
  final String id;
  final String title;
  final String content;
  final String? scriptureReference;
  final DateTime devotionalDate;
  final String authorId;
  final bool isPublished;
  final String? imageUrl;
  final String? category; // Domingo, Quarta, Especial
  final String? preacher; // Pregador
  final String? youtubeUrl; // Link do YouTube
  final DateTime createdAt;
  final DateTime updatedAt;

  const Devotional({
    required this.id,
    required this.title,
    required this.content,
    this.scriptureReference,
    required this.devotionalDate,
    required this.authorId,
    required this.isPublished,
    this.imageUrl,
    this.category,
    this.preacher,
    this.youtubeUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar Devotional a partir de JSON
  factory Devotional.fromJson(Map<String, dynamic> json) {
    return Devotional(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      scriptureReference: json['scripture_reference'] as String?,
      devotionalDate: DateTime.parse(json['devotional_date'] as String),
      authorId: json['author_id'] as String,
      isPublished: json['is_published'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      preacher: json['preacher'] as String?,
      youtubeUrl: json['youtube_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converter Devotional para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'scripture_reference': scriptureReference,
      'devotional_date': devotionalDate.toIso8601String().split('T')[0], // Apenas data
      'author_id': authorId,
      'is_published': isPublished,
      'image_url': imageUrl,
      'category': category,
      'preacher': preacher,
      'youtube_url': youtubeUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Criar cópia com alterações
  Devotional copyWith({
    String? id,
    String? title,
    String? content,
    String? scriptureReference,
    DateTime? devotionalDate,
    String? authorId,
    bool? isPublished,
    String? imageUrl,
    String? category,
    String? preacher,
    String? youtubeUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Devotional(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      scriptureReference: scriptureReference ?? this.scriptureReference,
      devotionalDate: devotionalDate ?? this.devotionalDate,
      authorId: authorId ?? this.authorId,
      isPublished: isPublished ?? this.isPublished,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      preacher: preacher ?? this.preacher,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se é devocional de hoje
  bool get isToday {
    final now = DateTime.now();
    return devotionalDate.year == now.year &&
        devotionalDate.month == now.month &&
        devotionalDate.day == now.day;
  }

  /// Verificar se é devocional futuro
  bool get isFuture {
    final now = DateTime.now();
    return devotionalDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// Verificar se é devocional passado
  bool get isPast {
    final now = DateTime.now();
    return devotionalDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Formatar data para exibição
  String get formattedDate {
    final months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${devotionalDate.day} de ${months[devotionalDate.month - 1]} de ${devotionalDate.year}';
  }

  /// Verificar se tem vídeo do YouTube
  bool get hasYoutubeVideo => youtubeUrl != null && youtubeUrl!.isNotEmpty;

  /// Texto da categoria
  String get categoryText {
    switch (category?.toLowerCase()) {
      case 'domingo':
        return 'Culto de Domingo';
      case 'quarta':
      case 'quarta-feira':
        return 'Culto de Quarta-feira';
      case 'especial':
        return 'Culto Especial';
      default:
        return category ?? 'Devocional';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Devotional &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Devotional(id: $id, title: $title, date: $devotionalDate, published: $isPublished)';
  }
}

/// Modelo de domínio para Leitura de Devocional
class DevotionalReading {
  final String id;
  final String devotionalId;
  final String userId;
  final DateTime readAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DevotionalReading({
    required this.id,
    required this.devotionalId,
    required this.userId,
    required this.readAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar DevotionalReading a partir de JSON
  factory DevotionalReading.fromJson(Map<String, dynamic> json) {
    return DevotionalReading(
      id: json['id'] as String,
      devotionalId: json['devotional_id'] as String,
      userId: json['user_id'] as String,
      readAt: DateTime.parse(json['read_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converter DevotionalReading para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'devotional_id': devotionalId,
      'user_id': userId,
      'read_at': readAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Criar cópia com alterações
  DevotionalReading copyWith({
    String? id,
    String? devotionalId,
    String? userId,
    DateTime? readAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DevotionalReading(
      id: id ?? this.id,
      devotionalId: devotionalId ?? this.devotionalId,
      userId: userId ?? this.userId,
      readAt: readAt ?? this.readAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se tem anotações
  bool get hasNotes => notes != null && notes!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevotionalReading &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DevotionalReading(id: $id, devotionalId: $devotionalId, userId: $userId, readAt: $readAt)';
  }
}

/// Modelo para estatísticas de devocional
class DevotionalStats {
  final int totalReads;
  final int uniqueReaders;

  const DevotionalStats({
    required this.totalReads,
    required this.uniqueReaders,
  });

  factory DevotionalStats.fromJson(Map<String, dynamic> json) {
    return DevotionalStats(
      totalReads: json['total_reads'] as int? ?? 0,
      uniqueReaders: json['unique_readers'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_reads': totalReads,
      'unique_readers': uniqueReaders,
    };
  }

  @override
  String toString() {
    return 'DevotionalStats(totalReads: $totalReads, uniqueReaders: $uniqueReaders)';
  }
}

/// Modelo para streak de leituras do usuário
class UserReadingStreak {
  final int currentStreak;
  final int longestStreak;
  final int totalReadings;

  const UserReadingStreak({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalReadings,
  });

  factory UserReadingStreak.fromJson(Map<String, dynamic> json) {
    return UserReadingStreak(
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalReadings: json['total_readings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_readings': totalReadings,
    };
  }

  @override
  String toString() {
    return 'UserReadingStreak(current: $currentStreak, longest: $longestStreak, total: $totalReadings)';
  }
}

