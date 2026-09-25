/// Matrícula do próprio usuário logado numa turma de batismo, como a RPC
/// `my_baptism_enrollments()` devolve.
///
/// Só colunas não sensíveis: nada de `notes` da liderança. A RPC já filtra
/// `ativo` e `concluido` — desistente não aparece.
class BaptismEnrollment {
  final String studentId;
  final String turmaId;

  /// Grupo espelho da turma (`study_groups.baptism_turma_id`). Nulo só se o
  /// espelho ainda não existe.
  final String? studyGroupId;
  final String? courseId;
  final String status;

  const BaptismEnrollment({
    required this.studentId,
    required this.turmaId,
    this.studyGroupId,
    this.courseId,
    required this.status,
  });

  factory BaptismEnrollment.fromJson(Map<String, dynamic> json) {
    return BaptismEnrollment(
      studentId: json['student_id'] as String,
      turmaId: json['turma_id'] as String,
      studyGroupId: json['study_group_id'] as String?,
      courseId: json['course_id'] as String?,
      status: (json['status'] as String?) ?? 'ativo',
    );
  }
}
