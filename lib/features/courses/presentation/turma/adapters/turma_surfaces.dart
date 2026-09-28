import 'package:flutter/widgets.dart';

import '../../../../study_groups/domain/models/study_group.dart';
import '../turma_access.dart';
import '../turma_origin.dart';
import 'batismo_turma_adapter.dart';
import 'generica_turma_adapter.dart';

/// "Registrar presença" dentro de uma aula: abre a chamada daquela aula.
typedef TurmaLessonAttendance =
    Future<void> Function(BuildContext context, StudyLesson lesson);

/// Onde esta turma se edita, para o botão que a vitrine de Cursos oferece
/// à liderança: o rótulo e a rota.
typedef TurmaManageTarget = ({String label, String route});

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

  /// Para onde a liderança vai quando quer editar a turma que abriu pela
  /// vitrine de Cursos. Cada origem sabe a sua porta — a tela só mostra o
  /// botão. `null` quando não há porta.
  TurmaManageTarget? get manage;
}

/// Único `switch` sobre a origem na árvore da tela da turma.
TurmaSurfaces turmaSurfacesFor(TurmaOrigin origin, TurmaAccess access) {
  return switch (origin) {
    BatismoTurmaOrigin() => BatismoTurmaAdapter(origin, access),
    GenericaTurmaOrigin() => GenericaTurmaAdapter(origin, access),
  };
}
