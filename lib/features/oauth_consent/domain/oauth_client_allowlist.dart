/// Allowlist dos aplicativos que podem usar o login do Church360 (OAuth 2.1 /
/// OIDC do Supabase Auth).
///
/// O Supabase já recusa `client_id` e `redirect_uri` não cadastrados no
/// `/oauth/authorize`. Esta lista é a SEGUNDA trava, do lado da tela de
/// consentimento: mesmo que alguém cadastre um client novo no painel, a tela
/// só aprova quem estiver aqui, revisado em código. Nada de auto-approve
/// genérico.
///
/// Regras (todas fail-closed):
/// - client fora da lista: a tela recusa e NÃO redireciona para lugar nenhum
///   (mandar o usuário para a `redirect_uri` de um client desconhecido seria
///   entregá-lo a um destino que ninguém revisou);
/// - escopo fora de [OAuthAllowedClient.allowedScopes] ou sem `openid`:
///   recusa;
/// - `redirect_uri` precisa bater exatamente (esquema, host, porta e caminho)
///   com uma das cadastradas aqui; query e fragmento não contam porque o
///   Supabase acrescenta `code`, `state` e `error`.
///
/// `client_id` não é segredo: é público por natureza (vai na URL do
/// `/oauth/authorize`). O `client_secret` NUNCA entra neste repositório.
class OAuthAllowedClient {
  final String clientId;

  /// Nome exibido ao usuário. Vem DAQUI, nunca do nome cadastrado no
  /// servidor, para que um client renomeado no painel não consiga se
  /// apresentar como outro aplicativo.
  final String displayName;

  /// URIs de retorno exatas, sem query nem fragmento.
  final List<String> redirectUris;

  final Set<String> allowedScopes;

  const OAuthAllowedClient({
    required this.clientId,
    required this.displayName,
    required this.redirectUris,
    required this.allowedScopes,
  });
}

/// Cada entrada corresponde a um client cadastrado no painel do Supabase
/// (Authentication → OAuth Apps) e revisado aqui. Lista vazia = nenhum
/// aplicativo pode usar o login.
const List<OAuthAllowedClient> kOAuthAllowedClients = <OAuthAllowedClient>[
  // Lider360 (teste) — client confidential do MVP do login único, cadastrado
  // em 23/10/2026. Sem escopo pedido; `email` tolerado caso o servidor o
  // atribua por padrão. O client de produção entra numa entrada própria.
  OAuthAllowedClient(
    clientId: 'd8e86d80-0a75-4fa2-ae2e-23c40a7f26ef',
    displayName: 'Lider360',
    redirectUris: [
      'http://localhost:3000/auth/church360/callback',
      'https://gestao-lideres-git-sso-church360-ap-bergs-projects.vercel.app/auth/church360/callback',
    ],
    allowedScopes: {'email'},
  ),
];

/// Formato aceito para o `authorization_id` antes de ele entrar na URL da API.
/// O valor vem da barra de endereço; validar o charset impede que alguém
/// injete `/`, `..` ou `?` no caminho da chamada REST.
final RegExp _authorizationIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');

bool isValidAuthorizationId(String? value) =>
    value != null && _authorizationIdPattern.hasMatch(value);

OAuthAllowedClient? findAllowedClient(
  String? clientId, {
  List<OAuthAllowedClient> allowlist = kOAuthAllowedClients,
}) {
  if (clientId == null || clientId.isEmpty) return null;
  for (final client in allowlist) {
    if (client.clientId == clientId) return client;
  }
  return null;
}

/// Todo escopo pedido precisa estar na lista do client; pedir nenhum escopo é
/// aceito (no MVP o Lider360 só confirma a identidade e não usa ID token).
/// `offline_access` é recusado sempre, mesmo que entre na lista: o Lider360
/// não deve receber refresh token do Church360.
bool scopesAllowed(String? scope, OAuthAllowedClient client) {
  final requested = (scope ?? '')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toSet();
  if (requested.contains('offline_access')) return false;
  return requested.every(client.allowedScopes.contains);
}

/// Confere uma URL de retorno (a `redirect_uri` do pedido ou a `redirect_url`
/// devolvida pela API, que já traz `code`/`state` na query) contra as URIs
/// cadastradas do client.
bool redirectAllowed(String? url, OAuthAllowedClient client) {
  final candidate = _parseRedirect(url);
  if (candidate == null) return false;
  for (final registered in client.redirectUris) {
    final expected = _parseRedirect(registered);
    if (expected == null) continue;
    if (candidate.scheme == expected.scheme &&
        candidate.host == expected.host &&
        candidate.port == expected.port &&
        candidate.path == expected.path) {
      return true;
    }
  }
  return false;
}

/// Versão para quando a API responde só com `redirect_url` (consentimento já
/// dado antes) e não informa o client: aceita se bater com QUALQUER client da
/// allowlist.
OAuthAllowedClient? clientForRedirect(
  String? url, {
  List<OAuthAllowedClient> allowlist = kOAuthAllowedClients,
}) {
  for (final client in allowlist) {
    if (redirectAllowed(url, client)) return client;
  }
  return null;
}

Uri? _parseRedirect(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return null;
  }
  if (!uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.hasFragment) return null;
  final isLoopback = uri.host == 'localhost' || uri.host == '127.0.0.1';
  if (uri.scheme == 'https') return uri;
  if (uri.scheme == 'http' && isLoopback) return uri;
  return null;
}
