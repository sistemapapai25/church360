import 'package:shared_preferences/shared_preferences.dart';

/// Flag local do tour de primeiro acesso.
///
/// Fica em `SharedPreferences` (já é dependência do app e é o padrão usado em
/// `supabase_constants.dart` e `developer_settings_screen.dart`) e não no
/// banco: é preferência de aparelho/navegador, não dado da igreja, e não vale
/// uma tabela nem uma migration.
///
/// A chave carrega a versão do roteiro. Quando o tour mudar de verdade, sobe
/// para `v2` e todo mundo vê o novo — sem precisar limpar nada na mão.
class OnboardingTourPrefs {
  const OnboardingTourPrefs._();

  static const String _chave = 'onboarding_tour_v1_done';

  /// `true` quando a pessoa já concluiu **ou pulou** o tour. Quem pulou não
  /// quer ver de novo; para rever existe o item na aba Mais.
  ///
  /// Qualquer falha de leitura devolve `true` — isto é deliberado: se o
  /// armazenamento local não responder (janela anônima, storage bloqueado),
  /// o pior resultado possível é o tour abrir em cima do app toda vez que a
  /// pessoa entra. Errar para o lado de não mostrar é o certo aqui.
  static Future<bool> jaConcluiu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chave) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> marcarConcluido() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, true);
    } catch (_) {
      // Sem armazenamento local não há o que gravar. O tour já foi fechado na
      // sessão atual; na próxima ele reaparece, e isso é melhor do que
      // estourar uma exceção por causa de uma preferência.
    }
  }

  /// Usado pelo "Ver tour de novo": limpa a flag para o tour poder ser
  /// reaberto de propósito.
  static Future<void> limpar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chave);
    } catch (_) {}
  }
}
