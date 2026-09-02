// Fase 6 — tradução única dos códigos de erro das RPCs de série.
//
// As RPCs de série (`delete_event_series_future`, migration `20260902000500`,
// e as de aplicar/estender/regerar dos Planos 06 e 08) sinalizam recusa com
// `RAISE EXCEPTION '<LITERAL>'`, que chega ao Dart dentro de um
// `PostgrestException`. A UI nunca deriva essas condições localmente — o
// servidor é a autoridade, e o gate de UI é só UX (IC-8 do `06-UI-SPEC.md`).
//
// DETECÇÃO E COPY VIVEM NESTE ARQUIVO, EM UM LUGAR SÓ, porque os quatro
// pontos de chamada de operação de série desta fase — excluir futuras,
// aplicar à série, estender/encurtar e regerar — precisam usar a MESMA
// condição e a MESMA string. Duas cópias divergentes é exatamente como esta
// mensagem envelhece errado: uma tela passa a explicar o que fazer e a outra
// continua mostrando um código. Mesmo molde de `event_full_error.dart`.
//
// A copy "Nada foi alterado" usada pelos diálogos destrutivos desta fase só é
// verdadeira porque cada operação executa numa RPC única, em UMA transação.
// Se algum plano quebrar uma dessas operações em mais de uma chamada do
// cliente, essa copy vira mentira e precisa mudar junto com estes códigos.
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recusa da guarda de responsável/permissão dentro da RPC.
const String seriesPermissionDeniedCode = 'PERMISSION_DENIED';

/// `current_tenant_id()` não resolveu a igreja ativa da sessão.
const String seriesTenantNotFoundCode = 'TENANT_ID_NOT_FOUND';

/// O lote informado não corresponde a nenhuma série visível para o ator.
const String seriesNotFoundCode = 'SERIES_NOT_FOUND';

/// A série existe, mas não há ocorrência futura para a operação atingir.
const String seriesNoFutureOccurrencesCode = 'NO_FUTURE_OCCURRENCES';

/// Código que o PostgREST emite quando o chamador não tem `EXECUTE` na função.
///
/// Tratado como **sinônimo** de [seriesPermissionDeniedCode]: o literal do
/// `RAISE` nunca chega a ser levantado nesse caminho (a chamada é recusada
/// antes de entrar na função), mas para o líder é a mesma situação — ele não
/// pode alterar esta série, e o próximo passo é o mesmo.
const String seriesInsufficientPrivilegeCode = '42501';

/// Concatena os quatro campos do `PostgrestException` onde o literal do
/// `RAISE` pode aparecer.
///
/// O PostgREST acomoda o literal em `code`, `message`, `details` ou `hint`
/// conforme a versão — varrer só um campo é falso-negativo silencioso. Mesma
/// forma de `event_full_error.dart`.
String _haystack(Object error) {
  if (error is PostgrestException) {
    return '${error.code ?? ''} ${error.message} '
        '${error.details ?? ''} ${error.hint ?? ''}';
  }
  return error.toString();
}

/// Copy PT-BR do `06-UI-SPEC.md` para [error], ou `null` quando o erro não é
/// nenhum dos códigos conhecidos.
///
/// `null` é resposta legítima e significa "não sei o que é isto": o chamador
/// delega a `AppErrorHandler.map`/`showSnackBar` com o `fallbackMessage` da
/// operação. Nunca renderizar `$e`.
String? seriesErrorMessage(Object error) {
  final haystack = _haystack(error);

  if (haystack.contains(seriesPermissionDeniedCode) ||
      haystack.contains(seriesInsufficientPrivilegeCode)) {
    return 'Você não é o responsável por este evento. Peça ao responsável ou '
        'ao Pastor Senior para alterar a série.';
  }
  if (haystack.contains(seriesTenantNotFoundCode)) {
    return 'Não foi possível identificar a igreja ativa. Saia e entre de novo '
        'no app.';
  }
  if (haystack.contains(seriesNotFoundCode)) {
    return 'Não encontramos os dados desta série. Recarregue a tela e tente de '
        'novo.';
  }
  if (haystack.contains(seriesNoFutureOccurrencesCode)) {
    return 'Esta série não tem ocorrências futuras para alterar.';
  }
  return null;
}
