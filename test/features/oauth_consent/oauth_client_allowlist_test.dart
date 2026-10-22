import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/oauth_consent/domain/oauth_client_allowlist.dart';

/// Trava das regras da allowlist do login único. Cada caso é uma regra de
/// segurança: client desconhecido, escopo extra e destino diferente do
/// cadastrado precisam ser recusados.
void main() {
  const lider360 = OAuthAllowedClient(
    clientId: '11111111-2222-4333-8444-555555555555',
    displayName: 'Lider360',
    redirectUris: [
      'https://gestao-lideres-rho.vercel.app/auth/church360/callback',
      'http://localhost:3000/auth/church360/callback',
    ],
    allowedScopes: {'openid', 'email'},
  );
  const allowlist = [lider360];

  test('a allowlist real tem SÓ o client de teste do Lider360, travado', () {
    expect(kOAuthAllowedClients, hasLength(1));
    final real = kOAuthAllowedClients.single;
    expect(real.clientId, 'd8e86d80-0a75-4fa2-ae2e-23c40a7f26ef');
    expect(real.displayName, 'Lider360');
    expect(real.redirectUris, [
      'http://localhost:3000/auth/church360/callback',
      'https://gestao-lideres-git-sso-church360-ap-bergs-projects.vercel.app/auth/church360/callback',
    ]);
    expect(real.allowedScopes, {'email'});
    expect(real.allowedScopes.contains('offline_access'), isFalse);
    // Um client fictício continua desconhecido para a allowlist real.
    expect(findAllowedClient(lider360.clientId), isNull);
    expect(
      findAllowedClient('d8e86d80-0a75-4fa2-ae2e-23c40a7f26ef'),
      same(real),
    );
  });

  test('allowlist real: retorno só para as URIs cadastradas', () {
    final real = kOAuthAllowedClients.single;
    expect(
      redirectAllowed(
        'http://localhost:3000/auth/church360/callback?code=x&state=y',
        real,
      ),
      isTrue,
    );
    expect(
      redirectAllowed(
        'https://gestao-lideres-git-sso-church360-ap-bergs-projects.vercel.app/auth/church360/callback?code=x',
        real,
      ),
      isTrue,
    );
    for (final url in [
      'https://gestao-lideres-rho.vercel.app/auth/church360/callback',
      'http://localhost:3001/auth/church360/callback',
      'https://gestao-lideres-git-outra-ap-bergs-projects.vercel.app/auth/church360/callback',
    ]) {
      expect(redirectAllowed(url, real), isFalse, reason: url);
    }
  });

  group('authorization_id', () {
    test('aceita identificador opaco comum', () {
      expect(isValidAuthorizationId('aBc123_-xyz789'), isTrue);
      expect(
        isValidAuthorizationId('9b2f0c1e-7d4a-4e8b-9c1d-2f3a4b5c6d7e'),
        isTrue,
      );
    });

    test('rejeita vazio, curto e caracteres de caminho', () {
      expect(isValidAuthorizationId(null), isFalse);
      expect(isValidAuthorizationId(''), isFalse);
      expect(isValidAuthorizationId('abc'), isFalse);
      expect(isValidAuthorizationId('../../admin'), isFalse);
      expect(isValidAuthorizationId('abcdefgh/consent'), isFalse);
      expect(isValidAuthorizationId('abcdefgh?x=1'), isFalse);
    });
  });

  group('client', () {
    test('encontra client cadastrado', () {
      expect(
        findAllowedClient(lider360.clientId, allowlist: allowlist),
        same(lider360),
      );
    });

    test('rejeita client desconhecido ou ausente', () {
      expect(findAllowedClient('outro', allowlist: allowlist), isNull);
      expect(findAllowedClient(null, allowlist: allowlist), isNull);
      expect(findAllowedClient('', allowlist: allowlist), isNull);
    });
  });

  group('escopos', () {
    test('aceita openid e openid email', () {
      expect(scopesAllowed('openid', lider360), isTrue);
      expect(scopesAllowed('openid email', lider360), isTrue);
      expect(scopesAllowed('  email   openid ', lider360), isTrue);
    });

    test('aceita nenhum escopo (MVP sem ID token) e só escopos da lista', () {
      expect(scopesAllowed(null, lider360), isTrue);
      expect(scopesAllowed('', lider360), isTrue);
      expect(scopesAllowed('   ', lider360), isTrue);
      expect(scopesAllowed('email', lider360), isTrue);
    });

    test('rejeita offline_access e escopos fora da lista', () {
      expect(scopesAllowed('offline_access', lider360), isFalse);
      expect(scopesAllowed('openid offline_access', lider360), isFalse);
      expect(scopesAllowed('openid phone', lider360), isFalse);
      expect(scopesAllowed('openid profile', lider360), isFalse);
      expect(scopesAllowed('phone', lider360), isFalse);
    });

    test('offline_access é recusado mesmo se alguém o puser na lista', () {
      const descuidado = OAuthAllowedClient(
        clientId: 'x',
        displayName: 'X',
        redirectUris: ['https://x.example/cb'],
        allowedScopes: {'openid', 'offline_access'},
      );
      expect(scopesAllowed('openid offline_access', descuidado), isFalse);
      expect(scopesAllowed('openid', descuidado), isTrue);
    });
  });

  group('redirect', () {
    test('aceita URI cadastrada com code e state na query', () {
      expect(
        redirectAllowed(
          'https://gestao-lideres-rho.vercel.app/auth/church360/callback?code=x&state=y',
          lider360,
        ),
        isTrue,
      );
      expect(
        redirectAllowed(
          'http://localhost:3000/auth/church360/callback?error=access_denied',
          lider360,
        ),
        isTrue,
      );
    });

    test('rejeita host, caminho, porta ou esquema diferentes', () {
      for (final url in [
        'https://gestao-lideres.vercel.app/auth/church360/callback',
        'https://gestao-lideres-rho.vercel.app/auth/church360/callback/x',
        'https://gestao-lideres-rho.vercel.app/',
        'https://gestao-lideres-rho.vercel.app:8443/auth/church360/callback',
        'http://gestao-lideres-rho.vercel.app/auth/church360/callback',
        'http://localhost:3001/auth/church360/callback',
        'https://evil.example/auth/church360/callback',
      ]) {
        expect(redirectAllowed(url, lider360), isFalse, reason: url);
      }
    });

    test('rejeita userinfo, fragmento, relativo e lixo', () {
      for (final url in [
        'https://user@gestao-lideres-rho.vercel.app/auth/church360/callback',
        'https://gestao-lideres-rho.vercel.app/auth/church360/callback#x',
        '/auth/church360/callback',
        'javascript:alert(1)',
        '',
        null,
      ]) {
        expect(redirectAllowed(url, lider360), isFalse, reason: '$url');
      }
    });

    test('clientForRedirect só reconhece destino de client da allowlist', () {
      expect(
        clientForRedirect(
          'https://gestao-lideres-rho.vercel.app/auth/church360/callback?code=1',
          allowlist: allowlist,
        ),
        same(lider360),
      );
      expect(
        clientForRedirect(
          'https://evil.example/cb?code=1',
          allowlist: allowlist,
        ),
        isNull,
      );
    });
  });
}
