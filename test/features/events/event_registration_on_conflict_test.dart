// CHU-322: `registerMemberInEvent` fazia `.upsert()` sem `onConflict`. O
// PostgREST então infere a PK (`id`) como alvo do ON CONFLICT — e como o app
// nunca envia o `id`, o upsert vira INSERT puro: reinscrever alguém que já
// está no evento derruba a requisição com 409 na UNIQUE (event_id, user_id).
//
// A UNIQUE foi conferida contra a base de produção em 21/08/2026:
// `on_conflict=event_id,user_id,tenant_id` devolve 42P10 (não existe),
// `on_conflict=event_id,user_id` passa da checagem de constraint.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _memberId = '22222222-0000-4000-8000-000000000002';

class _EventRegistrationApiSpy {
  final List<Uri> upserts = [];
  final List<Map<String, dynamic>> upsertedRows = [];

  http.Client get client => MockClient((request) async {
        final json = {'content-type': 'application/json; charset=utf-8'};

        if (request.url.path.endsWith('/event_registration') &&
            request.method == 'POST') {
          upserts.add(request.url);
          final body = jsonDecode(request.body);
          for (final row in (body is List ? body : [body])) {
            upsertedRows.add(Map<String, dynamic>.from(row as Map));
          }
          // `.single()` pede `application/vnd.pgrst.object+json`: a resposta
          // tem que ser o objeto, não uma lista de um item.
          return http.Response(
            jsonEncode({
              'id': '33333333-0000-4000-8000-000000000003',
              'event_id': _eventId,
              'user_id': _memberId,
              'registered_at': '2026-08-21T23:00:00.000Z',
            }),
            201,
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
      ),
    );

void main() {
  test('a inscrição declara o conflito por (event_id, user_id)', () async {
    final spy = _EventRegistrationApiSpy();

    await _repoWith(spy).registerMemberInEvent(
      eventId: _eventId,
      memberId: _memberId,
    );

    expect(
      spy.upserts.single.queryParameters['on_conflict'],
      'event_id,user_id',
    );
  });

  test('a inscrição continua mandando evento, membro e tenant', () async {
    final spy = _EventRegistrationApiSpy();

    await _repoWith(spy).registerMemberInEvent(
      eventId: _eventId,
      memberId: _memberId,
    );

    final row = spy.upsertedRows.single;
    expect(row['event_id'], _eventId);
    expect(row['user_id'], _memberId);
    expect(row['tenant_id'], isNotNull);
    expect(row.containsKey('id'), isFalse,
        reason: 'o app não envia a PK — é por isso que o onConflict é preciso');
  });
}
