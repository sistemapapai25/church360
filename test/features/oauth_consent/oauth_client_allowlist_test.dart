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

  test('a allowlist de produção começa vazia (fail-closed)', () {
    expect(kOAuthAllowedClients, isEmpty);
    expect(findAllowedClient(lider360.clientId), isNull);
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

    test('exige openid', () {
      expect(scopesAllowed('email', lider360), isFalse);
      expect(scopesAllowed('', lider360), isFalse);
      expect(scopesAllowed(null, lider360), isFalse);
    });

    test('rejeita offline_access e escopos fora da lista', () {
      expect(scopesAllowed('openid offline_access', lider360), isFalse);
      expect(scopesAllowed('openid phone', lider360), isFalse);
      expect(scopesAllowed('openid profile', lider360), isFalse);
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
