// Fase 4 — Plano 06. Prova de que setEventReminders faz delete-then-insert
// em event_reminder com tenant_id carimbado, e que lista vazia só deleta
// (D-03: zero lembretes é estado válido). Espião MockClient sobre o
// PostgREST real, sem mock de repositório — mesmo molde de
// event_audience_repository_test.dart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_reminder.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';

class _EventReminderApiSpy {
  final List<Uri> deletes = [];
  final List<Uri> gets = [];
  final List<Map<String, dynamic>> insertedRows = [];
  bool insertCalled = false;

  http.Client get client => MockClient((request) async {
    final json = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/event_reminder') &&
        request.method == 'DELETE') {
      deletes.add(request.url);
      return http.Response('[]', 200, request: request, headers: json);
    }

    if (request.url.path.endsWith('/event_reminder') &&
        request.method == 'POST') {
      insertCalled = true;
      final body = jsonDecode(request.body);
      for (final row in (body is List ? body : [body])) {
        insertedRows.add(Map<String, dynamic>.from(row as Map));
      }
      return http.Response(request.body, 201, request: request, headers: json);
    }

    if (request.url.path.endsWith('/event_reminder') &&
        request.method == 'GET') {
      gets.add(request.url);
      return http.Response('[]', 200, request: request, headers: json);
    }

    return http.Response('[]', 200, request: request, headers: json);
  });
}

EventsRepository _repoWith(_EventReminderApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: sem isso o timer de auto-refresh do GoTrue fica pendente e
    // quebra a checagem de "pending timer" do flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

void main() {
  group('EventReminder — modelo', () {
    test('fromJson resolve offsetMinutes como int', () {
      final reminder = EventReminder.fromJson({
        'id': 'x',
        'event_id': _eventId,
        'tenant_id': 'tenant-1',
        'offset_minutes': 2880,
        'created_at': '2026-08-31T00:00:00.000Z',
      });

      expect(reminder.offsetMinutes, 2880);
      expect(reminder.offsetMinutes, isA<int>());
    });

    test('toJson produz snake_case e não inclui id', () {
      final json = EventReminder(
        id: 'x',
        eventId: _eventId,
        offsetMinutes: 120,
      ).toJson();

      expect(json['event_id'], _eventId);
      expect(json['offset_minutes'], 120);
      expect(json.containsKey('id'), isFalse);
    });

    test('offsetMinutes igual a zero dispara o assert do CHECK', () {
      expect(
        () => EventReminder(eventId: _eventId, offsetMinutes: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('offsetMinutes negativo dispara o assert do CHECK', () {
      expect(
        () => EventReminder(eventId: _eventId, offsetMinutes: -10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('offsetMinutes acima de 525600 dispara o assert do CHECK', () {
      expect(
        () => EventReminder(eventId: _eventId, offsetMinutes: 525601),
        throwsA(isA<AssertionError>()),
      );
    });

    test('label em minutos para offset abaixo de 60', () {
      expect(EventReminder(eventId: _eventId, offsetMinutes: 15).label, contains('15 minuto'));
    });

    test('label em horas para múltiplo exato de 60 abaixo de um dia', () {
      expect(EventReminder(eventId: _eventId, offsetMinutes: 120).label, contains('2 horas'));
    });

    test('label em dias para múltiplo exato de 1440', () {
      expect(EventReminder(eventId: _eventId, offsetMinutes: 2880).label, contains('2 dias'));
    });

    test('label nunca expõe o número bruto de minutos para offsets em hora/dia', () {
      final label = EventReminder(eventId: _eventId, offsetMinutes: 2880).label;
      expect(label, isNot(contains('2880')));
    });
  });

  group('EventsRepository — setEventReminders/getEventReminders', () {
    test('lista vazia emite apenas DELETE, nenhum POST (D-03)', () async {
      final spy = _EventReminderApiSpy();

      await _repoWith(spy).setEventReminders(_eventId, []);

      expect(spy.deletes, isNotEmpty);
      expect(
        Uri.decodeFull(spy.deletes.single.toString()),
        contains('event_id=eq.$_eventId'),
      );
      expect(spy.insertCalled, isFalse);
    });

    test('dois lembretes emitem DELETE seguido de um único POST com duas linhas, tenant_id carimbado', () async {
      final spy = _EventReminderApiSpy();

      await _repoWith(spy).setEventReminders(_eventId, [
        EventReminder(eventId: _eventId, offsetMinutes: 2880),
        EventReminder(eventId: _eventId, offsetMinutes: 120),
      ]);

      expect(spy.deletes.length, 1);
      expect(spy.insertedRows.length, 2);
      for (final row in spy.insertedRows) {
        expect(row['tenant_id'], isNotNull);
        expect(row['event_id'], _eventId);
      }
    });

    test('getEventReminders emite GET filtrado por event_id', () async {
      final spy = _EventReminderApiSpy();

      await _repoWith(spy).getEventReminders(_eventId);

      expect(spy.gets, isNotEmpty);
      expect(
        Uri.decodeFull(spy.gets.single.toString()),
        contains('event_id=eq.$_eventId'),
      );
    });
  });
}
