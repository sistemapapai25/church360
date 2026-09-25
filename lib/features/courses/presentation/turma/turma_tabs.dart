import 'turma_access.dart';

/// As abas da tela da turma.
enum TurmaTabId {
  aulas('Aulas'),
  alunos('Alunos'),
  presenca('Presença'),
  minhaFrequencia('Minha frequência'),
  materiais('Materiais');

  final String label;

  const TurmaTabId(this.label);
}

/// Quais abas cada papel vê, na ordem da barra. Aulas é sempre a primeira
/// (padrão ao abrir).
///
/// O aluno não tem Alunos: não lista colegas (decisão 26). A presença dele
/// é só a própria, em Minha frequência.
List<TurmaTabId> turmaTabsFor(TurmaAccess access) {
  return switch (access.role) {
    TurmaRole.leadership => const [
        TurmaTabId.aulas,
        TurmaTabId.alunos,
        TurmaTabId.presenca,
        TurmaTabId.materiais,
      ],
    TurmaRole.student => const [
        TurmaTabId.aulas,
        TurmaTabId.minhaFrequencia,
        TurmaTabId.materiais,
      ],
    TurmaRole.none => const [],
  };
}
