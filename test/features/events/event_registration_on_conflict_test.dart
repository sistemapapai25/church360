// CHU-322: o onConflict correto para event_registration é (event_id, user_id).
// A partir do Plano 05, esse detalhe saiu do cliente e passou a morar dentro
// da RPC register_member_in_event; este teste impede regressão ao POST direto
// na tabela.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _memberId = '22222222-0000-4000-8000-000000000002';
const _registrationId = '33333333-0000-4000-8000-000000000003';

class _EventRegistrationApiSpy {
  final List<Uri> directRegistrationPosts = [];
  final List<Map<String, dynamic>> rpcBodies = [];

  http.Client get client => MockClient((request) async {
    final json = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/register_member_in_event') &&
        request.method == 'POST') {
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));
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

    return http.Response('[]', 200, request: request, headers: json);
  });
}

EventsRepository _repoWith(_EventRegistrationApiSpy spy) => EventsRepository(
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
    'inscrição de membro usa a RPC que contém o ON CONFLICT correto',
    () async {
      final spy = _EventRegistrationApiSpy();

      await _repoWith(
        spy,
      ).registerMemberInEvent(eventId: _eventId, memberId: _memberId);

      expect(spy.rpcBodies.single, {
        'p_event_id': _eventId,
        'p_user_id': _memberId,
      });
    },
  );

  test(
    'inscrição de membro não faz POST direto em event_registration',
    () async {
      final spy = _EventRegistrationApiSpy();

      await _repoWith(
        spy,
      ).registerMemberInEvent(eventId: _eventId, memberId: _memberId);

      expect(spy.directRegistrationPosts, isEmpty);
    },
  );
}
