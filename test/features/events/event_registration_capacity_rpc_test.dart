// Fase 1 - Plano 05. Prova de que inscricao de membro usa a RPC atomica
// register_member_in_event; o servidor concentra autorizacao, capacidade e
// ON CONFLICT (event_id, user_id).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _memberId = '22222222-0000-4000-8000-000000000002';
const _registrationId = '33333333-0000-4000-8000-000000000003';

class _EventRegistrationCapacityRpcSpy {
  final bool eventFull;
  final List<Uri> rpcCalls = [];
  final List<Map<String, dynamic>> rpcBodies = [];
  final List<Uri> directRegistrationPosts = [];
  final List<Uri> registrationReads = [];

  _EventRegistrationCapacityRpcSpy({this.eventFull = false});

  http.Client get client => MockClient((request) async {
    final json = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/register_member_in_event') &&
        request.method == 'POST') {
      rpcCalls.add(request.url);
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (eventFull) {
        return http.Response(
          jsonEncode({
            'code': 'P0001',
            'message': 'EVENT_FULL',
            'details': null,
            'hint': null,
          }),
          400,
          request: request,
          headers: json,
        );
      }

      return http.Response(
        jsonEncode(_registrationId),
        200,
        request: request,
        headers: json,
      );
    }

    if (request.url.path.endsWith('/event_registration')) {
      if (request.method == 'POST') {
        directRegistrationPosts.add(request.url);
      }

      if (request.method == 'GET') {
        registrationReads.add(request.url);
        return http.Response(
          jsonEncode({
            'id': _registrationId,
            'event_id': _eventId,
            'user_id': _memberId,
            'registered_at': '2026-08-21T23:00:00.000Z',
            'qr_code': 'EVENT_TICKET:$_eventId:$_memberId',
          }),
          200,
          request: request,
          headers: json,
        );
      }
    }

    return http.Response('[]', 200, request: request, headers: json);
  });
}

EventsRepository _repoWith(_EventRegistrationCapacityRpcSpy spy) =>
    EventsRepository(
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
    'registerMemberInEvent faz POST para a RPC com os parametros esperados',
    () async {
      final spy = _EventRegistrationCapacityRpcSpy();

      await _repoWith(
        spy,
      ).registerMemberInEvent(eventId: _eventId, memberId: _memberId);

      expect(
        spy.rpcCalls.single.path,
        endsWith('/rpc/register_member_in_event'),
      );
      expect(spy.rpcBodies.single.keys.toSet(), {'p_event_id', 'p_user_id'});
      expect(spy.rpcBodies.single['p_event_id'], _eventId);
      expect(spy.rpcBodies.single['p_user_id'], _memberId);
    },
  );

  test(
    'registerMemberInEvent nao faz POST direto em event_registration',
    () async {
      final spy = _EventRegistrationCapacityRpcSpy();

      await _repoWith(
        spy,
      ).registerMemberInEvent(eventId: _eventId, memberId: _memberId);

      expect(spy.directRegistrationPosts, isEmpty);
      expect(
        spy.registrationReads,
        hasLength(1),
        reason: 'a releitura por id e SELECT, nao escrita direta',
      );
    },
  );

  test(
    'EVENT_FULL propagado pela RPC continua inspecionavel pela tela',
    () async {
      final spy = _EventRegistrationCapacityRpcSpy(eventFull: true);

      await expectLater(
        _repoWith(
          spy,
        ).registerMemberInEvent(eventId: _eventId, memberId: _memberId),
        throwsA(predicate((error) => error.toString().contains('EVENT_FULL'))),
      );

      expect(spy.registrationReads, isEmpty);
    },
  );

  test('addRegistration delega para o mesmo caminho de RPC', () async {
    final spy = _EventRegistrationCapacityRpcSpy();

    await _repoWith(spy).addRegistration(_eventId, _memberId);

    expect(spy.rpcCalls.single.path, endsWith('/rpc/register_member_in_event'));
    expect(spy.directRegistrationPosts, isEmpty);
  });
}
