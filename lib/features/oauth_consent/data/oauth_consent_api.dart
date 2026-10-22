import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/oauth_client_allowlist.dart';

/// Cliente REST da tela de consentimento do OAuth 2.1 Server do Supabase Auth.
///
/// O `gotrue` Dart em uso (2.18.x) não expõe `auth.oauth.*`; as duas chamadas
/// abaixo são as mesmas que o `supabase-js` faz em
/// `getAuthorizationDetails` / `approveAuthorization` / `denyAuthorization`:
///
/// - `GET  /auth/v1/oauth/authorizations/{id}`
/// - `POST /auth/v1/oauth/authorizations/{id}/consent` `{action}`
///
/// Ambas exigem a sessão do próprio usuário (JWT no `Authorization`). Esta
/// classe não guarda token, não registra o `authorization_id` nem o e-mail em
/// log, e não toca em nenhuma tabela: quem cria o `code` é o Supabase Auth.
class OAuthConsentApi {
  final http.Client _http;
  final String _authBaseUrl;
  final String _apiKey;
  final String? Function() _accessToken;
  final Duration _timeout;

  OAuthConsentApi({
    required http.Client httpClient,
    required String supabaseUrl,
    required String apiKey,
    required String? Function() accessToken,
    Duration timeout = const Duration(seconds: 15),
  }) : _http = httpClient,
       _authBaseUrl = '$supabaseUrl/auth/v1',
       _apiKey = apiKey,
       _accessToken = accessToken,
       _timeout = timeout;

  Future<AuthorizationLookup> fetch(String authorizationId) async {
    final response = await _send('GET', _authorizationUri(authorizationId));
    final body = _decodeObject(response.body);

    final redirectUrl = body['redirect_url'];
    if (body['authorization_id'] == null && redirectUrl is String) {
      return AuthorizationAlreadyDecided(redirectUrl);
    }

    final client = body['client'];
    final user = body['user'];
    if (client is! Map || body['authorization_id'] is! String) {
      throw const OAuthConsentException(OAuthConsentFailure.invalidResponse);
    }
    return AuthorizationNeedsConsent(
      authorizationId: body['authorization_id'] as String,
      clientId: client['id'] as String?,
      redirectUri: body['redirect_uri'] as String?,
      scope: body['scope'] as String?,
      userEmail: user is Map ? user['email'] as String? : null,
    );
  }

  /// Aprova ou recusa. Devolve a `redirect_url` (com `code` e `state`, ou com
  /// `error=access_denied`) que o CHAMADOR precisa validar antes de navegar.
  Future<String> decide(String authorizationId, {required bool approve}) async {
    final response = await _send(
      'POST',
      _authorizationUri(authorizationId, consent: true),
      body: jsonEncode({'action': approve ? 'approve' : 'deny'}),
    );
    final redirectUrl = _decodeObject(response.body)['redirect_url'];
    if (redirectUrl is! String || redirectUrl.isEmpty) {
      throw const OAuthConsentException(OAuthConsentFailure.invalidResponse);
    }
    return redirectUrl;
  }

  Uri _authorizationUri(String authorizationId, {bool consent = false}) {
    if (!isValidAuthorizationId(authorizationId)) {
      throw const OAuthConsentException(OAuthConsentFailure.invalidRequest);
    }
    final suffix = consent ? '/consent' : '';
    return Uri.parse(
      '$_authBaseUrl/oauth/authorizations/$authorizationId$suffix',
    );
  }

  Future<http.Response> _send(String method, Uri uri, {String? body}) async {
    final token = _accessToken();
    if (token == null || token.isEmpty) {
      throw const OAuthConsentException(OAuthConsentFailure.sessionMissing);
    }
    final request = http.Request(method, uri)
      ..headers.addAll({
        'apikey': _apiKey,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = body;

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } catch (_) {
      throw const OAuthConsentException(OAuthConsentFailure.network);
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    if (status == 401 || status == 403) {
      throw const OAuthConsentException(OAuthConsentFailure.sessionMissing);
    }
    if (status == 400 || status == 404 || status == 410) {
      throw const OAuthConsentException(OAuthConsentFailure.expired);
    }
    throw const OAuthConsentException(OAuthConsentFailure.network);
  }

  Map<String, dynamic> _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // cai no erro abaixo
    }
    throw const OAuthConsentException(OAuthConsentFailure.invalidResponse);
  }
}

sealed class AuthorizationLookup {
  const AuthorizationLookup();
}

/// Usuário ainda não consentiu: a tela mostra o pedido.
class AuthorizationNeedsConsent extends AuthorizationLookup {
  final String authorizationId;
  final String? clientId;
  final String? redirectUri;
  final String? scope;
  final String? userEmail;

  const AuthorizationNeedsConsent({
    required this.authorizationId,
    required this.clientId,
    required this.redirectUri,
    required this.scope,
    required this.userEmail,
  });
}

/// Consentimento já dado antes: o Supabase devolve direto a URL de retorno.
class AuthorizationAlreadyDecided extends AuthorizationLookup {
  final String redirectUrl;
  const AuthorizationAlreadyDecided(this.redirectUrl);
}

enum OAuthConsentFailure {
  invalidRequest,
  sessionMissing,
  expired,
  network,
  invalidResponse,
}

class OAuthConsentException implements Exception {
  final OAuthConsentFailure failure;
  const OAuthConsentException(this.failure);

  @override
  String toString() => 'OAuthConsentException(${failure.name})';
}
