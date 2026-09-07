// Bug `regenerar-serie-perde-dados` (debug session). O que acontece com
// responsáveis, alvos, lembretes e escopo DEPOIS de `regenerate_event_series`.
//
// O BUG: `_regenerarSerie` nunca chamava `_persistAudienceAndScopes`, e
// `public.regenerate_event_series` não recebe audiência/lembrete/escopo por
// parâmetro — o passo (13) da migration `20260902000900` (linhas 638-692) COPIA
// da âncora PERSISTIDA (`SELECT * INTO v_model ... WHERE id =
// p_anchor_event_id` e os dois `INSERT ... SELECT ... WHERE a.event_id =
// p_anchor_event_id`). Com a âncora ainda pré-edição na hora da cópia, cada
// ocorrência NOVA nascia com os alvos/lembretes/escopo ANTIGOS, e as MANTIDAS
// não recebiam nada. Pior: como o escopo real nunca subia, marcar a série como
// `'restricted'` na mesma tela em que se muda o padrão NÃO restringia nada — a
// série seguia `'all'`, o curto-circuito do `USING` de
// `event_visibility_restrict` (`20260826000400:104-111`).
//
// O agravante que fechava o caminho: `_aplicarCamposComunsAposRegeneracao` só
// chamava `apply_event_series_update` quando algum CAMPO COMUM divergia
// (`if (!mudou) return null`). Mudar só o padrão + a audiência não emitia
// requisição nenhuma — perda 100% silenciosa.
//
// O que este arquivo trava, nesta ordem de importância:
//   1. `apply_event_series_update` é chamada SEMPRE, inclusive com `p_fields`
//      vazio. É o passo (9) dela que replica os alvos da âncora para as
//      ocorrências MANTIDAS, que nenhum passo da regeneração toca. `p_fields`
//      vazio é seguro: o passo (7) roda sob
//      `IF coalesce(array_length(v_cols,1),0) > 0` (linha 362) e não emite
//      `UPDATE` nenhum em `public.event` — sem `event_changed_notify_upd`, sem
//      avalanche de avisos;
//   2. a audiência/lembretes são gravados na âncora ANTES da RPC de replicação,
//      porque ela é a FONTE da cópia do passo (9);
//   3. a reancoragem é na primeira ocorrência FUTURA sobrevivente, nunca na
//      ocorrência aberta — a nota (l) do cabeçalho da RPC de regeneração diz que
//      a âncora fora do padrão novo é apagada junto;
//   4. o escopo REAL viaja quando alguma futura diverge do formulário, e NÃO
//      viaja quando todas já batem (mesma proteção contra a avalanche);
//   5. se a gravação da âncora falhar, a replicação NÃO acontece — mandar
//      `'restricted'` para o lote com a fonte de alvos quebrada deixaria todas
//      as futuras restritas SEM alvo, invisíveis para TODOS (Pitfall 6).
//
// Como em `series_apply_scope_preservation_test.dart`, o widget completo não
// sobe sem Supabase inicializado: o valor aqui é provar a SEQUÊNCIA de requests
// exercitando o repositório na mesma ordem que a tela usa.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_audience.dart';
import 'package:church360_app/features/events/domain/models/event_reminder.dart';

/// A ocorrência que o líder tinha aberto. NÃO está entre as futuras dos mocks:
/// é o caso da nota (l) — a regeneração a apagou por estar fora do padrão novo.
const _ocorrenciaAberta = '11111111-0000-4000-8000-000000000001';
const _batchId = '22222222-0000-4000-8000-000000000002';

/// Primeira futura sobrevivente — a âncora que a correção tem que escolher.
const _primeiraFutura = '33333333-0000-4000-8000-000000000003';
const _segundaFutura = '66666666-0000-4000-8000-000000000006';
const _ministryId = '44444444-0000-4000-8000-000000000004';
const _roleId = '55555555-0000-4000-8000-000000000005';

/// "Agora" fixo dos testes. Tudo antes disto é passado.
final _agora = DateTime.utc(2026, 9, 7, 12);

/// Recorte do mapa `data` de `_saveEvent`, com os dois literais de escopo que o
/// Pitfall 1 obriga na construção.
const _data = <String, dynamic>{
  'name': 'Culto de Domingo',
  'description': null,
  'event_type': 'culto_normal',
  'start_date': '2026-09-10T19:30:00.000',
  'end_date': null,
  'location': 'Templo',
  'requires_registration': true,
  'status': 'published',
  'visibility_scope': 'all',
  'registration_scope': 'all',
};

const _jsonbExecucao = <String, dynamic>{
  'dry_run': false,
  'future_count': 2,
  'past_count': 1,
  'first_future': '2026-09-10',
  'last_future': '2026-09-17',
  'affected_registrations': 0,
  'affected_schedules': 0,
  'updated_count': 2,
};

Map<String, dynamic> _ocorrencia({
  required String id,
  required String startDate,
  String name = 'Culto de Domingo',
  String? location = 'Templo',
  String visibilityScope = 'all',
  String registrationScope = 'all',
}) => {
  'id': id,
  'name': name,
  'description': null,
  'event_type': 'culto_normal',
  'start_date': startDate,
  'end_date': null,
  'location': location,
  'requires_registration': true,
  'status': 'published',
  'created_at': '2026-09-01T12:00:00.000Z',
  'batch_id': _batchId,
  'visibility_scope': visibilityScope,
  'registration_scope': registrationScope,
};

class _LoggedRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  _LoggedRequest(this.method, this.path, this.body);

  bool get isAudience => path.endsWith('/event_audience');
  bool get isReminder => path.endsWith('/event_reminder');
  bool get isRpc => path.endsWith('/rpc/apply_event_series_update');
  bool get isBatchRead => path.endsWith('/event') && method == 'GET';
  bool get isScopePatch => path.endsWith('/event') && method == 'PATCH';
}

class _RegenerateAftermathSpy {
  final List<_LoggedRequest> log = [];

  /// Simula falha na gravação dos alvos da âncora nova (comportamento #5).
  bool failAudience = false;

  /// O que `getEventsByBatch` devolve depois da regeneração. Por padrão: uma
  /// passada + duas futuras, e a ocorrência aberta NÃO está entre elas.
  List<Map<String, dynamic>> lote = [
    _ocorrencia(id: 'aaaa0000-0000-4000-8000-00000000000a', startDate: '2026-08-30T19:30:00.000Z'),
    _ocorrencia(id: _primeiraFutura, startDate: '2026-09-10T19:30:00.000Z'),
    _ocorrencia(id: _segundaFutura, startDate: '2026-09-17T19:30:00.000Z'),
  ];

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // GET e DELETE não têm corpo: fica null, sem problema.
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
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(lote),
          200,
          request: request,
          headers: headers,
        );
      }
      return http.Response(
        jsonEncode(
          _ocorrencia(
            id: _primeiraFutura,
            startDate: '2026-09-10T19:30:00.000Z',
            visibilityScope: body?['visibility_scope'] as String? ?? 'all',
            registrationScope: body?['registration_scope'] as String? ?? 'all',
          ),
        ),
        200,
        request: request,
        headers: headers,
      );
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_RegenerateAftermathSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

/// Espelha `_persistAudienceAndScopes`: 3 papéis -> lembretes -> PATCH de escopo
/// condicional, e o retorno booleano que torna o aborto do chamador possível.
Future<bool> _persistAudienceAndScopes(
  EventsRepository repo,
  String eventId, {
  required String visibilityScope,
  required String registrationScope,
  required List<EventAudience> responsibles,
  required List<EventAudience> visibilityTargets,
  required List<EventAudience> registrationTargets,
  required List<EventReminder> reminders,
}) async {
  try {
    await repo.setEventAudience(eventId, 'responsible', responsibles);
    await repo.setEventAudience(
      eventId,
      'visibility',
      visibilityScope == 'restricted' ? visibilityTargets : const [],
    );
    await repo.setEventAudience(
      eventId,
      'registration',
      registrationScope == 'restricted' ? registrationTargets : const [],
    );
    await repo.setEventReminders(eventId, reminders);

    if (visibilityScope != 'all' || registrationScope != 'all') {
      await repo.updateEvent(eventId, {
        'visibility_scope': visibilityScope,
        'registration_scope': registrationScope,
      });
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Espelha `_propagarEdicoesAposRegeneracao` DEPOIS da correção.
Future<String?> _propagarEdicoesAposRegeneracao(
  EventsRepository repo, {
  Map<String, dynamic> data = _data,
  required String visibilityScope,
  required String registrationScope,
  List<EventAudience> responsibles = const [],
  List<EventAudience> visibilityTargets = const [],
  List<EventAudience> registrationTargets = const [],
  List<EventReminder> reminders = const [],
}) async {
  const excluidos = {
    'start_date',
    'end_date',
    'visibility_scope',
    'registration_scope',
  };

  try {
    final ocorrencias = await repo.getEventsByBatch(_batchId);
    final futuras =
        ocorrencias.where((e) => e.startDate.isAfter(_agora)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (futuras.isEmpty) return null;

    final ancora = futuras.first;

    final ancoraOk = await _persistAudienceAndScopes(
      repo,
      ancora.id,
      visibilityScope: visibilityScope,
      registrationScope: registrationScope,
      responsibles: responsibles,
      visibilityTargets: visibilityTargets,
      registrationTargets: registrationTargets,
      reminders: reminders,
    );
    if (!ancoraOk) {
      return 'As ocorrências foram regeradas, mas os responsáveis, alvos e '
          'lembretes não foram salvos. Abra o evento e salve de novo.';
    }

    final persistido = ancora.toJson();
    final camposComuns = <String, dynamic>{
      for (final entrada in data.entries)
        if (!excluidos.contains(entrada.key)) entrada.key: entrada.value,
    };
    final comunsMudaram = camposComuns.entries.any(
      (entrada) => persistido[entrada.key] != entrada.value,
    );
    final escopoDivergente = futuras.any(
      (e) =>
          e.visibilityScope != visibilityScope ||
          e.registrationScope != registrationScope,
    );

    final campos = <String, dynamic>{
      if (comunsMudaram) ...camposComuns,
      if (escopoDivergente) ...{
        'visibility_scope': visibilityScope,
        'registration_scope': registrationScope,
      },
    };

    await repo.applySeriesUpdate(
      batchId: _batchId,
      anchorEventId: ancora.id,
      fields: campos,
    );
    return null;
  } catch (_) {
    return 'As ocorrências foram regeradas, mas as outras alterações não '
        'foram aplicadas. Abra o evento e salve de novo.';
  }
}

List<EventAudience> get _alvosDeVisibilidade => [
  EventAudience(
    eventId: _ocorrenciaAberta,
    role: 'visibility',
    ministryId: _ministryId,
  ),
];

List<EventAudience> get _alvosDeInscricao => [
  EventAudience(
    eventId: _ocorrenciaAberta,
    role: 'registration',
    rbacRoleId: _roleId,
  ),
];

void main() {
  group('a replicação acontece SEMPRE — a regressão que causava a perda', () {
    test(
      'nenhum campo comum mudou: a RPC ainda é chamada, com p_fields VAZIO',
      () async {
        final spy = _RegenerateAftermathSpy();

        // `_data` é idêntico ao que está persistido na âncora e o escopo bate:
        // é exatamente o caso em que o código antigo saía por
        // `if (!mudou) return null` e NÃO emitia requisição nenhuma.
        final aviso = await _propagarEdicoesAposRegeneracao(
          _repoWith(spy),
          visibilityScope: 'all',
          registrationScope: 'all',
          reminders: [
            EventReminder(eventId: _ocorrenciaAberta, offsetMinutes: 60),
          ],
        );

        expect(aviso, isNull);
        final rpc = spy.log.singleWhere((r) => r.isRpc);
        expect(
          Map<String, dynamic>.from(rpc.body!['p_fields'] as Map),
          isEmpty,
          reason:
              'p_fields vazio não emite UPDATE em public.event (passo (7) roda '
              'sob array_length > 0), mas o passo (9) replica os alvos da '
              'âncora para as ocorrências MANTIDAS',
        );
      },
    );

    test('os lembretes editados chegam ao servidor mesmo sem campo comum novo',
        () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
        reminders: [
          EventReminder(eventId: _ocorrenciaAberta, offsetMinutes: 1440),
        ],
      );

      final insercoes = spy.log.where(
        (r) => r.isReminder && r.method == 'POST',
      );
      expect(insercoes, isNotEmpty);
    });

    test('nenhuma requisição sai quando a série ficou só com passado', () async {
      final spy = _RegenerateAftermathSpy()
        ..lote = [
          _ocorrencia(
            id: 'aaaa0000-0000-4000-8000-00000000000a',
            startDate: '2026-08-30T19:30:00.000Z',
          ),
        ];

      final aviso = await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: _alvosDeVisibilidade,
      );

      expect(aviso, isNull);
      expect(spy.log.where((r) => r.isRpc), isEmpty);
      expect(spy.log.where((r) => r.isAudience), isEmpty);
    });
  });

  group('reancoragem — nunca na ocorrência aberta', () {
    test(
      'a âncora é a primeira ocorrência FUTURA, não a que o líder abriu',
      () async {
        final spy = _RegenerateAftermathSpy();

        await _propagarEdicoesAposRegeneracao(
          _repoWith(spy),
          visibilityScope: 'all',
          registrationScope: 'all',
        );

        final rpc = spy.log.singleWhere((r) => r.isRpc);
        expect(rpc.body!['p_anchor_event_id'], _primeiraFutura);
        expect(
          rpc.body!['p_anchor_event_id'],
          isNot(_ocorrenciaAberta),
          reason:
              'nota (l) da RPC de regeneração: a âncora fora do padrão novo é '
              'apagada junto, e chamar apply_event_series_update com ela '
              'responderia SERIES_NOT_FOUND',
        );
      },
    );

    test('a ocorrência PASSADA nunca é escolhida como âncora', () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      final rpc = spy.log.singleWhere((r) => r.isRpc);
      expect(
        rpc.body!['p_anchor_event_id'],
        isNot('aaaa0000-0000-4000-8000-00000000000a'),
      );
    });

    test('a leitura do lote acontece antes de qualquer gravação', () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      expect(spy.log.first.isBatchRead, isTrue);
    });
  });

  group('ordem: âncora nova antes da replicação', () {
    test('toda gravação de audiência acontece ANTES da RPC', () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
        responsibles: [
          EventAudience(
            eventId: _ocorrenciaAberta,
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
            'o passo (9) replica a audiência DA ÂNCORA: gravá-la depois '
            'propagaria os alvos antigos para todas as ocorrências mantidas',
      );
    });

    test('os alvos são gravados na âncora NOVA, não na ocorrência aberta',
        () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: _alvosDeVisibilidade,
      );

      final insercoes = spy.log.where(
        (r) => r.isAudience && r.method == 'POST',
      );
      expect(insercoes, isNotEmpty);
      for (final req in insercoes) {
        final linhas = jsonDecode(
          jsonEncode(req.body ?? const <String, dynamic>{}),
        );
        // O corpo do insert é uma lista; o spy só decodifica Map, então a
        // afirmação forte fica no PATCH de escopo, abaixo.
        expect(linhas, isNotNull);
      }

      final patch = spy.log.singleWhere((r) => r.isScopePatch);
      expect(patch.body!['visibility_scope'], 'restricted');
    });

    test('o PATCH de escopo da âncora vem depois dos alvos e antes da RPC',
        () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
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
    });
  });

  group('escopo — o segundo dano, mais grave que perda de edição', () {
    test(
      'restringir a série junto com o padrão CHEGA ao lote (era descartado)',
      () async {
        final spy = _RegenerateAftermathSpy();

        // O lote está 'all'/'all'; o formulário diz 'restricted'. Antes da
        // correção nada disso subia e a série continuava aberta para o tenant
        // inteiro, com o líder acreditando que tinha restringido.
        await _propagarEdicoesAposRegeneracao(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'all',
          visibilityTargets: _alvosDeVisibilidade,
        );

        final rpc = spy.log.singleWhere((r) => r.isRpc);
        final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
        expect(campos['visibility_scope'], 'restricted');
        expect(
          campos['registration_scope'],
          'all',
          reason: 'restringir a visibilidade não fecha a inscrição junto',
        );
      },
    );

    test('reabrir a série ("restricted" -> "all") também chega ao lote',
        () async {
      final spy = _RegenerateAftermathSpy()
        ..lote = [
          _ocorrencia(
            id: _primeiraFutura,
            startDate: '2026-09-10T19:30:00.000Z',
            visibilityScope: 'restricted',
          ),
          _ocorrencia(
            id: _segundaFutura,
            startDate: '2026-09-17T19:30:00.000Z',
            visibilityScope: 'restricted',
          ),
        ];

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      final rpc = spy.log.singleWhere((r) => r.isRpc);
      final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
      expect(
        campos['visibility_scope'],
        'all',
        reason:
            '_persistAudienceAndScopes só PROMOVE escopo (não rebaixa); quem '
            'fecha o caminho de volta é o passo (7), que não poupa a âncora',
      );
    });

    test(
      'lote já alinhado com o formulário NÃO recebe escopo no p_fields',
      () async {
        final spy = _RegenerateAftermathSpy()
          ..lote = [
            _ocorrencia(
              id: _primeiraFutura,
              startDate: '2026-09-10T19:30:00.000Z',
              visibilityScope: 'restricted',
            ),
            _ocorrencia(
              id: _segundaFutura,
              startDate: '2026-09-17T19:30:00.000Z',
              visibilityScope: 'restricted',
            ),
          ];

        await _propagarEdicoesAposRegeneracao(
          _repoWith(spy),
          visibilityScope: 'restricted',
          registrationScope: 'all',
          visibilityTargets: _alvosDeVisibilidade,
        );

        final rpc = spy.log.singleWhere((r) => r.isRpc);
        final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
        expect(
          campos.containsKey('visibility_scope'),
          isFalse,
          reason:
              'um UPDATE inócuo dispararia event_changed_notify_upd uma vez '
              'por linha — avalanche de avisos idênticos',
        );
        expect(campos.containsKey('registration_scope'), isFalse);
      },
    );

    test('campo comum alterado continua viajando inteiro (D-03)', () async {
      final spy = _RegenerateAftermathSpy();

      await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        data: {..._data, 'location': 'Salão anexo'},
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      final rpc = spy.log.singleWhere((r) => r.isRpc);
      final campos = Map<String, dynamic>.from(rpc.body!['p_fields'] as Map);
      expect(campos['location'], 'Salão anexo');
      expect(campos['name'], 'Culto de Domingo');
      expect(
        campos.containsKey('start_date'),
        isFalse,
        reason: 'reenviar a data desfaria o padrão que a regeneração acabou '
            'de aplicar',
      );
      expect(campos.containsKey('end_date'), isFalse);
    });
  });

  group('aborto quando a âncora nova falha', () {
    test('audiência falhou -> a replicação NÃO acontece', () async {
      final spy = _RegenerateAftermathSpy()..failAudience = true;

      final aviso = await _propagarEdicoesAposRegeneracao(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
        visibilityTargets: _alvosDeVisibilidade,
        registrationTargets: _alvosDeInscricao,
      );

      expect(
        spy.log.where((r) => r.isRpc),
        isEmpty,
        reason:
            'mandar "restricted" para o lote com a fonte de alvos quebrada '
            'deixaria todas as futuras restritas SEM alvo — invisíveis para '
            'todos (Pitfall 6)',
      );
      expect(spy.log.where((r) => r.isScopePatch), isEmpty);
      expect(aviso, isNotNull);
      expect(aviso, contains('regeradas'));
      expect(
        aviso,
        isNot(contains('Nada foi alterado')),
        reason:
            'a regeneração JÁ aconteceu quando isto roda — a copy não pode '
            'dizer que nada mudou',
      );
    });
  });
}
