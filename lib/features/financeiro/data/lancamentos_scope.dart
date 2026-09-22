// =====================================================
// CHURCH 360 - RECORTE DO LIVRO-CAIXA DA IGREJA
// =====================================================

/// Filtro que mantém o livro-caixa da igreja livre de saída de ministério
/// ainda não confirmada.
///
/// Desde 21/09 `lancamentos` guarda também o caixa dos departamentos:
/// `ministry_id` não nulo, e saída nascendo `PENDENTE` pelo trigger
/// `lancamentos_set_approval`. Nenhuma tela da igreja sabia disso, e a régua
/// do previsto no dashboard é "tudo que não for CANCELADO" — então uma saída
/// de departamento que ninguém aprovou derrubaria o saldo previsto da igreja
/// e apareceria no resumo por categoria como despesa real.
///
/// A régua deste recorte é: **o caixa da igreja soma o que é dela e o que o
/// departamento já teve aprovado**. Lançamento pendente ou rejeitado de
/// ministério fica só na aba do ministério, onde é a fila de aprovação.
///
/// Não é filtro de segurança — quem não pode ver essas linhas já não as
/// recebe, pelas policies de 21/09. É filtro de CONTA: evita somar duas
/// vezes régua diferente na mesma tela.
const String kLancamentosIgrejaScope =
    'ministry_id.is.null,approval_status.eq.APROVADO';
