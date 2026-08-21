// CHU-322: os upserts do módulo de notificações não declaravam `onConflict`.
// Sem ele o PostgREST infere a PK (`id`) como alvo do ON CONFLICT — e como o
// app nunca envia o `id`, o upsert vira INSERT puro e qualquer linha já
// existente derruba a requisição com 409 na UNIQUE.
//
// O caso vivo era `updateNotificationPreferences`: em 21/08/2026 a produção
// tinha 43 linhas em `notification_preferences`, ou seja, 43 usuários que
// levariam 409 ao salvar as configurações de notificação de novo.
//
// As UNIQUEs foram conferidas contra a produção na mesma data:
// `notification_preferences` é `(user_id)` — `on_conflict=user_id,tenant_id`
// devolve 42P10 — e `fcm_tokens` é `(user_id, device_id)`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/notifications/data/notification_repository.dart';

const _authUserId = '11111111-0000-4000-8000-000000000001';
const _agora = '2026-08-21T23:00:00.000Z';

/// JWT sem assinatura válida: o gotrue só decodifica o payload para ler o
/// `exp`, nunca verifica a assinatura no cliente.
String _fakeJwt() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg({
    'sub': _authUserId,
    'role': 'authenticated',
    'exp': DateTime(2099).millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.assinatura-de-teste';
}

class _NotificationsApiSpy {
  _NotificationsApiSpy({this.preferenciaJaExiste = true});

  /// Controla o que o `GET /notification_preferences` devolve, para escolher
  /// entre o ramo de leitura e o de criação preguiçosa.
  final bool preferenciaJaExiste;

  final List<Uri> preferencesUpserts = [];
  final List<Uri> fcmUpserts = [];
  final List<Map<String, dynamic>> upsertedRows = [];

  Map<String, dynamic> get _linhaPreferencias => {
        'id': '22222222-0000-4000-8000-000000000002',
        'user_id': _authUserId,
        'created_at': _agora,
        'updated_at': _agora,
      };

  http.Client get client => MockClient((request) async {
        final path = request.url.path;
        final json = {'content-type': 'application/json; charset=utf-8'};

        if (path.endsWith('/notification_preferences')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(preferenciaJaExiste ? [_linhaPreferencias] : []),
              200,
              request: request,
              headers: json,
            );
          }
          if (request.method == 'POST') {
            preferencesUpserts.add(request.url);
            upsertedRows
                .add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
            // `.single()` pede `application/vnd.pgrst.object+json`: a resposta
            // tem que ser o objeto, não uma lista de um item.
            return http.Response(
              jsonEncode(_linhaPreferencias),
              201,
              request: request,
              headers: json,
            );
          }
        }

        if (path.endsWith('/fcm_tokens') && request.method == 'POST') {
          fcmUpserts.add(request.url);
          upsertedRows
              .add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
          return http.Response(
            jsonEncode({
              'id': '33333333-0000-4000-8000-000000000003',
              'user_id': _authUserId,
              'token': 'token-de-teste',
              'created_at': _agora,
              'updated_at': _agora,
              'last_used_at': _agora,
            }),
            201,
            request: request,
            headers: json,
          );
        }

        return http.Response('[]', 200, request: request, headers: json);
      });
}

Future<NotificationRepository> _repoWith(_NotificationsApiSpy spy) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // Sem isso o GoTrue deixa um `Timer.periodic` de auto-refresh vivo e o
    // flutter_test falha o teste por timer pendente (CHU-321).
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  // O repositório resolve o usuário por `auth.currentUser`; `setInitialSession`
  // injeta a sessão sem tocar na rede.
  await client.auth.setInitialSession(jsonEncode({
    'access_token': _fakeJwt(),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-de-teste',
    'user': {
      'id': _authUserId,
      'aud': 'authenticated',
      'email': 'qa@church360.test',
      'created_at': _agora,
      'app_metadata': <String, dynamic>{},
    },
  }));

  return NotificationRepository(client);
}

void main() {
  test('salvar preferências declara o conflito por (user_id)', () async {
    final spy = _NotificationsApiSpy();

    await (await _repoWith(spy)).updateNotificationPreferences(general: false);

    expect(spy.preferencesUpserts.single.queryParameters['on_conflict'],
        'user_id');
    expect(spy.upsertedRows.single['general'], isFalse);
    expect(spy.upsertedRows.single.containsKey('id'), isFalse,
        reason: 'o app não envia a PK — é por isso que o onConflict é preciso');
  });

  test('a criação preguiçosa das preferências também declara o conflito',
      () async {
    final spy = _NotificationsApiSpy(preferenciaJaExiste: false);

    await (await _repoWith(spy)).getNotificationPreferences();

    expect(spy.preferencesUpserts.single.queryParameters['on_conflict'],
        'user_id');
  });

  test('preferências já existentes são lidas sem nenhuma gravação', () async {
    final spy = _NotificationsApiSpy();

    final prefs = await (await _repoWith(spy)).getNotificationPreferences();

    expect(prefs, isNotNull);
    expect(spy.preferencesUpserts, isEmpty);
  });

  test('o token FCM declara o conflito por (user_id, device_id)', () async {
    final spy = _NotificationsApiSpy();

    await (await _repoWith(spy)).saveFcmToken(
      token: 'token-de-teste',
      deviceId: 'aparelho-1',
    );

    expect(spy.fcmUpserts.single.queryParameters['on_conflict'],
        'user_id,device_id');
  });
}
