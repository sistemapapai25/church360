import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:church360_app/features/oauth_consent/data/oauth_consent_api.dart';
import 'package:church360_app/features/oauth_consent/domain/oauth_client_allowlist.dart';
import 'package:church360_app/features/oauth_consent/presentation/oauth_consent_screen.dart';

const _clientId = '11111111-2222-4333-8444-555555555555';
const _callback =
    'https://gestao-lideres-rho.vercel.app/auth/church360/callback';
const _authId = 'authz_0123456789';

const _lider360 = OAuthAllowedClient(
  clientId: _clientId,
  displayName: 'Lider360',
  redirectUris: [_callback],
  allowedScopes: {'openid', 'email'},
);

String _detalhes({
  String clientId = _clientId,
  String redirectUri = _callback,
  String scope = 'openid email',
}) => jsonEncode({
  'authorization_id': _authId,
  'redirect_uri': redirectUri,
  'scope': scope,
  'client': {'id': clientId, 'name': 'Nome vindo do servidor'},
  'user': {'id': 'u1', 'email': 'pessoa@example.com'},
});

class _Cenario {
  final navegacoes = <String>[];
  final acoes = <String>[];

  Future<void> montar(
    WidgetTester tester, {
    required http.Response Function() get,
    http.Response Function(String acao)? post,
    String? authorizationId = _authId,
  }) async {
    final client = MockClient((request) async {
      if (request.method == 'GET') return get();
      final acao =
          (jsonDecode(request.body) as Map<String, dynamic>)['action']
              as String;
      acoes.add(acao);
      return post!(acao);
    });
    final api = OAuthConsentApi(
      httpClient: client,
      supabaseUrl: 'https://projeto.supabase.co',
      apiKey: 'sb_publishable_teste',
      accessToken: () => 'jwt',
    );
    final router = GoRouter(
      initialLocation: '/oauth/consent',
      routes: [
        GoRoute(
          path: '/oauth/consent',
          builder: (_, __) => OAuthConsentScreen(
            authorizationId: authorizationId,
            api: api,
            allowlist: const [_lider360],
            navigateExternal: navegacoes.add,
            signOut: () async {},
          ),
        ),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _assentar(tester);
  }
}

/// O estado "Voltando ao…" é um spinner contínuo (a página está saindo), então
/// a árvore nunca fica parada: avança o relógio em passos fixos.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.pump();
  await tester.tap(find.text(texto));
  await _assentar(tester);
}

void main() {
  testWidgets('client permitido: mostra o pedido com nome da allowlist', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(tester, get: () => http.Response(_detalhes(), 200));

    expect(find.text('Entrar no Lider360'), findsOneWidget);
    expect(
      find.text(
        'O Lider360 quer confirmar sua identidade usando sua conta Church360.',
      ),
      findsOneWidget,
    );
    expect(find.text('pessoa@example.com'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    // Nada técnico na tela: nem o nome cadastrado no servidor, nem IDs.
    expect(find.textContaining('Nome vindo do servidor'), findsNothing);
    expect(find.textContaining(_clientId), findsNothing);
    expect(find.textContaining(_authId), findsNothing);
    expect(c.navegacoes, isEmpty);
  });

  testWidgets('Continuar aprova e volta para o callback validado', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(), 200),
      post: (_) => http.Response(
        jsonEncode({'redirect_url': '$_callback?code=abc&state=xyz'}),
        200,
      ),
    );
    await _tocar(tester, 'Continuar');

    expect(c.acoes, ['approve']);
    expect(c.navegacoes, ['$_callback?code=abc&state=xyz']);
    expect(find.text('Voltando ao Lider360…'), findsOneWidget);
  });

  testWidgets('Cancelar recusa e volta com o erro para o Lider360', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(), 200),
      post: (_) => http.Response(
        jsonEncode({'redirect_url': '$_callback?error=access_denied&state=s'}),
        200,
      ),
    );
    await _tocar(tester, 'Cancelar');

    expect(c.acoes, ['deny']);
    expect(c.navegacoes, ['$_callback?error=access_denied&state=s']);
  });

  testWidgets('client desconhecido: recusa sem redirecionar e sem aprovar', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(clientId: 'client-estranho'), 200),
    );
    expect(find.text('Aplicativo não autorizado'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(c.acoes, isEmpty);
    expect(c.navegacoes, isEmpty);
  });

  testWidgets('escopo extra (offline_access) é recusado', (tester) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(scope: 'openid offline_access'), 200),
    );
    expect(find.text('Não foi possível continuar'), findsOneWidget);
    expect(c.acoes, isEmpty);
    expect(c.navegacoes, isEmpty);
  });

  testWidgets('redirect_uri fora da allowlist é recusada', (tester) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(
        _detalhes(redirectUri: 'https://evil.example/auth/church360/callback'),
        200,
      ),
    );
    expect(find.text('Não foi possível continuar'), findsOneWidget);
    expect(c.navegacoes, isEmpty);
  });

  testWidgets('redirect_url devolvida pela aprovação também é conferida', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(), 200),
      post: (_) => http.Response(
        jsonEncode({'redirect_url': 'https://evil.example/cb?code=abc'}),
        200,
      ),
    );
    await _tocar(tester, 'Continuar');
    expect(c.navegacoes, isEmpty);
    expect(find.text('Não foi possível continuar'), findsOneWidget);
  });

  testWidgets('consentimento anterior: volta direto, sem nova pergunta', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(
        jsonEncode({'redirect_url': '$_callback?code=abc&state=xyz'}),
        200,
      ),
    );
    expect(c.navegacoes, ['$_callback?code=abc&state=xyz']);
    expect(find.text('Continuar'), findsNothing);
  });

  testWidgets('consentimento anterior para destino desconhecido é recusado', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(
        jsonEncode({'redirect_url': 'https://evil.example/cb?code=abc'}),
        200,
      ),
    );
    expect(c.navegacoes, isEmpty);
    expect(find.text('Aplicativo não autorizado'), findsOneWidget);
  });

  testWidgets('pedido expirado ou já usado', (tester) async {
    final c = _Cenario();
    await c.montar(tester, get: () => http.Response('{}', 404));
    expect(find.text('Pedido expirado'), findsOneWidget);
  });

  testWidgets('authorization_id ausente ou malformado', (tester) async {
    final c = _Cenario();
    await c.montar(
      tester,
      get: () => http.Response(_detalhes(), 200),
      authorizationId: '../x',
    );
    expect(find.text('Não foi possível continuar'), findsOneWidget);
  });

  testWidgets('sessão inválida volta ao login preservando o pedido', (
    tester,
  ) async {
    final c = _Cenario();
    await c.montar(tester, get: () => http.Response('{}', 401));
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('cabe em celular de 360 px sem overflow nem corte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Cenario();
    await c.montar(tester, get: () => http.Response(_detalhes(), 200));

    expect(tester.takeException(), isNull);
    for (final texto in ['Continuar', 'Cancelar', 'Trocar conta']) {
      final caixa = tester.getRect(find.text(texto));
      expect(caixa.left, greaterThanOrEqualTo(0), reason: texto);
      expect(caixa.right, lessThanOrEqualTo(360), reason: texto);
    }
  });
}
