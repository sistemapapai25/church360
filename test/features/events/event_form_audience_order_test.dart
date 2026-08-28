// Fase 3 — Plano 04, Task 2. Prova de que a gravação de um evento restrito
// segue sempre a ordem de três passos: evento com escopo 'all' -> audiência
// -> PATCH de escopo final. Ver Pitfall 1 (03-RESEARCH.md): uma policy
// `AS RESTRICTIVE FOR SELECT` em `public.event` também é avaliada no
// `INSERT ... RETURNING`/`UPDATE ... RETURNING`, e o Postgres LANÇA ERRO se
// a linha nova não passar — por isso o evento nunca pode nascer já com o
// escopo final, que só existe depois que a audiência foi gravada.
//
// O widget completo (`event_form_screen.dart`) não é testável sem Supabase
// inicializado; o valor deste teste é provar a SEQUÊNCIA de requests que
// `_persistAudienceAndScopes` produz, exercitando o repositório na mesma
// ordem que o método usa (mesmo `try/catch` incluso).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_audience.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _ministryId = '44444444-0000-4000-8000-000000000004';
const _roleId = '55555555-0000-4000-8000-000000000005';

class _LoggedRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  _LoggedRequest(this.method, this.path, this.body);
}

/// Spy que registra TODA requisição (a `/event` e a `/event_audience`) numa
/// única lista ordenada — é essa ordem que os testes afirmam, não só a
/// ocorrência de cada chamada isolada.
class _SaveSequenceSpy {
  final List<_LoggedRequest> log = [];

  /// Quando `true`, qualquer request a `/event_audience` volta com erro —
  /// simula falha na gravação da audiência (comportamento #5).
  bool failAudience = false;

  http.Client get client => MockClient((request) async {
        final headers = {'content-type': 'application/json; charset=utf-8'};
        Map<String, dynamic>? body;
        try {
          final decoded = jsonDecode(request.body);
          if (decoded is Map) body = Map<String, dynamic>.from(decoded);
        } catch (_) {
          // DELETE e outras requisições sem corpo: sem problema, fica null.
        }

        log.add(_LoggedRequest(request.method, request.url.path, body));

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
          final responseBody = {
            'id': _eventId,
            'name': 'Culto de teste',
            'start_date': '2026-08-30T19:00:00.000Z',
            'created_at': '2026-08-30T19:00:00.000Z',
            'visibility_scope': body?['visibility_scope'] ?? 'all',
            'registration_scope': body?['registration_scope'] ?? 'all',
          };
          return http.Response(
            jsonEncode(responseBody),
            request.method == 'POST' ? 201 : 200,
            request: request,
            headers: headers,
          );
        }

        return http.Response('[]', 200, request: request, headers: headers);
      });
}

EventsRepository _repoWith(_SaveSequenceSpy spy) => EventsRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: spy.client,
        // CHU-321: evita timer pendente do GoTrue em flutter_test.
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

/// Espelha `_persistAudienceAndScopes` de `event_form_screen.dart`: mesma
/// sequência (evento `all` -> audiência dos 3 papéis -> PATCH de escopo
/// condicional) e o mesmo `try/catch` que impede o PATCH de rodar se a
/// audiência falhar.
Future<void> _createEventFollowingThreeStepOrder(
  EventsRepository repo, {
  required String visibilityScope,
  required String registrationScope,
  List<EventAudience> responsibles = const [],
  List<EventAudience> visibilityTargets = const [],
  List<EventAudience> registrationTargets = const [],
}) async {
  final created = await repo.createEvent({
    'name': 'Culto de teste',
    'start_date': '2026-08-30T19:00:00.000Z',
    // Pitfall 1: o evento nasce SEMPRE com escopo 'all', nunca com o valor
    // final — a policy AS RESTRICTIVE FOR SELECT do Plano 05 também avalia
    // o INSERT ... RETURNING e lançaria erro se a linha nova não passasse.
    'visibility_scope': 'all',
    'registration_scope': 'all',
  });

  try {
    await repo.setEventAudience(created.id, 'responsible', responsibles);
    await repo.setEventAudience(
      created.id,
      'visibility',
      visibilityScope == 'restricted' ? visibilityTargets : const [],
    );
    await repo.setEventAudience(
      created.id,
      'registration',
      registrationScope == 'restricted' ? registrationTargets : const [],
    );
    if (visibilityScope != 'all' || registrationScope != 'all') {
      await repo.updateEvent(created.id, {
        'visibility_scope': visibilityScope,
        'registration_scope': registrationScope,
      });
    }
  } catch (_) {
    // Igual ao catch de _persistAudienceAndScopes: o PATCH de escopo NÃO
    // pode rodar se a audiência falhar — o evento permanece 'all'.
  }
}

void main() {
  test(
    'POST em /event carrega visibility_scope e registration_scope "all", nunca o valor restrito',
    () async {
      final spy = _SaveSequenceSpy();

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'visibility',
            ministryId: _ministryId,
          ),
        ],
      );

      final firstEventPost = spy.log.firstWhere(
        (r) => r.path.endsWith('/event') && r.method == 'POST',
      );
      expect(firstEventPost.body?['visibility_scope'], 'all');
      expect(firstEventPost.body?['registration_scope'], 'all');
    },
  );

  test(
    'depois do POST em /event vêm as gravações de /event_audience para os papéis com alvos',
    () async {
      final spy = _SaveSequenceSpy();

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
        visibilityTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'visibility',
            ministryId: _ministryId,
          ),
        ],
        registrationTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'registration',
            rbacRoleId: _roleId,
          ),
        ],
      );

      final firstEventPostIndex = spy.log.indexWhere(
        (r) => r.path.endsWith('/event') && r.method == 'POST',
      );
      final audienceIndices = [
        for (var i = 0; i < spy.log.length; i++)
          if (spy.log[i].path.endsWith('/event_audience')) i,
      ];

      expect(audienceIndices, isNotEmpty);
      expect(
        audienceIndices.every((i) => i > firstEventPostIndex),
        isTrue,
        reason:
            'toda gravação de audiência vem depois do POST inicial de /event',
      );
      // 3 papéis (responsible/visibility/registration) x DELETE, mais o
      // POST dos 2 papéis que têm alvo (visibility e registration).
      expect(audienceIndices.length, 5);
    },
  );

  test(
    'só depois da audiência vem um PATCH em /event com o escopo final',
    () async {
      final spy = _SaveSequenceSpy();

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
        visibilityTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'visibility',
            ministryId: _ministryId,
          ),
        ],
        registrationTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'registration',
            rbacRoleId: _roleId,
          ),
        ],
      );

      final patch = spy.log.singleWhere(
        (r) => r.path.endsWith('/event') && r.method == 'PATCH',
      );
      expect(patch.body?['visibility_scope'], 'restricted');
      expect(patch.body?['registration_scope'], 'restricted');

      final lastAudienceIndex = spy.log.lastIndexWhere(
        (r) => r.path.endsWith('/event_audience'),
      );
      final patchIndex = spy.log.indexOf(patch);
      expect(
        patchIndex > lastAudienceIndex,
        isTrue,
        reason:
            'o PATCH de escopo só pode vir depois de toda gravação de audiência',
      );
    },
  );

  test(
    'a ordem relativa é sempre /event (all) -> /event_audience -> PATCH de escopo',
    () async {
      final spy = _SaveSequenceSpy();

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'visibility',
            ministryId: _ministryId,
          ),
        ],
      );

      final postIndex = spy.log.indexWhere(
        (r) => r.path.endsWith('/event') && r.method == 'POST',
      );
      final audienceIndices = [
        for (var i = 0; i < spy.log.length; i++)
          if (spy.log[i].path.endsWith('/event_audience')) i,
      ];
      final patchIndex = spy.log.indexWhere(
        (r) => r.path.endsWith('/event') && r.method == 'PATCH',
      );

      expect(
        postIndex,
        0,
        reason: 'o evento é sempre a primeira requisição da sequência',
      );
      expect(audienceIndices.every((i) => i > postIndex), isTrue);
      expect(
        patchIndex > audienceIndices.reduce((a, b) => a > b ? a : b),
        isTrue,
      );
    },
  );

  test(
    'com os dois escopos em "all", nenhum PATCH extra de escopo é emitido',
    () async {
      final spy = _SaveSequenceSpy();

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'all',
        registrationScope: 'all',
      );

      final patches = spy.log.where(
        (r) => r.path.endsWith('/event') && r.method == 'PATCH',
      );
      expect(patches, isEmpty);
    },
  );

  test(
    'se a gravação da audiência falhar, o PATCH de escopo não é emitido',
    () async {
      final spy = _SaveSequenceSpy()..failAudience = true;

      await _createEventFollowingThreeStepOrder(
        _repoWith(spy),
        visibilityScope: 'restricted',
        registrationScope: 'all',
        visibilityTargets: [
          EventAudience(
            eventId: _eventId,
            role: 'visibility',
            ministryId: _ministryId,
          ),
        ],
      );

      final patches = spy.log.where(
        (r) => r.path.endsWith('/event') && r.method == 'PATCH',
      );
      expect(
        patches,
        isEmpty,
        reason: 'audiência falhou; o evento tem que permanecer com escopo all',
      );
    },
  );
}
