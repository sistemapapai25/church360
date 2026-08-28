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
const _roleId = '55555555-0000-4000-8000-000000000005';

class _EventAudienceApiSpy {
  final List<Uri> deletes = [];
  final List<Map<String, dynamic>> insertedRows = [];
  final List<Map<String, String>> insertHeaders = [];
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
          insertHeaders.add(Map<String, String>.from(request.headers));
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

  // Fase 3 — Plano 03, Task 2. O repositório deixa de ter role='responsible'
  // hardcoded: grava e lê audiência para qualquer papel, com cargo incluído.
  group('setEventAudience — papel parametrizado e cargo', () {
    test('grava alvo de cargo com role=visibility no DELETE e no POST', () async {
      final spy = _EventAudienceApiSpy();

      await _repoWith(spy).setEventAudience(_eventId, 'visibility', [
        EventAudience(
          eventId: _eventId,
          role: 'visibility',
          rbacRoleId: _roleId,
        ),
      ]);

      expect(spy.deletes.length, 1);
      final deleteUrl = Uri.decodeFull(spy.deletes.single.toString());
      expect(deleteUrl, contains('role=eq.visibility'));
      expect(deleteUrl, contains('event_id=eq.$_eventId'));

      expect(spy.insertedRows.length, 1);
      expect(spy.insertedRows.single['role'], 'visibility');
      expect(spy.insertedRows.single['rbac_role_id'], _roleId);
    });

    test('toda linha enviada tem as 4 chaves de alvo com exatamente uma não-nula', () async {
      final spy = _EventAudienceApiSpy();

      await _repoWith(spy).setEventAudience(_eventId, 'registration', [
        EventAudience(eventId: _eventId, role: 'registration', userId: _personId),
        EventAudience(eventId: _eventId, role: 'registration', groupId: _groupId),
        EventAudience(
          eventId: _eventId,
          role: 'registration',
          ministryId: _ministryId,
        ),
        EventAudience(
          eventId: _eventId,
          role: 'registration',
          rbacRoleId: _roleId,
        ),
      ]);

      expect(spy.insertedRows.length, 4);
      for (final row in spy.insertedRows) {
        for (final key in ['user_id', 'group_id', 'ministry_id', 'rbac_role_id']) {
          expect(row.containsKey(key), isTrue, reason: '$key ausente na linha');
        }
        final naoNulos = [
          row['user_id'],
          row['group_id'],
          row['ministry_id'],
          row['rbac_role_id'],
        ].where((v) => v != null).length;
        expect(naoNulos, 1, reason: 'cada linha grava exatamente um alvo');
        expect(row['tenant_id'], isNotNull);
        expect(row['event_id'], _eventId);
        expect(row['role'], 'registration');
      }
    });

    test('lista vazia deleta o papel recebido e não insere nada', () async {
      final spy = _EventAudienceApiSpy();

      await _repoWith(spy).setEventAudience(_eventId, 'registration', []);

      expect(spy.deletes.length, 1);
      expect(
        Uri.decodeFull(spy.deletes.single.toString()),
        contains('role=eq.registration'),
      );
      expect(spy.insertCalled, isFalse);
    });

    test('setEventResponsibles continua gravando role=responsible (sem regressão da Fase 1)', () async {
      final spy = _EventAudienceApiSpy();

      await _repoWith(spy).setEventResponsibles(_eventId, [
        EventAudience(eventId: _eventId, role: 'responsible', userId: _personId),
      ]);

      expect(
        Uri.decodeFull(spy.deletes.single.toString()),
        contains('role=eq.responsible'),
      );
      expect(spy.insertedRows.single['role'], 'responsible');
      expect(spy.insertedRows.single['user_id'], _personId);
      expect(spy.insertedRows.single['rbac_role_id'], isNull);
    });

    test('POST de audiência não é upsert: sem Prefer resolution=merge-duplicates', () async {
      final spy = _EventAudienceApiSpy();

      await _repoWith(spy).setEventAudience(_eventId, 'visibility', [
        EventAudience(
          eventId: _eventId,
          role: 'visibility',
          rbacRoleId: _roleId,
        ),
      ]);

      expect(spy.insertHeaders, isNotEmpty);
      for (final headers in spy.insertHeaders) {
        final prefer = headers.entries
            .firstWhere(
              (e) => e.key.toLowerCase() == 'prefer',
              orElse: () => const MapEntry('prefer', ''),
            )
            .value;
        expect(prefer.contains('resolution=merge-duplicates'), isFalse);
      }
    });
  });

  // Fase 3 — Plano 03, Task 1. Cargo (papel RBAC de public.roles) como quarto
  // tipo de alvo, espelhando a coluna rbac_role_id do servidor.
  group('EventAudience — alvo de cargo', () {
    test('constrói com rbacRoleId e resolve targetKind/targetId de cargo', () {
      final audience = EventAudience(
        eventId: _eventId,
        role: 'visibility',
        rbacRoleId: _roleId,
      );

      expect(audience.targetKind, EventAudienceTargetKind.role);
      expect(audience.targetId, _roleId);
    });

    test('dois alvos (groupId + rbacRoleId) dispara o assert de alvo único', () {
      expect(
        () => EventAudience(
          eventId: _eventId,
          role: 'visibility',
          groupId: _groupId,
          rbacRoleId: _roleId,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('nenhum alvo dispara o assert de alvo único', () {
      expect(
        () => EventAudience(eventId: _eventId, role: 'visibility'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromJson com rbac_role_id resolve targetKind de cargo', () {
      final audience = EventAudience.fromJson({
        'id': 'x',
        'event_id': _eventId,
        'role': 'visibility',
        'user_id': null,
        'group_id': null,
        'ministry_id': null,
        'rbac_role_id': _roleId,
      });

      expect(audience.targetKind, EventAudienceTargetKind.role);
      expect(audience.targetId, _roleId);
      expect(audience.userId, isNull);
      expect(audience.groupId, isNull);
      expect(audience.ministryId, isNull);
    });

    test('toJson de alvo de cargo grava rbac_role_id e anula os outros três', () {
      final json = EventAudience(
        eventId: _eventId,
        role: 'registration',
        rbacRoleId: _roleId,
      ).toJson();

      expect(json['rbac_role_id'], _roleId);
      expect(json['user_id'], isNull);
      expect(json['group_id'], isNull);
      expect(json['ministry_id'], isNull);
      expect(json['role'], 'registration');
      expect(json['event_id'], _eventId);
    });

    test('alvos pessoa/grupo/ministério não regridem com o quarto tipo', () {
      final pessoa = EventAudience(
        eventId: _eventId,
        role: 'responsible',
        userId: _personId,
      );
      final grupo = EventAudience(
        eventId: _eventId,
        role: 'responsible',
        groupId: _groupId,
      );
      final ministerio = EventAudience(
        eventId: _eventId,
        role: 'responsible',
        ministryId: _ministryId,
      );

      expect(pessoa.targetKind, EventAudienceTargetKind.person);
      expect(pessoa.targetId, _personId);
      expect(grupo.targetKind, EventAudienceTargetKind.group);
      expect(grupo.targetId, _groupId);
      expect(ministerio.targetKind, EventAudienceTargetKind.ministry);
      expect(ministerio.targetId, _ministryId);

      for (final alvo in [pessoa, grupo, ministerio]) {
        expect(alvo.toJson()['rbac_role_id'], isNull);
      }
      expect(pessoa.toJson()['user_id'], _personId);
      expect(grupo.toJson()['group_id'], _groupId);
      expect(ministerio.toJson()['ministry_id'], _ministryId);
    });
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
