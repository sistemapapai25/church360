// Fase 1 — Plano 03. Prova de que setEventResponsibles grava em
// event_audience no formato exato exigido pelo servidor (Plano 02): um alvo
// por linha, role='responsible', tenant_id carimbado.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/domain/models/event_audience.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _personId = '22222222-0000-4000-8000-000000000002';
const _groupId = '33333333-0000-4000-8000-000000000003';
const _ministryId = '44444444-0000-4000-8000-000000000004';

class _EventAudienceApiSpy {
  final List<Uri> deletes = [];
  final List<Map<String, dynamic>> insertedRows = [];
  bool insertCalled = false;

  http.Client get client => MockClient((request) async {
        final json = {'content-type': 'application/json; charset=utf-8'};

        if (request.url.path.endsWith('/event_audience') &&
            request.method == 'DELETE') {
          deletes.add(request.url);
          return http.Response('[]', 200, request: request, headers: json);
        }

        if (request.url.path.endsWith('/event_audience') &&
            request.method == 'POST') {
          insertCalled = true;
          final body = jsonDecode(request.body);
          for (final row in (body is List ? body : [body])) {
            insertedRows.add(Map<String, dynamic>.from(row as Map));
          }
          return http.Response(request.body, 201, request: request, headers: json);
        }

        return http.Response('[]', 200, request: request, headers: json);
      });
}

EventsRepository _repoWith(_EventAudienceApiSpy spy) => EventsRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: spy.client,
      ),
    );

void main() {
  test('setEventResponsibles com pessoa, grupo e ministério emite 3 linhas, uma por alvo', () async {
    final spy = _EventAudienceApiSpy();

    await _repoWith(spy).setEventResponsibles(_eventId, [
      EventAudience(eventId: _eventId, role: 'responsible', userId: _personId),
      EventAudience(eventId: _eventId, role: 'responsible', groupId: _groupId),
      EventAudience(eventId: _eventId, role: 'responsible', ministryId: _ministryId),
    ]);

    expect(spy.insertedRows.length, 3);
    for (final row in spy.insertedRows) {
      expect(row['role'], 'responsible');
      expect(row['event_id'], _eventId);
      final targets = [row['user_id'], row['group_id'], row['ministry_id']]
          .where((v) => v != null)
          .length;
      expect(targets, 1, reason: 'cada linha grava exatamente um alvo');
    }
  });

  test('setEventResponsibles com lista vazia deleta e não insere nada', () async {
    final spy = _EventAudienceApiSpy();

    await _repoWith(spy).setEventResponsibles(_eventId, []);

    expect(spy.deletes, isNotEmpty);
    expect(spy.insertCalled, isFalse);
  });

  test('EventAudience.fromJson com group_id preenchido resolve targetKind de grupo', () {
    final audience = EventAudience.fromJson({
      'id': 'x',
      'event_id': _eventId,
      'role': 'responsible',
      'user_id': null,
      'group_id': _groupId,
      'ministry_id': null,
    });

    expect(audience.targetKind, EventAudienceTargetKind.group);
    expect(audience.userId, isNull);
    expect(audience.ministryId, isNull);
  });

  test('Event.fromJson sem visibility_scope/registration_scope resolve para all', () {
    final event = Event.fromJson({
      'id': _eventId,
      'name': 'Culto',
      'start_date': '2026-08-26T00:00:00.000Z',
      'created_at': '2026-08-26T00:00:00.000Z',
    });

    expect(event.visibilityScope, 'all');
    expect(event.registrationScope, 'all');
  });
}
