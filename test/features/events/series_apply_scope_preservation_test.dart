// Bug `serie-visibilidade-rebaixada` (debug session). A ORDEM e o ABORTO do
// ramo "Aplicar a toda a série" (`_aplicarEdicaoATodaASerie`).
//
// O bug: o ramo repassava o mapa `data` intacto para
// `apply_event_series_update` e nunca chamava `_persistAudienceAndScopes`.
// Como `visibility_scope`/`registration_scope` NÃO estão na `c_excluded` da
// migration `20260902000600` (linhas 158-163) e o passo (7) é deny-list, o
// literal `'all'` era gravado em TODAS as ocorrências futuras do lote —
// inclusive na âncora, que o `WHERE` não poupa. E `'all'` é o primeiro termo do
// `USING` de `event_visibility_restrict` (`20260826000400:104-111`), o
// curto-circuito que libera a linha sem consultar `event_audience`: a série
// restrita inteira virava legível por qualquer autenticado do tenant, em
// silêncio. Confirmado em produção (batch `fd8a5303`, 26/26 ocorrências).
//
// O que este arquivo trava, nesta ordem de importância:
//   1. o `p_fields` carrega o escopo REAL do formulário, nunca o `'all'`
//      hardcoded — a regressão de exposição;
//   2. a audiência/lembretes da ÂNCORA são gravados ANTES da RPC. O passo (9)
//      replica a audiência DA ÂNCORA para o lote: gravá-la depois propagaria os
//      alvos antigos e descartaria em silêncio o que o líder editou;
//   3. se a gravação da âncora falhar, a RPC NÃO é chamada. Sem esse aborto,
//      `'restricted'` iria para dezenas de ocorrências cuja fonte de alvos
//      falhou — evento restrito sem alvo é invisível para TODOS (Pitfall 6),
//      que é o modo de falha oposto e pior que o bug original.
//
// Como no `event_form_audience_order_test.dart`, o widget completo não é
// testável sem Supabase inicializado: o valor aqui é provar a SEQUÊNCIA de
// requests exercitando o repositório na mesma ordem que a tela usa. A metade
// que NÃO é espelho é `seriesUpdateFields`, o símbolo de produção importado
// abaixo — é ele que monta o `p_fields` na tela e aqui.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_audience.dart';
import 'package:church360_app/features/events/domain/models/event_reminder.dart';
import 'package:church360_app/features/events/presentation/utils/series_update_fields.dart';

const _anchorEventId = '11111111-0000-4000-8000-000000000001';
const _batchId = '22222222-0000-4000-8000-000000000002';
const _ministryId = '44444444-0000-4000-8000-000000000004';
const _roleId = '55555555-0000-4000-8000-000000000005';

/// Recorte do mapa `data` de `_saveEvent`, com os dois literais de escopo que
/// o Pitfall 1 obriga na construção.
const _data = <String, dynamic>{
  'name': 'Culto de Domingo',
  'description': null,
  'event_type': 'culto_normal',
  'start_date': '2026-09-06T19:30:00.000',
  'requires_registration': true,
  'status': 'published',
  'visibility_scope': 'all',
  'registration_scope': 'all',
};

const _jsonbExecucao = <String, dynamic>{
  'dry_run': false,
  'future_count': 14,
  'past_count': 3,
  'first_future': '2026-09-06',
  'last_future': '2026-12-13',
  'affected_registrations': 5,
  'affected_schedules': 2,
  'updated_count': 14,
};

class _LoggedRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  _LoggedRequest(this.method, this.path, this.body);

  bool get isAudience => path.endsWith('/event_audience');
  bool get isReminder => path.endsWith('/event_reminder');
  bool get isRpc => path.endsWith('/rpc/apply_event_series_update');
  bool get isScopePatch => path.endsWith('/event') && method == 'PATCH';
}

/// Spy que registra TODA requisição numa única lista ordenada — é a ordem entre
/// elas que os testes afirmam, não a ocorrência isolada de cada uma.
class _SeriesSaveSpy {
  final List<_LoggedRequest> log = [];

  /// Simula falha na gravação dos alvos da âncora (comportamento #3).
  bool failAudience = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // DELETE não tem corpo: fica null, sem problema.
    }

    log.add(_LoggedRequest(request.method, request.url.path, body));

    if (request.url.path.endsWith('/rpc/apply_event_series_update')) {
      return http.Response(
        jsonEncode(_jsonbExecucao),
        200,
        request: request,
        headers: headers,
      );
    }

    if (request.url.path.endsWith('/event_audience')) {
      if (failAudience) {
        return http.Response(
          jsonEncode({
            'code': '500',
            'message': 'falha simulada na gravação da audiência',
            'details': null,
            'hint': null,
          }),
          500,
          request: request,
          headers: headers,
        );
      }
      return http.Response(
        request.method == 'DELETE' ? '[]' : request.body,
        request.method == 'POST' ? 201 : 200,
        request: request,
        headers: headers,
      );
    }

    if (request.url.path.endsWith('/event')) {
      return http.Response(
        jsonEncode({
          'id': _anchorEventId,
          'name': 'Culto de Domingo',
          'start_date': '2026-09-06T19:30:00.000Z',
          'created_at': '2026-09-01T12:00:00.000Z',
          'visibility_scope': body?['visibility_scope'] ?? 'all',
          'registration_scope': body?['registration_scope'] ?? 'all',
        }),
        200,
        request: request,
        headers: headers,
      );
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_SeriesSaveSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

/// Espelha `_persistAudienceAndScopes` DEPOIS da correção: mesma sequência
/// (3 papéis -> lembretes -> PATCH de escopo condicional) e o mesmo retorno
/// booleano, que é o que torna o aborto do chamador possível.
Future<bool> _persistAudienceAndScopes(
  EventsRepository repo, {
  required String visibilityScope,
  required String registrationScope,
  required List<EventAudience> responsibles,
  required List<EventAudience> visibilityTargets,
  required List<EventAudience> registrationTargets,
  required List<EventReminder> reminders,
}) async {
  try {
    await repo.setEventAudience(_anchorEventId, 'responsible', responsibles);
    await repo.setEventAudience(
      _anchorEventId,
      'visibility',
      visibilityScope == 'restricted' ? visibilityTargets : const [],
    );
    await repo.setEventAudience(
      _anchorEventId,
      'registration',
      registrationScope == 'restricted' ? registrationTargets : const [],
    );
    await repo.setEventReminders(_anchorEventId, reminders);

    if (visibilityScope != 'all' || registrationScope != 'all') {
      await repo.updateEvent(_anchorEventId, {
        'visibility_scope': visibilityScope,
        'registration_scope': registrationScope,
      });
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Espelha o `onConfirm` de `_aplicarEdicaoATodaASerie` depois da correção:
/// âncora primeiro, aborto se ela falhar, e só então a RPC com o escopo real.
/// Devolve `true` quando a RPC chegou a ser chamada.
Future<bool> _confirmarAplicacaoNaSerie(
  EventsRepository repo, {
  required String visibilityScope,
  required String registrationScope,
  List<EventAudience> responsibles = const [],
  List<EventAudience> visibilityTargets = const [],
  List<EventAudience> registrationTargets = const [],
  List<EventReminder> reminders = const [],
}) async {
  final ancoraOk = await _persistAudienceAndScopes(
    repo,
    visibilityScope: visibilityScope,
    registrationScope: registrationScope,
    responsibles: responsibles,
    visibilityTargets: visibilityTargets,
    registrationTargets: registrationTargets,
    reminders: reminders,
  );
  if (!ancoraOk) return false;

  await repo.applySeriesUpdate(
    batchId: _batchId,
    anchorEventId: _anchorEventId,
    fields: seriesUpdateFields(
      base: _data,
      visibilityScope: visibilityScope,
      registrationScope: registrationScope,
    ),
  );
  return true;
}

List<EventAudience> get _alvosDeVisibilidade => [
  EventAudience(
    eventId: _anchorEventId,
    role: 'visibility',
    ministryId: _ministryId,
  ),
];

List<EventAudience> get _alvosDeInscricao => [
  EventAudience(
    eventId: _anchorEventId,
    role: 'registration',
    rbacRoleId: _roleId,
  ),
];

void main() {
  group('escopo real no p_fields', () {
    test(
      'p_fields carrega "restricted", nunca o "all" hardcoded do mapa data',
      () async {
        final spy = _SeriesSaveSpy();

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'restricted',
          visibilityTargets: _alvosDeVisibilidade,
          registrationTargets: _alvosDeInscricao,
        );

        final rpc = spy.log.singleWhere((r) => r.isRpc);
        final campos = Map<String, dynamic>.from(
          rpc.body!['p_fields'] as Map,
        );
        expect(campos['visibility_scope'], 'restricted');
        expect(campos['registration_scope'], 'restricted');
      },
    );

    test('série aberta continua mandando "all" — nada é inventado', () async {
      final spy = _SeriesSaveSpy();

      await _confirmarAplicacaoNaSerie(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      final rpc = spy.log.singleWhere((r) => r.isRpc);
      final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
      expect(campos['visibility_scope'], 'all');
      expect(campos['registration_scope'], 'all');
    });

    test(
      'restrição só de visibilidade não fecha a inscrição junto no lote',
      () async {
        final spy = _SeriesSaveSpy();

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'all',
          visibilityTargets: _alvosDeVisibilidade,
        );

        final rpc = spy.log.singleWhere((r) => r.isRpc);
        final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
        expect(campos['visibility_scope'], 'restricted');
        expect(campos['registration_scope'], 'all');
      },
    );

    test('os campos comuns continuam viajando inteiros (D-03)', () async {
      final spy = _SeriesSaveSpy();

      await _confirmarAplicacaoNaSerie(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: _alvosDeVisibilidade,
      );

      final rpc = spy.log.singleWhere((r) => r.isRpc);
      final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
      expect(campos.keys.toSet(), _data.keys.toSet());
      expect(campos['name'], 'Culto de Domingo');
      expect(campos['event_type'], 'culto_normal');
      expect(campos.containsKey('start_date'), isTrue);
    });
  });

  group('ordem: âncora antes da RPC', () {
    test(
      'toda gravação de audiência da âncora acontece ANTES da RPC',
      () async {
        final spy = _SeriesSaveSpy();

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'restricted',
          responsibles: [
            EventAudience(
              eventId: _anchorEventId,
              role: 'responsible',
              ministryId: _ministryId,
            ),
          ],
          visibilityTargets: _alvosDeVisibilidade,
          registrationTargets: _alvosDeInscricao,
        );

        final rpcIndex = spy.log.indexWhere((r) => r.isRpc);
        final audienceIndices = [
          for (var i = 0; i < spy.log.length; i++)
            if (spy.log[i].isAudience) i,
        ];

        expect(rpcIndex, isNonNegative);
        expect(audienceIndices, isNotEmpty);
        expect(
          audienceIndices.every((i) => i < rpcIndex),
          isTrue,
          reason:
              'o passo (9) da RPC replica a audiência DA ÂNCORA: gravá-la '
              'depois propagaria os alvos antigos para o lote inteiro',
        );
      },
    );

    test('os lembretes da âncora também são gravados antes da RPC', () async {
      final spy = _SeriesSaveSpy();

      await _confirmarAplicacaoNaSerie(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
        reminders: [
          EventReminder(eventId: _anchorEventId, offsetMinutes: 60),
        ],
      );

      final rpcIndex = spy.log.indexWhere((r) => r.isRpc);
      final reminderIndices = [
        for (var i = 0; i < spy.log.length; i++)
          if (spy.log[i].isReminder) i,
      ];

      expect(reminderIndices, isNotEmpty);
      expect(reminderIndices.every((i) => i < rpcIndex), isTrue);
    });

    test(
      'o PATCH de escopo da âncora vem depois dos alvos e antes da RPC',
      () async {
        final spy = _SeriesSaveSpy();

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'restricted',
          visibilityTargets: _alvosDeVisibilidade,
          registrationTargets: _alvosDeInscricao,
        );

        final patchIndex = spy.log.indexWhere((r) => r.isScopePatch);
        final ultimoAlvo = spy.log.lastIndexWhere((r) => r.isAudience);
        final rpcIndex = spy.log.indexWhere((r) => r.isRpc);

        expect(patchIndex, isNonNegative);
        expect(
          patchIndex > ultimoAlvo,
          isTrue,
          reason:
              'Pitfall 1: a promoção de escopo é um UPDATE ... RETURNING e só '
              'pode rodar depois que a audiência existe',
        );
        expect(patchIndex < rpcIndex, isTrue);
      },
    );

    test(
      'com os dois escopos em "all" nenhum PATCH extra de escopo é emitido',
      () async {
        final spy = _SeriesSaveSpy();

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'all',
          registrationScope: 'all',
        );

        expect(spy.log.where((r) => r.isScopePatch), isEmpty);
        expect(spy.log.where((r) => r.isRpc), hasLength(1));
      },
    );
  });

  group('aborto quando a âncora falha', () {
    test(
      'audiência falhou -> a RPC NÃO é chamada (nenhuma ocorrência é tocada)',
      () async {
        final spy = _SeriesSaveSpy()..failAudience = true;

        final chamouRpc = await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'restricted',
          visibilityTargets: _alvosDeVisibilidade,
          registrationTargets: _alvosDeInscricao,
        );

        expect(chamouRpc, isFalse);
        expect(
          spy.log.where((r) => r.isRpc),
          isEmpty,
          reason:
              'mandar "restricted" para o lote com a fonte de alvos quebrada '
              'deixaria dezenas de ocorrências restritas SEM alvo — '
              'invisíveis para todos (Pitfall 6)',
        );
      },
    );

    test(
      'audiência falhou -> nem o PATCH de escopo da âncora é emitido',
      () async {
        final spy = _SeriesSaveSpy()..failAudience = true;

        await _confirmarAplicacaoNaSerie(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'all',
          visibilityTargets: _alvosDeVisibilidade,
        );

        expect(spy.log.where((r) => r.isScopePatch), isEmpty);
      },
    );
  });
}
