// REG-03: a autorização de escrita da aba "Inscritos" é composta —
// permissão global de cargo (`events.manage_registrations`) OU vínculo de
// responsável por AQUELE evento. Gatar só pela permissão global quebraria o
// critério de sucesso #1 da fase: o líder de grupo marcado como responsável
// não tem a permissão e perderia todas as ações.
//
// Estes quatro testes travam a tabela-verdade do gate, incluindo o
// curto-circuito (permissão global não paga o custo da RPC) e o
// comportamento fail-closed em erro (erro nunca produz `true`).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _permissao = 'events.manage_registrations';

/// Espião no nível do repositório: registra quantas vezes a consulta de
/// responsável (a RPC `am_i_event_responsible`) foi disparada, para provar o
/// curto-circuito por ausência de chamada.
class _EventsRepositorySpy extends EventsRepository {
  _EventsRepositorySpy({this.responsavel = false, this.lancaErro = false})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          httpClient: MockClient(
            (request) async => http.Response('[]', 200, request: request),
          ),
          // CHU-321: evita timer pendente do GoTrue em flutter_test.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool responsavel;
  final bool lancaErro;
  int chamadasIsEventResponsible = 0;

  @override
  Future<bool> isEventResponsible(String eventId) async {
    chamadasIsEventResponsible++;
    if (lancaErro) {
      throw Exception('falha ao consultar o vínculo de responsável');
    }
    return responsavel;
  }
}

ProviderContainer _containerCom({
  required bool temPermissaoGlobal,
  required _EventsRepositorySpy spy,
}) {
  final container = ProviderContainer(
    overrides: [
      eventsRepositoryProvider.overrideWithValue(spy),
      currentUserHasPermissionProvider(
        _permissao,
      ).overrideWith((ref) async => temPermissaoGlobal),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'permissão global concede sem consultar o vínculo de responsável (curto-circuito)',
    () async {
      final spy = _EventsRepositorySpy(responsavel: false);
      final container = _containerCom(temPermissaoGlobal: true, spy: spy);

      final pode = await container.read(
        canManageEventRegistrationsProvider(_eventId).future,
      );

      expect(pode, isTrue);
      expect(
        spy.chamadasIsEventResponsible,
        0,
        reason:
            'com permissão global o gate não pode pagar o custo da RPC de responsável',
      );
    },
  );

  test(
    'sem permissão global, ser responsável pelo evento concede',
    () async {
      final spy = _EventsRepositorySpy(responsavel: true);
      final container = _containerCom(temPermissaoGlobal: false, spy: spy);

      final pode = await container.read(
        canManageEventRegistrationsProvider(_eventId).future,
      );

      expect(pode, isTrue);
      expect(spy.chamadasIsEventResponsible, 1);
    },
  );

  test(
    'sem permissão global e sem vínculo de responsável, nega',
    () async {
      final spy = _EventsRepositorySpy(responsavel: false);
      final container = _containerCom(temPermissaoGlobal: false, spy: spy);

      final pode = await container.read(
        canManageEventRegistrationsProvider(_eventId).future,
      );

      expect(pode, isFalse);
    },
  );

  test(
    'erro na consulta de responsável nunca produz `true` (fail-closed)',
    () async {
      final spy = _EventsRepositorySpy(lancaErro: true);
      final container = _containerCom(temPermissaoGlobal: false, spy: spy);

      await expectLater(
        container.read(canManageEventRegistrationsProvider(_eventId).future),
        throwsA(isA<Exception>()),
      );

      final valor = container.read(
        canManageEventRegistrationsProvider(_eventId),
      );
      expect(
        valor.hasError,
        isTrue,
        reason: 'o consumidor precisa ver erro, não um valor permissivo',
      );
      expect(
        valor.valueOrNull,
        isNot(true),
        reason: 'nenhum caminho de erro pode resolver `true`',
      );
    },
  );
}
