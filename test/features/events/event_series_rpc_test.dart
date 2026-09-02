// Fase 6 — REC-05 (Plano 06-04). O lado cliente da RPC destrutiva
// `public.delete_event_series_future` (migration `20260902000500`), nos dois
// modos: prévia (`p_dry_run: true`) e execução (`p_dry_run: false`).
//
// Estes testes travam TRÊS coisas:
//   1. a forma da chamada — path `/rpc/delete_event_series_future`, aridade 3,
//      exatamente as chaves `p_batch_id`/`p_anchor_event_id`/`p_dry_run` e
//      assertiva EXPLÍCITA de que NENHUM parâmetro de ator sai do cliente. É a
//      regressão CHU-326: o ator vem de `auth.uid()` e o tenant de
//      `current_tenant_id()`, DENTRO do servidor;
//   2. que a desserialização não inventa número — `EventSeriesImpact.fromJson`
//      lê o `jsonb` real devolvido pelo servidor, chave por chave, e tolera
//      `first_future`/`last_future` nulos (série sem ocorrência futura). A
//      contagem exibida no diálogo DLG-5 vem daqui e de nenhum cálculo local
//      (A-04 do `06-UI-SPEC.md`);
//   3. que `42501` PROPAGA em vez de virar sucesso silencioso. Não existe
//      default fail-closed que transforme recusa de EXECUTE em "deu certo" —
//      uma exclusão em massa que a UI reporta como concluída sem ter
//      acontecido é pior do que um erro na tela.
//
// Espião `MockClient` sobre o PostgREST real, sem mock de repositório — mesmo
// molde de `event_access_status_rpc_test.dart` e `event_series_repository_test.dart`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_series_impact.dart';
import 'package:church360_app/features/events/presentation/utils/series_error.dart';

const _batchId = '22222222-0000-4000-8000-000000000002';
const _anchorEventId = '11111111-0000-4000-8000-000000000001';

/// As 3 chaves da assinatura de `public.delete_event_series_future`, na ordem
/// do servidor. Nenhuma a mais, nenhuma a menos.
const _chavesEsperadas = <String>{
  'p_batch_id',
  'p_anchor_event_id',
  'p_dry_run',
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

/// `jsonb` de prévia devolvido pelo servidor, com as 9 chaves do contrato.
const _jsonbPrevia = <String, dynamic>{
  'dry_run': true,
  'future_count': 14,
  'past_count': 3,
  'first_future': '2026-09-03',
  'last_future': '2026-12-10',
  'affected_registrations': 5,
  'affected_schedules': 2,
  'deleted_count': 0,
  'notified_count': 0,
};

class _DeleteSeriesApiSpy {
  final List<Uri> rpcPosts = [];
  final List<Map<String, dynamic>> rpcBodies = [];

  /// `jsonb` que a RPC devolve quando não está configurada para falhar.
  Map<String, dynamic> response = Map<String, dynamic>.from(_jsonbPrevia);

  /// Quando verdadeiro, a RPC responde o `42501` que o PostgREST emite quando
  /// a guarda de responsável/permissão dentro da função levanta
  /// `PERMISSION_DENIED`.
  bool failWithPermissionDenied = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/delete_event_series_future') &&
        request.method == 'POST') {
      rpcPosts.add(request.url);
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (failWithPermissionDenied) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for function '
                'delete_event_series_future',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: headers,
        );
      }

      return http.Response(
        jsonEncode(response),
        200,
        request: request,
        headers: headers,
      );
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_DeleteSeriesApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

PostgrestException _erro({
  String? code,
  String message = 'erro',
  String? details,
  String? hint,
}) =>
    PostgrestException(
      message: message,
      code: code,
      details: details,
      hint: hint,
    );

void main() {
  group('seriesErrorMessage — detecção nos 4 campos do PostgrestException', () {
    const copyPermissao =
        'Você não é o responsável por este evento. Peça ao responsável ou ao '
        'Pastor Senior para alterar a série.';

    test('reconhece PERMISSION_DENIED vindo em `code`', () {
      expect(
        seriesErrorMessage(_erro(code: seriesPermissionDeniedCode)),
        copyPermissao,
      );
    });

    test('reconhece PERMISSION_DENIED vindo em `message`', () {
      expect(
        seriesErrorMessage(
          _erro(message: 'PERMISSION_DENIED', code: 'P0001'),
        ),
        copyPermissao,
      );
    });

    test('reconhece PERMISSION_DENIED vindo em `details`', () {
      expect(
        seriesErrorMessage(
          _erro(code: 'P0001', details: 'PERMISSION_DENIED'),
        ),
        copyPermissao,
      );
    });

    test('reconhece PERMISSION_DENIED vindo em `hint`', () {
      expect(
        seriesErrorMessage(_erro(code: 'P0001', hint: 'PERMISSION_DENIED')),
        copyPermissao,
      );
    });

    test('trata 42501 como sinônimo de PERMISSION_DENIED', () {
      // Recusa de EXECUTE pelo PostgREST: o literal do RAISE nunca chega,
      // mas para o líder é exatamente a mesma situação.
      expect(
        seriesErrorMessage(
          _erro(
            code: '42501',
            message: 'permission denied for function '
                'delete_event_series_future',
          ),
        ),
        copyPermissao,
      );
    });

    test('reconhece TENANT_ID_NOT_FOUND e SERIES_NOT_FOUND', () {
      expect(
        seriesErrorMessage(_erro(message: seriesTenantNotFoundCode)),
        'Não foi possível identificar a igreja ativa. Saia e entre de novo '
        'no app.',
      );
      expect(
        seriesErrorMessage(_erro(message: seriesNotFoundCode)),
        'Não encontramos os dados desta série. Recarregue a tela e tente de '
        'novo.',
      );
    });

    test('devolve null para erro desconhecido — quem decide é AppErrorHandler',
        () {
      expect(seriesErrorMessage(_erro(code: '23505', message: 'duplicate')),
          isNull);
      expect(seriesErrorMessage(Exception('falha de rede')), isNull);
    });
  });

  group('EventSeriesImpact.fromJson', () {
    test('lê as 9 chaves snake_case do jsonb do servidor', () {
      final impacto = EventSeriesImpact.fromJson(_jsonbPrevia);

      expect(impacto.dryRun, isTrue);
      expect(impacto.futureCount, 14);
      expect(impacto.pastCount, 3);
      expect(impacto.firstFuture, DateTime(2026, 9, 3));
      expect(impacto.lastFuture, DateTime(2026, 12, 10));
      expect(impacto.affectedRegistrations, 5);
      expect(impacto.affectedSchedules, 2);
      expect(impacto.deletedCount, 0);
      expect(impacto.notifiedCount, 0);
    });

    test('tolera first_future/last_future nulos — série sem futuras', () {
      final impacto = EventSeriesImpact.fromJson(const {
        'dry_run': true,
        'future_count': 0,
        'past_count': 7,
        'first_future': null,
        'last_future': null,
        'affected_registrations': 0,
        'affected_schedules': 0,
        'deleted_count': 0,
        'notified_count': 0,
      });

      expect(impacto.futureCount, 0);
      expect(impacto.pastCount, 7);
      expect(impacto.firstFuture, isNull);
      expect(impacto.lastFuture, isNull);
    });

    test('chave ausente vira 0, nunca null nem exceção', () {
      final impacto = EventSeriesImpact.fromJson(const {'future_count': 2});

      expect(impacto.futureCount, 2);
      expect(impacto.pastCount, 0);
      expect(impacto.deletedCount, 0);
      expect(impacto.createdCount, 0);
      expect(impacto.dryRun, isFalse);
    });
  });

  group('previewDeleteSeriesFuture / deleteEventSeriesFuture', () {
    test('a prévia envia p_dry_run: true e EXATAMENTE as 3 chaves', () async {
      final spy = _DeleteSeriesApiSpy();

      await _repoWith(spy).previewDeleteSeriesFuture(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
      );

      expect(
        spy.rpcPosts.single.path,
        endsWith('/rpc/delete_event_series_future'),
      );
      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_batch_id'], _batchId);
      expect(spy.rpcBodies.single['p_anchor_event_id'], _anchorEventId);
      expect(spy.rpcBodies.single['p_dry_run'], isTrue);
    });

    test('a execução envia a MESMA chamada com p_dry_run: false', () async {
      final spy = _DeleteSeriesApiSpy()
        ..response = {
          ..._jsonbPrevia,
          'dry_run': false,
          'deleted_count': 14,
          'notified_count': 5,
        };

      final impacto = await _repoWith(spy).deleteEventSeriesFuture(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
      );

      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_dry_run'], isFalse);
      // O SnackBar de sucesso usa ESTE número, não o da prévia.
      expect(impacto.deletedCount, 14);
      expect(impacto.dryRun, isFalse);
    });

    test('nenhuma das duas envia parâmetro de ator ou de tenant', () async {
      final spy = _DeleteSeriesApiSpy();
      final repo = _repoWith(spy);

      await repo.previewDeleteSeriesFuture(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
      );
      await repo.deleteEventSeriesFuture(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
      );

      for (final body in spy.rpcBodies) {
        for (final proibida in _chavesDeAtorProibidas) {
          expect(
            body.containsKey(proibida),
            isFalse,
            reason: 'CHU-326: `$proibida` não pode sair do cliente',
          );
        }
      }
    });

    test('cada invocação faz EXATAMENTE uma chamada', () async {
      final spy = _DeleteSeriesApiSpy();

      await _repoWith(spy).previewDeleteSeriesFuture(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
      );

      expect(spy.rpcPosts, hasLength(1));
    });

    test('42501 PROPAGA na prévia — nunca vira impacto vazio', () async {
      final spy = _DeleteSeriesApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        () => _repoWith(spy).previewDeleteSeriesFuture(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('42501 PROPAGA na execução — nunca vira sucesso silencioso', () async {
      // Se a recusa virasse `deleted_count: 0`, a UI diria "0 ocorrências
      // futuras excluídas" como se tivesse dado certo.
      final spy = _DeleteSeriesApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        () => _repoWith(spy).deleteEventSeriesFuture(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
