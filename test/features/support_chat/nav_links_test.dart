import 'package:church360_app/features/support_chat/domain/nav_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('[[NAV]] vira botão e sai do texto; rota externa é ignorada', () {
    final r = parseNavLinks(
      'É o curso do Batismo. Toque abaixo.\n'
      '[[NAV]]{"label":"Abrir Batismo","route":"/ministries/abc"}\n'
      '[[NAV]]{"label":"Golpe","route":"//evil.com"}\n'
      '[[NAV]]{"label":"Fora","route":"https://evil.com"}\n'
      '[[NAV]]não é json',
    );
    expect(r.text, 'É o curso do Batismo. Toque abaixo.');
    expect(r.links, [
      {'label': 'Abrir Batismo', 'route': '/ministries/abc'},
    ]);
  });

  test('no máximo 3 botões', () {
    final r = parseNavLinks(
      List.generate(5, (i) => '[[NAV]]{"route":"/t$i"}').join('\n'),
    );
    expect(r.links.length, 3);
    expect(r.links.first['label'], 'Abrir tela');
  });
}
