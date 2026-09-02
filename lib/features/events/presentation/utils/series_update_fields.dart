/// Fase 6 — REC-02. Monta o `p_fields` de `public.apply_event_series_update`
/// a partir do mapa `data` do formulário, trocando o escopo hardcoded pelo
/// escopo REAL da tela.
///
/// **Por que isto existe (bug `serie-visibilidade-rebaixada`).** O mapa `data`
/// de `_saveEvent` carrega sempre `visibility_scope: 'all'` e
/// `registration_scope: 'all'`. Esse literal é CORRETO no caminho de uma
/// ocorrência — Pitfall 1 (03-RESEARCH.md): a policy `AS RESTRICTIVE FOR
/// SELECT` também é avaliada no `INSERT/UPDATE ... RETURNING` de
/// `createEvent`/`updateEvent`, que usam `.select().single()`, e o escopo final
/// só pode ser promovido depois que a audiência existe.
///
/// No caminho da série o mesmo mapa era repassado INTACTO para a RPC. E ali o
/// literal não é inofensivo:
///   • `visibility_scope`/`registration_scope` **não** estão na `c_excluded` da
///     migration `20260902000600` (linhas 158-163: 9 colunas, nenhuma delas de
///     escopo);
///   • o passo (7) é **deny-list** — toda chave do jsonb que seja coluna real e
///     não excluída entra no `SET`;
///   • o `WHERE` não poupa a âncora.
/// Resultado: a série restrita inteira era gravada como `'all'`, e `'all'` é o
/// primeiro termo do `USING` de `event_visibility_restrict`
/// (`20260826000400:104-111`) — o curto-circuito que libera a linha para
/// qualquer autenticado do tenant sem sequer consultar `event_audience`.
/// Rebaixamento silencioso = exposição real do conteúdo restrito.
///
/// **Por que mandar o valor final aqui é seguro.** A razão do Pitfall 1 não
/// alcança este caminho: o passo (7) não tem `RETURNING` (a própria migration
/// diz, em 341-344, que a contagem sai de `GET DIAGNOSTICS`) e o corpo roda com
/// `SET row_security TO off` (linha 138). Não há policy avaliada sobre a linha
/// nova, logo não há o erro que obriga o `'all'` no outro caminho.
///
/// **Pré-condição de ordem, não desta função.** O passo (9) da RPC replica a
/// audiência DA ÂNCORA para o lote. Mandar `'restricted'` sem a âncora ter
/// alvos gravados produziria o modo de falha oposto (Pitfall 6: evento restrito
/// sem alvo é invisível para TODOS). Por isso quem chama esta função tem que
/// gravar a audiência da âncora ANTES e abortar se essa gravação falhar — ver
/// `_aplicarEdicaoATodaASerie` em `event_form_screen.dart`.
library;

/// Devolve uma CÓPIA de [base] com os dois campos de escopo trocados pelos
/// valores reais do formulário.
///
/// Não muta [base] — o mesmo mapa é usado pelo caminho de regeneração
/// (`_aplicarCamposComunsAposRegeneracao`), que precisa dele sem escopo nenhum.
Map<String, dynamic> seriesUpdateFields({
  required Map<String, dynamic> base,
  required String visibilityScope,
  required String registrationScope,
}) {
  return <String, dynamic>{
    ...base,
    'visibility_scope': visibilityScope,
    'registration_scope': registrationScope,
  };
}
