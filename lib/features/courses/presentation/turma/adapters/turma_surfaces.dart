import 'package:flutter/widgets.dart';

import '../turma_access.dart';
import '../turma_origin.dart';
import 'batismo_turma_adapter.dart';
import 'generica_turma_adapter.dart';

/// As abas que variam com a origem da turma. As outras (Aulas, Materiais)
/// são as mesmas para qualquer turma e não passam por aqui.
abstract interface class TurmaSurfaces {
  Widget alunos();
  Widget presenca();
  Widget minhaFrequencia();
}

/// Único `switch` sobre a origem na árvore da tela da turma.
TurmaSurfaces turmaSurfacesFor(TurmaOrigin origin, TurmaAccess access) {
  return switch (origin) {
    BatismoTurmaOrigin() => BatismoTurmaAdapter(origin),
    GenericaTurmaOrigin() => GenericaTurmaAdapter(origin, access),
  };
}
