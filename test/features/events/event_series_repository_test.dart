// Fase 6 — REC-01 (Plano 06-02). As duas únicas portas da definição de série
// no cliente: `getEventSeries` (leitura por PostgREST) e `upsertEventSeries`
// (escrita pela RPC `public.upsert_event_series`, migration `20260902000300`).
//
// Estes testes travam TRÊS coisas:
//   1. a forma da chamada de escrita — path `/rpc/upsert_event_series` e
//      exatamente as 10 chaves `p_*` da assinatura do servidor, com assertiva
//      EXPLÍCITA de que nenhum parâmetro de ator sai do cliente. É a regressão
//      CHU-326: função que confia em quem o cliente diz ser. O ator vem de
//      `auth.uid()` e o tenant de `current_tenant_id()`, DENTRO do servidor;
//   2. que o erro de permissão NÃO é engolido em default. `event_series` não
//      tem policy de escrita e a autorização mora dentro da RPC — se `42501`
//      virasse "deu certo", a UI diria que a série ficou salva quando não
//      ficou;
//   3. que a leitura devolve `null` (série legada, IC-7) e não erro quando
//      não existe linha — hoje 100% das séries de produção estão nesse estado
//      (VEREDITO A4 do `06-DB-BASELINE.md`).
//
// Espião `MockClient` sobre o PostgREST real, sem mock de repositório — mesmo
// molde de `event_reminder_repository_test.dart` e `event_access_status_rpc_test.dart`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_series.dart';

const _batchId = '22222222-0000-4000-8000-000000000002';
const _anchorEventId = '11111111-0000-4000-8000-000000000001';

/// As 10 chaves da assinatura de `public.upsert_event_series`, na ordem do
/// servidor. Nenhuma a mais, nenhuma a menos.
const _chavesEsperadas = <String>{
  'p_batch_id',
  'p_anchor_event_id',
  'p_anchor_date',
  'p_pattern_group',
  'p_variable_type',
  'p_weekdays',
  'p_interval_weeks',
  'p_monthly_ordinal',
  'p_recurrence_end_date',
  'p_start_time_minutes',
};

/// Nomes de parâmetro de ator/tenant que NUNCA podem sair do cliente.
const _chavesDeAtorProibidas = <String>[
  'p_tenant_id',
  'p_actor',
  'p_actor_id',
  'p_user_id',
  'p_user_account_id',
  'p_auth_uid',
  'tenant_id',
  'user_id',
];

class _EventSeriesApiSpy {
  final List<Uri> gets = [];
  final List<Uri> rpcPosts = [];
  final List<Map<String, dynamic>> rpcBodies = [];

  /// Corpo bruto que o GET de `/event_series` devolve. `'[]'` = série legada.
  String seriesRows = '[]';

  /// Quando verdadeiro, a RPC responde o `42501` que o PostgREST emite quando
  /// a guarda de responsável/permissão dentro da função levanta
  /// `PERMISSION_DENIED`.
  bool failWithPermissionDenied = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/upsert_event_series') &&
        request.method == 'POST') {
      rpcPosts.add(request.url);
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (failWithPermissionDenied) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'PERMISSION_DENIED',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: headers,
        );
      }

      return http.Response(
        jsonEncode(_batchId),
        200,
        request: request,
        headers: headers,
      );
    }

    if (request.url.path.endsWith('/event_series') &&
        request.method == 'GET') {
      gets.add(request.url);
      return http.Response(seriesRows, 200, request: request, headers: headers);
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_EventSeriesApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: sem isso o timer de auto-refresh do GoTrue fica pendente e
    // quebra a checagem de "pending timer" do flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

Future<void> _upsertPadrao(EventsRepository repo) => repo.upsertEventSeries(
  batchId: _batchId,
  anchorEventId: _anchorEventId,
  anchorDate: DateTime(2026, 9, 2),
  patternGroup: 'semanal',
  variableType: null,
  weekdays: const [DateTime.sunday],
  intervalWeeks: 1,
  monthlyOrdinal: null,
  recurrenceEndDate: DateTime(2026, 12, 31),
  startTimeMinutes: 19 * 60 + 30,
);

void main() {
  group('EventSeries — modelo espelhando os CHECKs do servidor', () {
    test('fromJson lê weekdays como List<int> e recurrence_end_date como DateTime', () {
      final serie = EventSeries.fromJson({
        'id': _batchId,
        'tenant_id': 'tenant-1',
        'anchor_date': '2026-09-02',
        'pattern_group': 'semanal',
        'variable_type': null,
        'weekdays': [7, 3],
        'interval_weeks': 1,
        'monthly_ordinal': null,
        'recurrence_end_date': '2026-12-31',
        'start_time_minutes': 1170,
        'created_at': '2026-09-02T00:00:00.000Z',
        'updated_at': '2026-09-02T00:00:00.000Z',
      });

      expect(serie.id, _batchId);
      expect(serie.weekdays, isA<List<int>>());
      expect(serie.weekdays, [7, 3]);
      expect(serie.recurrenceEndDate, DateTime(2026, 12, 31));
      expect(serie.anchorDate, DateTime(2026, 9, 2));
      expect(serie.startTimeMinutes, 1170);
    });

    test('fromJson aceita recurrence_end_date nulo (horizonte padrão)', () {
      final serie = EventSeries.fromJson({
        'id': _batchId,
        'tenant_id': 'tenant-1',
        'anchor_date': '2026-09-02',
        'pattern_group': 'semanal',
        'weekdays': [7],
        'interval_weeks': 1,
        'recurrence_end_date': null,
        'start_time_minutes': 600,
      });

      expect(serie.recurrenceEndDate, isNull);
      expect(serie.variableType, isNull);
      expect(serie.monthlyOrdinal, isNull);
    });

    test('toJson não inclui id, tenant_id, created_at nem updated_at', () {
      final json = EventSeries(
        id: _batchId,
        tenantId: 'tenant-1',
        anchorDate: DateTime(2026, 9, 2),
        patternGroup: 'semanal',
        weekdays: const [7],
        intervalWeeks: 1,
        startTimeMinutes: 600,
        createdAt: DateTime(2026, 9, 2),
        updatedAt: DateTime(2026, 9, 2),
      ).toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('tenant_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
      expect(json['pattern_group'], 'semanal');
      expect(json['anchor_date'], '2026-09-02');
    });

    test('intervalWeeks igual a 9 dispara o assert de event_series_interval_chk', () {
      expect(
        () => EventSeries(
          anchorDate: DateTime(2026, 9, 2),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 9,
          startTimeMinutes: 600,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('startTimeMinutes igual a 1440 dispara o assert de event_series_start_time_chk', () {
      expect(
        () => EventSeries(
          anchorDate: DateTime(2026, 9, 2),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          startTimeMinutes: 1440,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('monthlyOrdinal igual a 6 dispara o assert de event_series_ordinal_chk', () {
      expect(
        () => EventSeries(
          anchorDate: DateTime(2026, 9, 2),
          patternGroup: 'variavel',
          variableType: 'dias',
          weekdays: const [7],
          intervalWeeks: 1,
          monthlyOrdinal: 6,
          startTimeMinutes: 600,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('patternLabel delega para describeSeriesPattern (A-13)', () {
      final serie = EventSeries(
        anchorDate: DateTime(2026, 9, 2),
        patternGroup: 'semanal',
        weekdays: const [DateTime.sunday],
        intervalWeeks: 1,
        startTimeMinutes: 600,
      );

      expect(serie.patternLabel, 'Toda semana, domingo');
    });
  });

  group('EventsRepository.getEventSeries', () {
    test('emite GET em /event_series filtrado por id e por tenant_id', () async {
      final spy = _EventSeriesApiSpy();

      await _repoWith(spy).getEventSeries(_batchId);

      expect(spy.gets, hasLength(1));
      final query = Uri.decodeFull(spy.gets.single.toString());
      expect(query, contains('id=eq.$_batchId'));
      expect(query, contains('tenant_id=eq.'));
    });

    test('devolve null para resposta vazia — série legada, não erro (IC-7)', () async {
      final spy = _EventSeriesApiSpy()..seriesRows = '[]';

      final serie = await _repoWith(spy).getEventSeries(_batchId);

      expect(serie, isNull);
    });

    test('desserializa a linha quando a série tem definição salva', () async {
      final spy = _EventSeriesApiSpy()
        ..seriesRows = jsonEncode([
          {
            'id': _batchId,
            'tenant_id': 'tenant-1',
            'anchor_date': '2026-09-02',
            'pattern_group': 'variavel',
            'variable_type': 'quinzenal',
            'weekdays': [1],
            'interval_weeks': 2,
            'monthly_ordinal': null,
            'recurrence_end_date': '2027-03-01',
            'start_time_minutes': 1170,
            'created_at': '2026-09-02T00:00:00.000Z',
            'updated_at': '2026-09-02T00:00:00.000Z',
          },
        ]);

      final serie = await _repoWith(spy).getEventSeries(_batchId);

      expect(serie, isNotNull);
      expect(serie!.patternGroup, 'variavel');
      expect(serie.variableType, 'quinzenal');
      expect(serie.intervalWeeks, 2);
      expect(serie.patternLabel, 'A cada 2 semanas, segunda');
    });
  });

  group('EventsRepository.upsertEventSeries', () {
    test('faz POST em /rpc/upsert_event_series exatamente uma vez', () async {
      final spy = _EventSeriesApiSpy();

      await _upsertPadrao(_repoWith(spy));

      expect(spy.rpcPosts, hasLength(1));
      expect(spy.rpcPosts.single.path, endsWith('/rpc/upsert_event_series'));
    });

    test('o corpo tem EXATAMENTE as 10 chaves p_* da assinatura do servidor', () async {
      final spy = _EventSeriesApiSpy();

      await _upsertPadrao(_repoWith(spy));

      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
    });

    test('NENHUM parâmetro de ator ou de tenant sai do cliente (CHU-326)', () async {
      final spy = _EventSeriesApiSpy();

      await _upsertPadrao(_repoWith(spy));

      final corpo = spy.rpcBodies.single;
      for (final proibida in _chavesDeAtorProibidas) {
        expect(
          corpo.containsKey(proibida),
          isFalse,
          reason:
              'A chave "$proibida" não pode sair do cliente: o ator vem de '
              'auth.uid() e o tenant de current_tenant_id(), dentro da RPC.',
        );
      }
    });

    test('datas viajam como yyyy-MM-dd, não como ISO completo', () async {
      final spy = _EventSeriesApiSpy();

      await _upsertPadrao(_repoWith(spy));

      final corpo = spy.rpcBodies.single;
      expect(corpo['p_anchor_date'], '2026-09-02');
      expect(corpo['p_recurrence_end_date'], '2026-12-31');
    });

    test('recurrenceEndDate nula viaja como null (horizonte padrão de 12 meses)', () async {
      final spy = _EventSeriesApiSpy();

      await _repoWith(spy).upsertEventSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        anchorDate: DateTime(2026, 9, 2),
        patternGroup: 'semanal',
        weekdays: const [DateTime.sunday],
        intervalWeeks: 1,
        startTimeMinutes: 600,
      );

      final corpo = spy.rpcBodies.single;
      expect(corpo.containsKey('p_recurrence_end_date'), isTrue);
      expect(corpo['p_recurrence_end_date'], isNull);
      expect(corpo['p_variable_type'], isNull);
      expect(corpo['p_monthly_ordinal'], isNull);
    });

    test('relança quando o servidor responde 42501/PERMISSION_DENIED', () async {
      final spy = _EventSeriesApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        _upsertPadrao(_repoWith(spy)),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
