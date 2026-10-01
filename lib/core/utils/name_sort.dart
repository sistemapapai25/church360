/// Compara nomes para ordem alfabética em pt-BR: ignora maiúsculas e
/// acentos ("Ângela" fica junto de "Ana", não depois de "Zé").
int compareNames(String a, String b) => _fold(a).compareTo(_fold(b));

const _from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _to = 'aaaaaeeeeiiiiooooouuuucn';

String _fold(String s) {
  final lower = s.trim().toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = _from.indexOf(ch);
    out.write(i < 0 ? ch : _to[i]);
  }
  return out.toString();
}
