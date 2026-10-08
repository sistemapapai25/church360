/// Texto da resposta do agente pronto para a voz do aparelho: sem isso o TTS
/// lê "asterisco", URLs inteiras, a linha de controle `[[TRANSFER_SUGGEST]]...`
/// e a descrição dos emojis.
String textForSpeech(String text) {
  return text
      .replaceAll(RegExp(r'^\s*\[\[[A-Z_]+\]\].*$', multiLine: true), ' ')
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'https?://\S+'), ' (link na tela) ')
      .replaceAll(
        RegExp(r'^\s{0,3}(#{1,6}|>|[-*+•]|\d+\.)\s+', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'[*_~|#]+'), '')
      .replaceAll('→', ', ')
      .replaceAll(
        RegExp(
          r'[\p{Extended_Pictographic}\p{Emoji_Modifier}\p{Regional_Indicator}\u{200D}\u{FE0F}\u{20E3}]',
          unicode: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
