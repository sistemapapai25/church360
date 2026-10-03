/// Matéria do curso (`course_subject`, PR 2a): o modelo que as turmas
/// seguem — título, quantas aulas e o professor padrão.
class CourseSubject {
  final String id;
  final String courseId;
  final String title;
  final int lessonCount;

  /// `user_account.id` do professor padrão.
  final String? defaultTeacherId;

  const CourseSubject({
    required this.id,
    required this.courseId,
    required this.title,
    required this.lessonCount,
    this.defaultTeacherId,
  });

  factory CourseSubject.fromJson(Map<String, dynamic> json) {
    return CourseSubject(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      lessonCount: json['lesson_count'] as int,
      defaultTeacherId: json['default_teacher_id'] as String?,
    );
  }
}
