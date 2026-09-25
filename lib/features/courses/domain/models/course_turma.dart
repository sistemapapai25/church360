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

  const CourseTurma({
    required this.id,
    required this.name,
    required this.status,
    this.startDate,
    this.endDate,
    this.ministryId,
    this.baptismTurmaId,
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
    );
  }

  /// Grupo espelho de uma `baptism_turma` (ver migration
  /// 20260925000100_study_group_baptism_turma_vinculo).
  bool get isBaptismTurma => baptismTurmaId != null && ministryId != null;

  /// Destino do card.
  ///
  /// Turma de Batismo abre o workspace do ministério, que é onde a turma é
  /// gerida de verdade (alunos, presença, checklist) e cujo acesso é
  /// decidido pelo vínculo com o ministério. Não existe rota de uma turma
  /// só; o grupo espelho em /study-groups/:id exige `study_groups.view` e
  /// mostraria só a sombra da turma. Grupo nativo segue para o detalhe do
  /// grupo de estudo.
  String get route =>
      isBaptismTurma ? '/ministries/$ministryId/batismo' : '/study-groups/$id';

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
