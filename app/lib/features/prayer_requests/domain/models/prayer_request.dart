/// Enums e Models para Pedidos de Oração

/// Categoria do pedido de oração
enum PrayerCategory {
  personal('personal', 'Pessoal', '👤'),
  family('family', 'Família', '👨‍👩‍👧‍👦'),
  health('health', 'Saúde', '🏥'),
  work('work', 'Trabalho', '💼'),
  ministry('ministry', 'Ministério', '⛪'),
  church('church', 'Igreja', '🙏'),
  other('other', 'Outro', '📝');

  final String value;
  final String displayName;
  final String icon;

  const PrayerCategory(this.value, this.displayName, this.icon);

  static PrayerCategory fromString(String value) {
    return PrayerCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrayerCategory.other,
    );
  }
}

/// Status do pedido de oração
enum PrayerStatus {
  pending('pending', 'Pendente', '⏳'),
  praying('praying', 'Em Oração', '🙏'),
  answered('answered', 'Respondido', '✅'),
  cancelled('cancelled', 'Cancelado', '❌');

  final String value;
  final String displayName;
  final String icon;

  const PrayerStatus(this.value, this.displayName, this.icon);

  static PrayerStatus fromString(String value) {
    return PrayerStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrayerStatus.pending,
    );
  }
}

/// Privacidade do pedido de oração
enum PrayerPrivacy {
  public('public', 'Público', 'Todos podem ver'),
  membersOnly('members_only', 'Apenas Membros', 'Apenas membros da igreja'),
  leadersOnly('leaders_only', 'Apenas Líderes', 'Apenas líderes e coordenadores'),
  private('private', 'Privado', 'Apenas você');

  final String value;
  final String displayName;
  final String description;

  const PrayerPrivacy(this.value, this.displayName, this.description);

  static PrayerPrivacy fromString(String value) {
    return PrayerPrivacy.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrayerPrivacy.public,
    );
  }
}

/// Model: Pedido de Oração
class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final PrayerCategory category;
  final PrayerStatus status;
  final PrayerPrivacy privacy;
  final String authorId;
  final DateTime? answeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.privacy,
    required this.authorId,
    this.answeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper: Está respondido?
  bool get isAnswered => status == PrayerStatus.answered;

  // Helper: Está cancelado?
  bool get isCancelled => status == PrayerStatus.cancelled;

  // Helper: Está ativo?
  bool get isActive => status == PrayerStatus.pending || status == PrayerStatus.praying;

  // Helper: Data formatada
  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    return '$day/$month/$year';
  }

  // Helper: Tempo desde criação
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'ano' : 'anos'} atrás';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'mês' : 'meses'} atrás';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'} atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'} atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'} atrás';
    } else {
      return 'Agora';
    }
  }

  // From JSON
  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: PrayerCategory.fromString(json['category'] as String),
      status: PrayerStatus.fromString(json['status'] as String),
      privacy: PrayerPrivacy.fromString(json['privacy'] as String),
      authorId: json['author_id'] as String,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.value,
      'status': status.value,
      'privacy': privacy.value,
      'author_id': authorId,
      'answered_at': answeredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  PrayerRequest copyWith({
    String? id,
    String? title,
    String? description,
    PrayerCategory? category,
    PrayerStatus? status,
    PrayerPrivacy? privacy,
    String? authorId,
    DateTime? answeredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrayerRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      privacy: privacy ?? this.privacy,
      authorId: authorId ?? this.authorId,
      answeredAt: answeredAt ?? this.answeredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model: Oração (alguém marcou "eu orei")
class PrayerRequestPrayer {
  final String id;
  final String prayerRequestId;
  final String userId;
  final DateTime prayedAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrayerRequestPrayer({
    required this.id,
    required this.prayerRequestId,
    required this.userId,
    required this.prayedAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper: Tem nota?
  bool get hasNote => note != null && note!.isNotEmpty;

  // From JSON
  factory PrayerRequestPrayer.fromJson(Map<String, dynamic> json) {
    return PrayerRequestPrayer(
      id: json['id'] as String,
      prayerRequestId: json['prayer_request_id'] as String,
      userId: json['user_id'] as String,
      prayedAt: DateTime.parse(json['prayed_at'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prayer_request_id': prayerRequestId,
      'user_id': userId,
      'prayed_at': prayedAt.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Model: Testemunho de oração respondida
class PrayerRequestTestimony {
  final String id;
  final String prayerRequestId;
  final String testimony;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrayerRequestTestimony({
    required this.id,
    required this.prayerRequestId,
    required this.testimony,
    required this.createdAt,
    required this.updatedAt,
  });

  // From JSON
  factory PrayerRequestTestimony.fromJson(Map<String, dynamic> json) {
    return PrayerRequestTestimony(
      id: json['id'] as String,
      prayerRequestId: json['prayer_request_id'] as String,
      testimony: json['testimony'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prayer_request_id': prayerRequestId,
      'testimony': testimony,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Model: Estatísticas de um pedido
class PrayerRequestStats {
  final int totalPrayers;
  final int uniquePrayers;
  final bool hasTestimony;

  PrayerRequestStats({
    required this.totalPrayers,
    required this.uniquePrayers,
    required this.hasTestimony,
  });

  factory PrayerRequestStats.fromJson(Map<String, dynamic> json) {
    return PrayerRequestStats(
      totalPrayers: json['total_prayers'] as int,
      uniquePrayers: json['unique_prayers'] as int,
      hasTestimony: json['has_testimony'] as bool,
    );
  }
}

