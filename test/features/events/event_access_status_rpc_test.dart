// LINK-01 / D-02 (Plano 02-04): depois da RLS da Fase 3, `eventByIdProvider`
// devolvendo `null` deixou de ter significado único — pode ser "restrito para
// mim" ou "não existe". Quem sabe a diferença é o servidor, via a RPC
// `public.get_event_access_status` (migration `20260901000200`, Plano 02-02).
//
// Estes testes travam DUAS coisas:
//   1. a forma da chamada (path + chave exata `p_event_id`, aridade 1, sem
//      nenhum parâmetro de ator — regressão CHU-326);
//   2. que a desserialização NÃO é fail-closed em direção a `not_found`. Regra
//      2 do Interaction Contract do `02-UI-SPEC.md`: falha de rede/servidor
//      nunca pode virar estado conclusivo. O erro tem que chegar cru ao
//      provider para a tela cair em `error` com "Tentar novamente".
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';

/// Spy no mesmo padrão de `event_eligibility_rpc_test.dart`: intercepta por
/// sufixo de path da RPC e registra corpo + contagem.
class _AccessStatusApiSpy {
  final List<Uri> posts = [];
  final List<Map<String, dynamic>> bodies = [];

  /// Resposta que o servidor devolve para `get_event_access_status`.
  Object? statusResponse = 'ok';

  /// Quando verdadeiro, a RPC responde o `42501` que o PostgREST emite para
  /// chamador sem `EXECUTE` (o caso do `anon`, que teve o grant revogado).
  bool failWithPermissionDenied = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/get_event_access_status') &&
        request.method == 'POST') {
      posts.add(request.url);
      bodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (failWithPermissionDenied) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for function get_event_access_status',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: headers,
        );
      }

      return http.Response(
        jsonEncode(statusResponse),
        200,
        request: request,
        headers: headers,
      );
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_AccessStatusApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

void main() {
  test(
    'getEventAccessStatus faz POST na RPC com a chave exata p_event_id',
    () async {
      final spy = _AccessStatusApiSpy();

      await _repoWith(spy).getEventAccessStatus(_eventId);

      expect(spy.posts.single.path, endsWith('/rpc/get_event_access_status'));
      // Aridade 1: nenhum parâmetro de ator sai do cliente.
      expect(spy.bodies.single, {'p_event_id': _eventId});
    },
  );

  test('getEventAccessStatus faz EXATAMENTE uma chamada por invocação', () async {
    final spy = _AccessStatusApiSpy();

    await _repoWith(spy).getEventAccessStatus(_eventId);

    expect(spy.posts, hasLength(1));
  });

  test("resposta 'restricted' devolve a string 'restricted'", () async {
    final spy = _AccessStatusApiSpy()..statusResponse = 'restricted';

    expect(await _repoWith(spy).getEventAccessStatus(_eventId), 'restricted');
  });

  test("resposta 'not_found' devolve a string 'not_found'", () async {
    final spy = _AccessStatusApiSpy()..statusResponse = 'not_found';

    expect(await _repoWith(spy).getEventAccessStatus(_eventId), 'not_found');
  });

  test('resposta null devolve null — não colapsa em not_found', () async {
    final spy = _AccessStatusApiSpy()..statusResponse = null;

    expect(await _repoWith(spy).getEventAccessStatus(_eventId), isNull);
  });

  test(
    'erro 42501 PROPAGA a exceção — nunca vira not_found nem string default',
    () async {
      // T-02-17: falha apresentada como "evento não encontrado" seria um
      // estado conclusivo mentiroso. O repositório propaga; a tela decide.
      final spy = _AccessStatusApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        () => _repoWith(spy).getEventAccessStatus(_eventId),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
