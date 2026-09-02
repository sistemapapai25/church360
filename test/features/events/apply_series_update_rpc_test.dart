// Fase 6 — REC-02 (Plano 06-06). O lado cliente de
// `public.apply_event_series_update` (migration `20260902000600`), nos dois
// modos: prévia (`p_dry_run: true`) e execução (`p_dry_run: false`).
//
// **Este é o primeiro caller real daquela RPC em toda a história do projeto —
// e o corpo dela nunca executou em nenhum ambiente** (ver `06-05-SUMMARY.md`).
// Estes testes são `MockClient` sobre o PostgREST: travam a FORMA da chamada e
// a desserialização, NUNCA o servidor. Nada aqui prova que a RPC funciona.
//
// O que eles travam:
//   1. a forma — path `/rpc/apply_event_series_update`, EXATAMENTE as 5
//      chaves da assinatura e assertiva explícita de que nenhum parâmetro de
//      ator sai do cliente (regressão CHU-326: ator vem de `auth.uid()` e
//      tenant de `current_tenant_id()`, dentro do servidor);
//   2. que `p_fields` viaja como o mapa `data` do formulário, inteiro e sem
//      filtro local — é isso que torna D-03 verdadeiro sem lista fixa na UI;
//   3. que `p_start_time_minutes` viaja NULO quando o horário não mudou
//      (Pitfall #6: reescrever a hora de dezenas de linhas dispara
//      `event_changed_notify_upd` uma vez por linha, à toa);
//   4. que `updated_count` é lido do jsonb da EXECUÇÃO — é ele, não a
//      contagem da prévia, que o SnackBar de sucesso informa;
//   5. que `42501` PROPAGA nos dois modos, nunca vira sucesso silencioso.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';

const _batchId = '22222222-0000-4000-8000-000000000002';
const _anchorEventId = '11111111-0000-4000-8000-000000000001';

/// As 5 chaves da assinatura do servidor. Nenhuma a mais, nenhuma a menos.
const _chavesEsperadas = <String>{
  'p_batch_id',
  'p_anchor_event_id',
  'p_fields',
  'p_start_time_minutes',
  'p_dry_run',
};

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

/// Recorte do mapa `data` que `_saveEvent` monta — inclusive as chaves que o
/// servidor tem na própria lista de exclusão. O cliente não filtra nada.
const _fields = <String, dynamic>{
  'name': 'Culto de Domingo',
  'description': null,
  'event_type': 'culto_normal',
  'start_date': '2026-09-06T19:30:00.000',
  'end_date': null,
  'location': 'Templo novo',
  'max_capacity': 200,
  'requires_registration': false,
  'is_mandatory': false,
  'status': 'published',
  'image_url': null,
  'visibility_scope': 'all',
  'registration_scope': 'all',
};

const _jsonbPrevia = <String, dynamic>{
  'dry_run': true,
  'future_count': 14,
  'past_count': 3,
  'first_future': '2026-09-06',
  'last_future': '2026-12-13',
  'affected_registrations': 5,
  'affected_schedules': 2,
  'updated_count': 0,
};

class _ApplySeriesApiSpy {
  final List<Uri> rpcPosts = [];
  final List<Map<String, dynamic>> rpcBodies = [];

  Map<String, dynamic> response = Map<String, dynamic>.from(_jsonbPrevia);
  bool failWithPermissionDenied = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/apply_event_series_update') &&
        request.method == 'POST') {
      rpcPosts.add(request.url);
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (failWithPermissionDenied) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message':
                'permission denied for function apply_event_series_update',
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

EventsRepository _repoWith(_ApplySeriesApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

void main() {
  group('previewSeriesUpdate / applySeriesUpdate — forma da chamada', () {
    test('a prévia envia p_dry_run: true e EXATAMENTE as 5 chaves', () async {
      final spy = _ApplySeriesApiSpy();

      await _repoWith(spy).previewSeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );

      expect(
        spy.rpcPosts.single.path,
        endsWith('/rpc/apply_event_series_update'),
      );
      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_batch_id'], _batchId);
      expect(spy.rpcBodies.single['p_anchor_event_id'], _anchorEventId);
      expect(spy.rpcBodies.single['p_dry_run'], isTrue);
    });

    test('a execução envia a MESMA chamada com p_dry_run: false', () async {
      final spy = _ApplySeriesApiSpy()
        ..response = {..._jsonbPrevia, 'dry_run': false, 'updated_count': 14};

      final impacto = await _repoWith(spy).applySeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );

      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_dry_run'], isFalse);
      // O SnackBar de sucesso usa ESTE número, não o da prévia.
      expect(impacto.updatedCount, 14);
      expect(impacto.dryRun, isFalse);
    });

    test('D-03: p_fields viaja inteiro, sem filtro local de chaves', () async {
      final spy = _ApplySeriesApiSpy();

      await _repoWith(spy).previewSeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );

      final enviado = Map<String, dynamic>.from(
        spy.rpcBodies.single['p_fields'] as Map,
      );
      expect(enviado.keys.toSet(), _fields.keys.toSet());
      expect(enviado['location'], 'Templo novo');
      // Chaves da lista de EXCLUSÃO do servidor saem daqui do mesmo jeito: a
      // decisão de ignorá-las é do servidor, e o cliente não replica a regra.
      expect(enviado.containsKey('start_date'), isTrue);
      expect(enviado.containsKey('status'), isTrue);
    });

    test('p_start_time_minutes viaja nulo quando o horário não mudou', () async {
      final spy = _ApplySeriesApiSpy();

      await _repoWith(spy).previewSeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );

      expect(spy.rpcBodies.single.containsKey('p_start_time_minutes'), isTrue);
      expect(spy.rpcBodies.single['p_start_time_minutes'], isNull);
    });

    test('p_start_time_minutes viaja em MINUTOS quando informado', () async {
      final spy = _ApplySeriesApiSpy();

      await _repoWith(spy).applySeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
        startTimeMinutes: 20 * 60 + 15,
      );

      expect(spy.rpcBodies.single['p_start_time_minutes'], 1215);
    });

    test('nenhum dos dois modos envia parâmetro de ator ou de tenant', () async {
      final spy = _ApplySeriesApiSpy();
      final repo = _repoWith(spy);

      await repo.previewSeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );
      await repo.applySeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
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
      final spy = _ApplySeriesApiSpy();

      await _repoWith(spy).previewSeriesUpdate(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        fields: _fields,
      );

      expect(spy.rpcPosts, hasLength(1));
    });
  });

  group('propagação de erro', () {
    test('42501 PROPAGA na prévia — o diálogo não pode abrir', () async {
      final spy = _ApplySeriesApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        () => _repoWith(spy).previewSeriesUpdate(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
          fields: _fields,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('42501 PROPAGA na execução — nunca vira sucesso silencioso', () async {
      // Se a recusa virasse `updated_count: 0`, a UI diria "Alterações
      // aplicadas a 0 ocorrências futuras" como se tivesse dado certo.
      final spy = _ApplySeriesApiSpy()..failWithPermissionDenied = true;

      await expectLater(
        () => _repoWith(spy).applySeriesUpdate(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
          fields: _fields,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
