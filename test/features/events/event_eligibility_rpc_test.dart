// VIS-03/VIS-04 (Plano 03-08): o cliente consome a elegibilidade de audiência
// SEMPRE pelas RPCs do servidor (`am_i_eligible_to_register` e
// `list_event_eligible_members`), nunca resolvendo grupo/ministério/cargo em
// Dart. Estes testes travam a forma da chamada (path + chave `p_event_id`) e a
// desserialização fail-closed; a autoridade de decisão continua no servidor.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';

/// Spy no mesmo padrão de `event_registration_on_conflict_test.dart`:
/// intercepta por sufixo de path da RPC e registra corpo + contagem.
class _EligibilityApiSpy {
  final List<Uri> eligibilityPosts = [];
  final List<Map<String, dynamic>> eligibilityBodies = [];
  final List<Uri> eligibleMembersPosts = [];
  final List<Map<String, dynamic>> eligibleMembersBodies = [];

  /// Resposta que o servidor devolve para `am_i_eligible_to_register`.
  Object? eligibilityResponse = true;

  /// Resposta que o servidor devolve para `list_event_eligible_members`.
  Object? eligibleMembersResponse = const [];

  /// Quando verdadeiro, a RPC de elegibilidade responde erro do PostgREST.
  bool failEligibility = false;

  http.Client get client => MockClient((request) async {
    final json = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/am_i_eligible_to_register') &&
        request.method == 'POST') {
      eligibilityPosts.add(request.url);
      eligibilityBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));
      if (failEligibility) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for function',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode(eligibilityResponse),
        200,
        request: request,
        headers: json,
      );
    }

    if (request.url.path.endsWith('/rpc/list_event_eligible_members') &&
        request.method == 'POST') {
      eligibleMembersPosts.add(request.url);
      eligibleMembersBodies.add(
        Map<String, dynamic>.from(jsonDecode(request.body)),
      );
      return http.Response(
        jsonEncode(eligibleMembersResponse),
        200,
        request: request,
        headers: json,
      );
    }

    return http.Response('[]', 200, request: request, headers: json);
  });
}

EventsRepository _repoWith(_EligibilityApiSpy spy) => EventsRepository(
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
    'amIEligibleToRegister faz UM POST na RPC com a chave p_event_id',
    () async {
      final spy = _EligibilityApiSpy();

      await _repoWith(spy).amIEligibleToRegister(_eventId);

      expect(spy.eligibilityPosts, hasLength(1));
      expect(spy.eligibilityBodies.single, {'p_event_id': _eventId});
    },
  );

  test('amIEligibleToRegister devolve true quando o servidor diz true', () async {
    final spy = _EligibilityApiSpy()..eligibilityResponse = true;

    expect(await _repoWith(spy).amIEligibleToRegister(_eventId), isTrue);
  });

  test('amIEligibleToRegister devolve false quando o servidor diz false', () async {
    final spy = _EligibilityApiSpy()..eligibilityResponse = false;

    expect(await _repoWith(spy).amIEligibleToRegister(_eventId), isFalse);
  });

  test(
    'listEventEligibleMembers faz UM POST com p_event_id e desserializa a lista',
    () async {
      final spy = _EligibilityApiSpy()
        ..eligibleMembersResponse = [
          {'id': 'm1', 'full_name': 'Ana Silva', 'nickname': 'Aninha'},
          {'id': 'm2', 'full_name': 'Bruno Souza'},
        ];

      final membros = await _repoWith(spy).listEventEligibleMembers(_eventId);

      expect(spy.eligibleMembersPosts, hasLength(1));
      expect(spy.eligibleMembersBodies.single, {'p_event_id': _eventId});
      expect(membros, hasLength(2));
      expect(membros.first['id'], 'm1');
      expect(membros.first['full_name'], 'Ana Silva');
    },
  );

  test(
    'listEventEligibleMembers devolve lista vazia sem lançar quando a RPC nega',
    () async {
      // A RPC responde `[]` (não erro) para chamador sem autorização — o
      // repositório precisa refletir isso como lista vazia, e o diálogo
      // transforma em estado vazio explicado.
      final spy = _EligibilityApiSpy()..eligibleMembersResponse = const [];

      expect(await _repoWith(spy).listEventEligibleMembers(_eventId), isEmpty);
    },
  );

  test('erro do PostgREST propaga: o repositório não engole nem traduz', () async {
    final spy = _EligibilityApiSpy()..failEligibility = true;

    expect(
      () => _repoWith(spy).amIEligibleToRegister(_eventId),
      throwsA(isA<PostgrestException>()),
    );
  });
}
