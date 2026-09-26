import '../../../study_groups/domain/models/study_group.dart';

/// Turma (linha de `study_groups`) vista de dentro de um curso.
///
/// Não reaproveita `StudyGroup` de propósito: aquele modelo exige
/// `is_public`, `created_at` e `updated_at` e não conhece `ministry_id` nem
/// `baptism_turma_id`. Aqui só entra o que o card da tela do curso mostra
/// e o que decide para onde ele leva — nada de participantes.
class CourseTurma {
  final String id;
  final String name;
  final StudyGroupStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? ministryId;
  final String? baptismTurmaId;

  /// Curso dono da turma. Nulo só em grupo antigo, de antes de
  /// `study_groups.course_id` (a coluna ainda é nullable até a Etapa 8).
  final String? courseId;

  const CourseTurma({
    required this.id,
    required this.name,
    required this.status,
    this.startDate,
    this.endDate,
    this.ministryId,
    this.baptismTurmaId,
    this.courseId,
  });

  factory CourseTurma.fromJson(Map<String, dynamic> json) {
    return CourseTurma(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Turma sem nome',
      // Status nulo ou fora do enum cai em `active` (mesmo fallback de
      // StudyGroupStatus.fromString) em vez de derrubar a lista inteira.
      status: StudyGroupStatus.fromString(json['status'] as String? ?? ''),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      ministryId: json['ministry_id'] as String?,
      baptismTurmaId: json['baptism_turma_id'] as String?,
      courseId: json['course_id'] as String?,
    );
  }

  /// Grupo espelho de uma `baptism_turma` (ver migration
  /// 20260925000100_study_group_baptism_turma_vinculo).
  bool get isBaptismTurma => baptismTurmaId != null && ministryId != null;

  /// Destino do card.
  ///
  /// A turma tem uma tela só, dentro de Cursos (decisão 23 do
  /// ROADMAP-FORMACAO): `/courses/:courseId/turmas/:studyGroupId`. Batismo e
  /// grupo nativo abrem a mesma tela; o que muda lá dentro vem da origem.
  ///
  /// Nenhum card leva mais para `/ministries/...` (gate 6). Sem `course_id`
  /// (grupo antigo, até a Etapa 8) não há rota canônica: cai no detalhe
  /// antigo do grupo, que redireciona se a turma ganhar curso depois.
  String get route => routeWithin(null);

  /// Igual a [route], mas usa [fallbackCourseId] quando a linha não trouxe
  /// `course_id` — a seção Turmas de um curso sabe de que curso é.
  String routeWithin(String? fallbackCourseId) {
    final course = courseId ?? fallbackCourseId;
    if (course != null) return '/courses/$course/turmas/$id';
    return '/study-groups/$id';
  }

  /// "06/09/2026 a 25/10/2026", "Início: …", "Término: …" ou nulo.
  String? get periodLabel {
    final start = startDate;
    final end = endDate;
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${_formatDate(start)} a ${_formatDate(end)}';
    }
    if (start != null) return 'Início: ${_formatDate(start)}';
    return 'Término: ${_formatDate(end!)}';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
