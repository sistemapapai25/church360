import 'package:flutter/widgets.dart';

import '../../../../study_groups/domain/models/study_group.dart';
import '../turma_access.dart';
import '../turma_origin.dart';
import 'batismo_turma_adapter.dart';
import 'generica_turma_adapter.dart';

/// Onde esta turma se edita, para o botão que a vitrine de Cursos oferece
/// à liderança: o rótulo e a rota.
typedef TurmaManageTarget = ({String label, String route});

/// As abas que variam com a origem da turma. As outras (Aulas, Materiais)
/// são as mesmas para qualquer turma e não passam por aqui.
abstract interface class TurmaSurfaces {
  Widget alunos();
  Widget minhaFrequencia();

  /// Aba Presença da tela da aula — o único lugar da chamada nas duas
  /// origens. Quem faz (ou lê) a chamada vê a da aula; o aluno, a própria
  /// marca; o resto, um aviso.
  Widget lessonPresence(StudyLesson lesson);

  /// Para onde a liderança vai quando quer editar a turma que abriu pela
  /// vitrine de Cursos. Cada origem sabe a sua porta — a tela só mostra o
  /// botão. `null` quando não há porta.
  TurmaManageTarget? get manage;

  /// A turma aceita "Participar" quando é pública (`turma_join`). O
  /// Batismo não: lá a entrada é a inscrição do ministério.
  bool get acceptsJoin;
}

/// Único `switch` sobre a origem na árvore da tela da turma.
TurmaSurfaces turmaSurfacesFor(TurmaOrigin origin, TurmaAccess access) {
  return switch (origin) {
    BatismoTurmaOrigin() => BatismoTurmaAdapter(origin, access),
    GenericaTurmaOrigin() => GenericaTurmaAdapter(origin, access),
  };
}
