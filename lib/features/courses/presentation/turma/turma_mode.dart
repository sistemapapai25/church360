/// Por qual porta a tela da turma foi aberta — e, por causa disso, se ela
/// grava alguma coisa.
///
/// A terceira pergunta da tela, ao lado de *que turma é esta*
/// (`turmaOriginProvider`) e *quem eu sou nela* (`turmaAccessProvider`):
/// *de onde eu entrei*. Nenhuma das três deduz as outras — o líder do
/// Batismo continua sendo líder quando chega por Cursos, e mesmo assim não
/// edita ali.
enum TurmaMode {
  /// Porta de Cursos (`/courses/:courseId/turmas/:studyGroupId`): vitrine.
  /// Mostra tudo o que o papel enxerga e não grava nada — nem aula, nem
  /// aluno, nem presença.
  leitura,

  /// Porta de gestão (`/turmas/:studyGroupId/gestao`): a turma do Batismo
  /// aberta pelo sheet de Turmas do ministério, e a turma genérica aberta
  /// pelo botão "Gerenciar". Aqui o papel vale inteiro.
  gestao,
}
