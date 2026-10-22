import 'package:web/web.dart' as web;

bool get externalNavigationSupported => true;

/// `replace` e não `assign`: o voltar do navegador não deve reabrir a tela de
/// consentimento de um pedido que já foi decidido.
void replaceLocation(String url) {
  web.window.location.replace(url);
}
