import 'dart:convert';

/// Botões de tela do Moisés: linhas `[[NAV]]{"label":"…","route":"/…"}`,
/// até 3. Só rota interna (começa com `/`, nunca `//`); quem decide se a
/// pessoa entra é o guard da rota, como em qualquer outra navegação.
({String text, List<Map<String, String>> links}) parseNavLinks(String reply) {
  const marker = '[[NAV]]';
  final links = <Map<String, String>>[];
  final kept = <String>[];
  for (final line in reply.split('\n')) {
    if (!line.trimLeft().startsWith(marker)) {
      kept.add(line);
      continue;
    }
    try {
      final d = jsonDecode(line.trim().substring(marker.length).trim());
      if (d is! Map) continue;
      final route = d['route']?.toString().trim() ?? '';
      final label = d['label']?.toString().trim() ?? '';
      if (route.startsWith('/') &&
          !route.startsWith('//') &&
          links.length < 3) {
        links.add({
          'label': label.isEmpty ? 'Abrir tela' : label,
          'route': route,
        });
      }
    } catch (_) {}
  }
  return (text: kept.join('\n').trimRight(), links: links);
}
