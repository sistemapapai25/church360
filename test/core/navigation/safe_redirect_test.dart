import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/navigation/app_router.dart';

/// Trava das regras de saneamento do `?redirect=` (LINK-03 / D-04).
///
/// O valor chega pela URL e é controlável por quem monta o link, então cada
/// caso abaixo é uma regra de segurança, não um detalhe de implementação:
/// aceitar só caminho interno, nunca URL externa, nunca voltar para as
/// próprias telas de entrada (loop), e nunca lançar exceção.
void main() {
  group('safeRedirect', () {
    test('aceita caminho interno de detalhe de evento', () {
      expect(safeRedirect('/events/abc'), '/events/abc');
    });

    test('aceita a rota de inscrição (D-04)', () {
      expect(safeRedirect('/events/abc/register'), '/events/abc/register');
    });

    test('decodifica valor percent-encoded vindo da URL', () {
      expect(safeRedirect('%2Fevents%2Fabc'), '/events/abc');
    });

    test('rejeita URL absoluta externa (open redirect)', () {
      expect(safeRedirect('https://phishing.example'), isNull);
    });

    test('rejeita URL protocol-relative', () {
      expect(safeRedirect('//phishing.example'), isNull);
    });

    test('rejeita /login (loop)', () {
      expect(safeRedirect('/login'), isNull);
    });

    test('rejeita /signup (loop)', () {
      expect(safeRedirect('/signup'), isNull);
    });

    test('rejeita /splash (loop)', () {
      expect(safeRedirect('/splash'), isNull);
    });

    test('rejeita null e string vazia', () {
      expect(safeRedirect(null), isNull);
      expect(safeRedirect(''), isNull);
    });

    test('rejeita string malformada em vez de lançar FormatException', () {
      expect(safeRedirect('%'), isNull);
    });
  });
}
