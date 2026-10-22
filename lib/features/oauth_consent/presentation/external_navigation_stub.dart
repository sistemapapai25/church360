/// O consentimento OAuth acontece no navegador. Nos apps nativos esta rota
/// não é alcançada pelo fluxo; se for, a tela informa e não navega.
bool get externalNavigationSupported => false;

void replaceLocation(String url) {
  throw UnsupportedError('Navegação externa disponível apenas no web.');
}
