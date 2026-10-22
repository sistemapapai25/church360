import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:church360_app/features/oauth_consent/data/oauth_consent_api.dart';

void main() {
  const base = 'https://projeto.supabase.co';
  const id = 'authz_0123456789';

  OAuthConsentApi api(MockClient client, {String? token = 'jwt-do-usuario'}) =>
      OAuthConsentApi(
        httpClient: client,
        supabaseUrl: base,
        apiKey: 'sb_publishable_teste',
        accessToken: () => token,
      );

  test('GET de detalhes usa o endpoint, a apikey e o JWT da sessão', () async {
    late http.Request visto;
    final client = MockClient((request) async {
      visto = request;
      return http.Response(
        jsonEncode({
          'authorization_id': id,
          'redirect_uri': 'https://app.example/cb',
          'scope': 'openid',
          'client': {'id': 'c1', 'name': 'Qualquer nome'},
          'user': {'id': 'u1', 'email': 'pessoa@example.com'},
        }),
        200,
      );
    });

    final resultado = await api(client).fetch(id);

    expect(visto.method, 'GET');
    expect(visto.url.toString(), '$base/auth/v1/oauth/authorizations/$id');
    expect(visto.headers['apikey'], 'sb_publishable_teste');
    expect(visto.headers['Authorization'], 'Bearer jwt-do-usuario');
    expect(resultado, isA<AuthorizationNeedsConsent>());
    final pedido = resultado as AuthorizationNeedsConsent;
    expect(pedido.clientId, 'c1');
    expect(pedido.redirectUri, 'https://app.example/cb');
    expect(pedido.scope, 'openid');
    expect(pedido.userEmail, 'pessoa@example.com');
  });

  test('resposta só com redirect_url = consentimento já dado', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'redirect_url': 'https://app.example/cb?code=1&state=s'}),
        200,
      ),
    );
    final resultado = await api(client).fetch(id);
    expect(resultado, isA<AuthorizationAlreadyDecided>());
    expect(
      (resultado as AuthorizationAlreadyDecided).redirectUrl,
      'https://app.example/cb?code=1&state=s',
    );
  });

  test(
    'approve e deny enviam a ação correta e devolvem a redirect_url',
    () async {
      final corpos = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/v1/oauth/authorizations/$id/consent');
        corpos.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'redirect_url': 'https://app.example/cb?x=1'}),
          200,
        );
      });

      expect(
        await api(client).decide(id, approve: true),
        'https://app.example/cb?x=1',
      );
      await api(client).decide(id, approve: false);
      expect(corpos, [
        {'action': 'approve'},
        {'action': 'deny'},
      ]);
    },
  );

  test('authorization_id inválido nunca chega à rede', () async {
    var chamadas = 0;
    final client = MockClient((_) async {
      chamadas++;
      return http.Response('{}', 200);
    });
    await expectLater(
      api(client).fetch('../admin'),
      throwsA(
        isA<OAuthConsentException>().having(
          (e) => e.failure,
          'failure',
          OAuthConsentFailure.invalidRequest,
        ),
      ),
    );
    expect(chamadas, 0);
  });

  test('sem sessão não chama a API', () async {
    var chamadas = 0;
    final client = MockClient((_) async {
      chamadas++;
      return http.Response('{}', 200);
    });
    await expectLater(
      api(client, token: null).fetch(id),
      throwsA(
        isA<OAuthConsentException>().having(
          (e) => e.failure,
          'failure',
          OAuthConsentFailure.sessionMissing,
        ),
      ),
    );
    expect(chamadas, 0);
  });

  group('mapeamento de status', () {
    for (final caso in <int, OAuthConsentFailure>{
      401: OAuthConsentFailure.sessionMissing,
      403: OAuthConsentFailure.sessionMissing,
      400: OAuthConsentFailure.expired,
      404: OAuthConsentFailure.expired,
      500: OAuthConsentFailure.network,
    }.entries) {
      test('HTTP ${caso.key} vira ${caso.value.name}', () async {
        final client = MockClient((_) async => http.Response('{}', caso.key));
        await expectLater(
          api(client).fetch(id),
          throwsA(
            isA<OAuthConsentException>().having(
              (e) => e.failure,
              'failure',
              caso.value,
            ),
          ),
        );
      });
    }

    test('corpo que não é objeto JSON vira invalidResponse', () async {
      final client = MockClient((_) async => http.Response('[]', 200));
      await expectLater(
        api(client).fetch(id),
        throwsA(
          isA<OAuthConsentException>().having(
            (e) => e.failure,
            'failure',
            OAuthConsentFailure.invalidResponse,
          ),
        ),
      );
    });
  });
}
