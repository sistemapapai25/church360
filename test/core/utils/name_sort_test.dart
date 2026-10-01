import 'package:church360_app/core/utils/name_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordena ignorando maiúsculas e acentos', () {
    final names = ['Zé', 'ana', 'Ângela', 'Bruno', 'Érica', 'carlos'];
    names.sort(compareNames);
    expect(names, ['ana', 'Ângela', 'Bruno', 'carlos', 'Érica', 'Zé']);
  });
}
