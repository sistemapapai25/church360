import 'package:church360_app/features/bible/domain/models/bible_word_study.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final study = BibleWordStudy.fromOccurrenceJson({
    'verse_id': 7,
    'palavra_pt': 'Laço do passarinheiro',
    'secoes': [
      {'tipo': 'contexto', 'blocos': []},
    ],
    'bible_word_study': {
      'titulo': 'Laço do passarinheiro',
      'language': 'hebrew',
      'strong_codes': ['H6341', 'H3353'],
      'secoes': [
        {'tipo': 'etimologia', 'blocos': []},
      ],
    },
  });

  test('seções da palavra vêm antes das do versículo', () {
    expect(study.secoes.map((s) => s['tipo']), ['etimologia', 'contexto']);
  });

  test('casa pelo Strong pela raiz, com zero à esquerda e letra', () {
    expect(study.matches(strongCode: 'H6341', surface: 'x'), isTrue);
    expect(study.matches(strongCode: 'H06341G', surface: 'x'), isTrue);
    expect(study.matches(strongCode: 'H634', surface: 'x'), isFalse);
  });

  test('casa pela palavra da ARC só com 4+ letras', () {
    expect(study.matches(strongCode: 'H9999', surface: 'Laço'), isTrue);
    expect(study.matches(strongCode: 'H9999', surface: 'do'), isFalse);
  });

  test('aviso de IA só quando a origem diz "com IA"', () {
    expect(study.geradoPorIa, isFalse);
    final ia = BibleWordStudy.fromOccurrenceJson({
      'verse_id': 1,
      'bible_word_study': {
        'titulo': 'Dias',
        'language': 'hebrew',
        'origem': 'Estudo palavra por palavra (gerado com IA, 20/10/2026)',
      },
    });
    expect(ia.geradoPorIa, isTrue);
  });
}
