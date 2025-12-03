/// Modelo de Plano de Leitura
class ReadingPlan {
  final String id;
  final String title;
  final String? description;
  final int durationDays; // Duração em dias
  final String? imageUrl;
  final String status; // 'active', 'inactive'
  final String? category; // 'complete_bible', 'new_testament', 'old_testament', 'devotional'
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReadingPlan({
    required this.id,
    required this.title,
    this.description,
    required this.durationDays,
    this.imageUrl,
    this.status = 'active',
    this.category,
    required this.createdAt,
    this.updatedAt,
  });

  /// Criar a partir de JSON
  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      durationDays: json['duration_days'] as int,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'active',
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'duration_days': durationDays,
      'image_url': imageUrl,
      'status': status,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Propriedades computadas
  bool get isActive => status == 'active';

  String get durationText {
    if (durationDays == 1) return '1 dia';
    if (durationDays < 30) return '$durationDays dias';
    if (durationDays == 30) return '1 mês';
    if (durationDays < 365) {
      final months = (durationDays / 30).round();
      return '$months ${months == 1 ? 'mês' : 'meses'}';
    }
    final years = (durationDays / 365).round();
    return '$years ${years == 1 ? 'ano' : 'anos'}';
  }

  String get categoryText {
    switch (category) {
      case 'complete_bible':
        return 'Bíblia Completa';
      case 'new_testament':
        return 'Novo Testamento';
      case 'old_testament':
        return 'Antigo Testamento';
      case 'devotional':
        return 'Devocional';
      default:
        return 'Geral';
    }
  }
}

/// Modelo de Progresso do Usuário em um Plano de Leitura
class ReadingPlanProgress {
  final String planId;
  final String memberId;
  final DateTime startedAt;
  final int currentDay;
  final DateTime? completedAt;
  final DateTime? lastReadAt;

  ReadingPlanProgress({
    required this.planId,
    required this.memberId,
    required this.startedAt,
    this.currentDay = 1,
    this.completedAt,
    this.lastReadAt,
  });

  bool get isCompleted => completedAt != null;

  /// Criar a partir de JSON
  factory ReadingPlanProgress.fromJson(Map<String, dynamic> json) {
    return ReadingPlanProgress(
      planId: json['plan_id'] as String,
      memberId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      currentDay: json['current_day'] as int? ?? 1,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'user_id': memberId,
      'started_at': startedAt.toIso8601String(),
      'current_day': currentDay,
      'completed_at': completedAt?.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }
}
