import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';

/// De onde a turma veio. **Único** ponto da tela da turma que olha
/// `baptism_turma_id` (gate 5 do ROADMAP-FORMACAO: nenhum
/// `if origin == baptism` espalhado pela árvore).
///
/// A origem diz *que turma é esta* — e, a partir da 5.2, entrega as
/// superfícies que variam (Alunos, Presença, Minha frequência). *Quem eu sou
/// nesta turma* é outra pergunta, respondida por `turmaAccessProvider`.
sealed class TurmaOrigin {
  final String studyGroupId;

  const TurmaOrigin(this.studyGroupId);

  factory TurmaOrigin.of(CourseTurma turma) {
    final baptismTurmaId = turma.baptismTurmaId;
    final ministryId = turma.ministryId;
    if (baptismTurmaId != null && ministryId != null) {
      return BatismoTurmaOrigin(
        studyGroupId: turma.id,
        ministryId: ministryId,
        baptismTurmaId: baptismTurmaId,
      );
    }
    return GenericaTurmaOrigin(studyGroupId: turma.id);
  }
}

/// Grupo espelho de uma `baptism_turma`. Alunos em `baptism_student`
/// (chave `user_account.id`), presença em `baptism_meeting`/`_attendance`.
final class BatismoTurmaOrigin extends TurmaOrigin {
  final String ministryId;
  final String baptismTurmaId;

  const BatismoTurmaOrigin({
    required String studyGroupId,
    required this.ministryId,
    required this.baptismTurmaId,
  }) : super(studyGroupId);
}

/// Turma genérica de Formação. Participantes em `study_participants` e
/// presença em `study_attendance` (as duas com chave `auth.uid()`).
final class GenericaTurmaOrigin extends TurmaOrigin {
  const GenericaTurmaOrigin({required String studyGroupId})
      : super(studyGroupId);
}

/// Origem da turma; `null` quando a RLS esconde o grupo.
final turmaOriginProvider =
    FutureProvider.family<TurmaOrigin?, String>((ref, studyGroupId) async {
  final turma = await ref.watch(turmaByIdProvider(studyGroupId).future);
  return turma == null ? null : TurmaOrigin.of(turma);
});
