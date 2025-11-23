/// Enum para tipo de curso
enum CourseType {
  presencial('presencial', 'Presencial'),
  onlineLive('online_live', 'Online ao Vivo'),
  onlineRecorded('online_recorded', 'Online Gravado');

  final String value;
  final String label;

  const CourseType(this.value, this.label);

  static CourseType fromString(String value) {
    switch (value) {
      case 'presencial':
        return CourseType.presencial;
      case 'online_live':
        return CourseType.onlineLive;
      case 'online_recorded':
        return CourseType.onlineRecorded;
      default:
        return CourseType.presencial;
    }
  }
}

/// Modelo de Curso
class Course {
  final String id;
  final String title;
  final String? description;
  final String? instructor;
  final String? imageUrl;
  final int? duration; // Duração em horas
  final String level; // 'Básico', 'Intermediário', 'Avançado'
  final String status; // 'active', 'upcoming', 'completed'
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxStudents;
  final int? enrolledCount; // Número de alunos inscritos
  final String? category; // Categoria do curso (ex: Teologia, Música, Liderança)
  final CourseType courseType; // Tipo de curso
  final String? meetingLink; // Link da sala (para cursos online ao vivo)
  final String? eventId; // Evento vinculado (para cursos presenciais)
  final String? address; // Endereço (para cursos presenciais)
  final bool isPaid; // Se o curso é pago
  final double? price; // Preço do curso (se for pago)
  final String? paymentInfo; // Informações de pagamento (PIX, conta, etc.)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Course({
    required this.id,
    required this.title,
    this.description,
    this.instructor,
    this.imageUrl,
    this.duration,
    this.level = 'Básico',
    this.status = 'active',
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.enrolledCount,
    this.category,
    this.courseType = CourseType.presencial,
    this.meetingLink,
    this.eventId,
    this.address,
    this.isPaid = false,
    this.price,
    this.paymentInfo,
    required this.createdAt,
    this.updatedAt,
  });

  /// Criar a partir de JSON
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      instructor: json['instructor'] as String?,
      imageUrl: json['image_url'] as String?,
      duration: json['duration'] as int?,
      level: json['level'] as String? ?? 'Básico',
      status: json['status'] as String? ?? 'active',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      maxStudents: json['max_students'] as int?,
      enrolledCount: json['enrolled_count'] as int?,
      category: json['category'] as String?,
      courseType: json['course_type'] != null
          ? CourseType.fromString(json['course_type'] as String)
          : CourseType.presencial,
      meetingLink: json['meeting_link'] as String?,
      eventId: json['event_id'] as String?,
      address: json['address'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      paymentInfo: json['payment_info'] as String?,
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
      'instructor': instructor,
      'image_url': imageUrl,
      'duration': duration,
      'level': level,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'max_students': maxStudents,
      'category': category,
      'course_type': courseType.value,
      'meeting_link': meetingLink,
      'event_id': eventId,
      'address': address,
      'is_paid': isPaid,
      'price': price,
      'payment_info': paymentInfo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Propriedades computadas
  bool get isActive {
    return status == 'active';
  }

  bool get isUpcoming {
    if (startDate == null) return false;
    return startDate!.isAfter(DateTime.now()) && status == 'upcoming';
  }

  bool get isCompleted {
    return status == 'completed';
  }

  bool get isFull {
    if (maxStudents == null || enrolledCount == null) {
      return false;
    }
    return enrolledCount! >= maxStudents!;
  }

  bool get hasVacancies {
    if (maxStudents == null) return true;
    if (enrolledCount == null) return true;
    return enrolledCount! < maxStudents!;
  }

  int get availableVacancies {
    if (maxStudents == null) return 999;
    if (enrolledCount == null) return maxStudents!;
    return maxStudents! - enrolledCount!;
  }

  String get statusText {
    switch (status) {
      case 'active':
        return 'Ativo';
      case 'upcoming':
        return 'Em breve';
      case 'completed':
        return 'Concluído';
      default:
        return 'Desconhecido';
    }
  }

  String get levelText {
    return level;
  }
}

/// Modelo de Inscrição em Curso
class CourseEnrollment {
  final String courseId;
  final String memberId;
  final String? memberName; // Computed from join
  final DateTime enrolledAt;
  final String status; // 'active', 'completed', 'dropped'
  final double? progress; // Progresso em porcentagem (0-100)

  CourseEnrollment({
    required this.courseId,
    required this.memberId,
    this.memberName,
    required this.enrolledAt,
    this.status = 'active',
    this.progress,
  });

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) {
    return CourseEnrollment(
      courseId: json['course_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      status: json['status'] as String? ?? 'active',
      progress: json['progress'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'member_id': memberId,
      'enrolled_at': enrolledAt.toIso8601String(),
      'status': status,
      'progress': progress,
    };
  }
}

