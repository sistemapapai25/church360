/// Progresso de quem está logado num curso gravado (RPC `course_progress`,
/// E1 do roadmap Home/culto/Dashboard, 14/10/2026).
class CourseProgress {
  final String courseId;

  /// Aulas que a RLS me deixa ver no curso.
  final int total;

  /// Dessas, as que marquei como concluídas.
  final int done;

  /// Aula para "Continuar de onde parou": a não concluída tocada por último,
  /// senão a primeira não concluída na ordem. Nulo = tudo concluído.
  final String? resumeLessonId;

  /// Segundos salvos do vídeo da aula a retomar.
  final int resumePositionS;

  const CourseProgress({
    required this.courseId,
    required this.total,
    required this.done,
    this.resumeLessonId,
    this.resumePositionS = 0,
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) => CourseProgress(
    courseId: json['course_id'] as String,
    total: json['total'] as int,
    done: json['done'] as int,
    resumeLessonId: json['resume_lesson_id'] as String?,
    resumePositionS: (json['resume_position_s'] as int?) ?? 0,
  );

  /// 0.0 a 1.0.
  double get fraction => total == 0 ? 0 : done / total;

  int get percent => (fraction * 100).round();

  bool get started => done > 0 || resumePositionS > 0;

  bool get completed => total > 0 && done >= total;
}

/// Uma aula do ponto de vista de quem está logado (`course_lesson_progress`).
class LessonProgress {
  final String lessonId;
  final DateTime? completedAt;
  final int videoPositionS;

  const LessonProgress({
    required this.lessonId,
    this.completedAt,
    this.videoPositionS = 0,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
    lessonId: json['lesson_id'] as String,
    completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'] as String)
        : null,
    videoPositionS: (json['video_position_s'] as int?) ?? 0,
  );

  bool get completed => completedAt != null;
}
