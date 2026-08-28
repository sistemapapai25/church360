import 'package:supabase_flutter/supabase_flutter.dart';

/// REG-04 — tradução única da recusa de capacidade emitida pelo servidor.
///
/// A RPC `register_member_in_event` (migration `20260825000500`, Plano 05) é a
/// autoridade sobre a vaga: quando o teto já foi atingido ela executa
/// `RAISE EXCEPTION 'EVENT_FULL'`, que chega ao cliente como
/// `PostgrestException` com o literal na mensagem. A UI apenas antecipa o
/// teto — nunca conta inscritos para decidir se há vaga.
///
/// Detecção e copy vivem neste arquivo, em um lugar só, para que os dois
/// pontos de entrada de inscrição (diálogo "Adicionar Inscrito" e tela de
/// autoinscrição) usem a MESMA condição e a MESMA string. Duas cópias
/// divergentes é como esta mensagem envelhece errado.
const String eventFullErrorCode = 'EVENT_FULL';

/// Verdadeiro quando [error] é a recusa `EVENT_FULL` vinda da RPC.
///
/// A checagem varre código, mensagem, detalhes e hint do `PostgrestException`
/// porque o PostgREST pode acomodar o literal do `RAISE` em campos diferentes
/// conforme a versão. Para qualquer outro tipo de erro, cai no `toString()`.
bool isEventFullError(Object error) {
  if (error is PostgrestException) {
    final haystack =
        '${error.code ?? ''} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    return haystack.contains(eventFullErrorCode);
  }
  return error.toString().contains(eventFullErrorCode);
}

/// Copy PT-BR exata do UI-SPEC para a recusa `EVENT_FULL`.
///
/// [maxCapacity] nulo (evento cuja capacidade não veio no contexto) omite a
/// parte numérica — nunca imprimir `null` para o usuário.
String eventFullMessage(int? maxCapacity) {
  final teto = maxCapacity != null
      ? 'A capacidade máxima de $maxCapacity inscritos já foi atingida.'
      : 'A capacidade máxima já foi atingida.';
  return 'Evento lotado. $teto '
      'Aumente a capacidade na edição do evento para liberar novas vagas.';
}
