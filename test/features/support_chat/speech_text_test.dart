import 'package:church360_app/features/support_chat/domain/speech_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tira markdown, links, emojis e linhas de controle antes de falar', () {
    const reply = '''## Como alterar
1. Abra **Mais** → *Meu perfil* 😊
- Veja [o guia](https://exemplo.com/guia) ou https://exemplo.com
[[TRANSFER_SUGGEST]] {"candidates":[]}''';

    expect(
      textForSpeech(reply),
      'Como alterar Abra Mais , Meu perfil Veja o guia ou (link na tela)',
    );
  });

  test('texto que só tem marcador vira vazio', () {
    expect(textForSpeech('[[CONTACT_UPDATE_PROPOSAL]] {"proposalId":"x"}'), '');
  });
}
