import 'turma_access.dart';

/// As abas da tela da turma.
enum TurmaTabId {
  aulas('Aulas'),
  alunos('Alunos'),
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
///
/// Não há aba Presença: a chamada é feita dentro da aula e a frequência de
/// cada aluno aparece em Alunos (PR 1 do módulo acadêmico, 02/10).
List<TurmaTabId> turmaTabsFor(TurmaAccess access) {
  return switch (access.role) {
    TurmaRole.leadership => const [
        TurmaTabId.aulas,
        TurmaTabId.alunos,
        TurmaTabId.materiais,
      ],
    TurmaRole.student => const [
        TurmaTabId.aulas,
        TurmaTabId.minhaFrequencia,
        TurmaTabId.materiais,
      ],
    // O professor não abre a turma: entra direto na aula, pela Agenda.
    TurmaRole.teacher || TurmaRole.none => const [],
  };
}
