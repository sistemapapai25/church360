import 'study_group.dart';

/// Uma aula de que eu sou o professor, como a Agenda a vê
/// (RPC `my_teaching_lessons`, PR 2c). Traz o nome da turma porque o
/// professor não lê a turma pela RLS.
class TeachingLesson {
  final String id;
  final String studyGroupId;
  final int lessonNumber;
  final String title;
  final DateTime scheduledDate;

  /// 'HH:mm', ou null sem horário.
  final String? startTime;
  final int? durationMinutes;
  final LessonStatus status;
  final String turmaName;
  final String? courseTitle;
  final String? subjectTitle;

  const TeachingLesson({
    required this.id,
    required this.studyGroupId,
    required this.lessonNumber,
    required this.title,
    required this.scheduledDate,
    this.startTime,
    this.durationMinutes,
    required this.status,
    required this.turmaName,
    this.courseTitle,
    this.subjectTitle,
  });

  factory TeachingLesson.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['scheduled_date'] as String);
    return TeachingLesson(
      id: json['id'] as String,
      studyGroupId: json['study_group_id'] as String,
      lessonNumber: json['lesson_number'] as int,
      title: json['title'] as String,
      scheduledDate: DateTime(date.year, date.month, date.day),
      startTime: json['start_time'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      status: LessonStatus.fromString(json['status'] as String),
      turmaName: json['turma_name'] as String,
      courseTitle: json['course_title'] as String?,
      subjectTitle: json['subject_title'] as String?,
    );
  }

  String? get timeRange => lessonTimeRange(startTime, durationMinutes);

  /// Início na hora de parede rotulada como UTC — o mesmo contrato de
  /// `Event.startDate`, para as duas listas se ordenarem juntas. Sem
  /// horário, meia-noite do dia.
  DateTime get startsAt {
    final parts = (startTime ?? '00:00').split(':');
    return DateTime.utc(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// A regra de Próximos Eventos (`start_date >= agora`): sai da lista na
  /// hora de começar. Sem horário não há hora de começar, então fica até o
  /// fim do dia.
  bool isUpcoming(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (scheduledDate.isAfter(today)) return true;
    if (scheduledDate.isBefore(today)) return false;
    if (startTime == null) return true;
    final wallNow = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    return !startsAt.isBefore(wallNow);
  }
}

/// Um aluno na chamada do professor (RPC `teacher_lesson_roll`). A chave é
/// a da origem da turma: `baptism_student.id` ou `study_participants.user_id`.
typedef TeacherRollEntry = ({
  String studentId,
  String name,
  AttendanceStatus? status,
});
