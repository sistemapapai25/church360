import 'package:flutter/widgets.dart';

import '../../../../study_groups/domain/models/study_group.dart';
import '../turma_access.dart';
import '../turma_origin.dart';
import 'batismo_turma_adapter.dart';
import 'generica_turma_adapter.dart';

/// "Registrar presença" dentro de uma aula: abre a chamada daquela aula.
typedef TurmaLessonAttendance =
    Future<void> Function(BuildContext context, StudyLesson lesson);

/// As abas que variam com a origem da turma. As outras (Aulas, Materiais)
/// são as mesmas para qualquer turma e não passam por aqui.
abstract interface class TurmaSurfaces {
  Widget alunos();
  Widget presenca();
  Widget minhaFrequencia();

  /// Ação "Registrar presença" na aula, ou `null` quando a origem não
  /// registra presença pela aula. Só o Batismo tem (Etapa 5.3); a turma
  /// genérica marca presença na aba Presença, por aula, desde a 5.2.
  TurmaLessonAttendance? get lessonAttendance;
}

/// Único `switch` sobre a origem na árvore da tela da turma.
TurmaSurfaces turmaSurfacesFor(TurmaOrigin origin, TurmaAccess access) {
  return switch (origin) {
    BatismoTurmaOrigin() => BatismoTurmaAdapter(origin),
    GenericaTurmaOrigin() => GenericaTurmaAdapter(origin, access),
  };
}
