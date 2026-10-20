import 'package:church360_app/features/bible/domain/models/bible_lexeme.dart';
import 'package:church360_app/features/bible/domain/models/bible_verse.dart';
import 'package:church360_app/features/bible/domain/models/bible_word_study.dart';
import 'package:church360_app/features/bible/presentation/screens/bible_reader_screen.dart';
import 'package:flutter_test/flutter_test.dart';

BibleVerse _v(int n, String text) => BibleVerse(
  id: 1000 + n,
  bookId: 43,
  chapter: 3,
  verse: n,
  text: text,
  bookName: 'João',
);

const _rodape = '\n\n— Bíblia Sagrada (ARC)';

void main() {
  group('formatVersesForCopy', () {
    test('um versículo: referência e texto, sem prefixo numérico', () {
      final out = formatVersesForCopy('João', 3, [
        _v(16, 'Porque Deus amou o mundo'),
      ]);
      expect(out, 'João 3:16\n\nPorque Deus amou o mundo$_rodape');
    });

    test('intervalo: 16-18 com um versículo por linha prefixado', () {
      final out = formatVersesForCopy('João', 3, [
        _v(16, 'a'),
        _v(17, 'b'),
        _v(18, 'c'),
      ]);
      expect(out, 'João 3:16-18\n\n16 a\n17 b\n18 c$_rodape');
    });

    test('intervalo mais versículo avulso: 16-18,21', () {
      final out = formatVersesForCopy('João', 3, [
        _v(16, 'a'),
        _v(17, 'b'),
        _v(18, 'c'),
        _v(21, 'd'),
      ]);
      expect(out, 'João 3:16-18,21\n\n16 a\n17 b\n18 c\n21 d$_rodape');
    });

    test('ordem embaralhada sai ordenada pelo número do versículo', () {
      final out = formatVersesForCopy('João', 3, [
        _v(21, 'd'),
        _v(17, 'b'),
        _v(16, 'a'),
        _v(18, 'c'),
      ]);
      expect(out, 'João 3:16-18,21\n\n16 a\n17 b\n18 c\n21 d$_rodape');
    });

    test('lista vazia não gera nada', () {
      expect(formatVersesForCopy('João', 3, const []), '');
    });
  });

  group('formatLexemeForCopy', () {
    const lexeme = BibleLexeme(
      id: 1,
      strongCode: 'G26',
      language: 'greek',
      lemma: 'ἀγαπάω',
      transliteration: 'agapaō',
      ptGloss: 'amar',
      ptDefinition: 'Amar com amor de escolha e devoção.',
      ptSource: 'UBS SDBH pt',
    );

    test('sem estudo: léxico, origem e referência', () {
      final out = formatLexemeForCopy(
        lexeme,
        null,
        surface: 'amou',
        reference: 'João 3:16',
      );
      expect(
        out,
        'G26 · “amou”\n\n'
        'ἀγαπάω (agapaō)\n\n'
        'amar\n\n'
        'Amar com amor de escolha e devoção.\n\n'
        '$ubsCreditoParaTeste\n\n'
        'João 3:16',
      );
    });

    test('com estudo: título, original, raiz e seções', () {
      final study = BibleWordStudy(
        verseId: 1016,
        titulo: 'Amar',
        language: 'greek',
        strongCodes: const ['G26'],
        palavraOriginal: 'ἀγαπάω',
        transliteracao: 'agapaō',
        raiz: 'ἀγαπη',
        raizTransliteracao: 'agapē',
        secoes: const [
          {
            'tipo': 'etimologia',
            'blocos': [
              {
                'tipo': 'lista',
                'itens': ['Significado: afeição'],
              },
              {'tipo': 'texto', 'texto': 'Uso teológico.'},
            ],
          },
        ],
      );
      final out = formatLexemeForCopy(lexeme, study);
      expect(out, contains('Amar\nἀγαπάω · agapaō\nRaiz: ἀγαπη (agapē)'));
      expect(
        out,
        contains('Etimologia\n• Significado: afeição\nUso teológico.'),
      );
      expect(out, isNot(contains('João 3:16')));
    });
  });
}

const ubsCreditoParaTeste =
    'Dicionário Semântico do Hebraico Bíblico, © Sociedades Bíblicas Unidas, CC BY-SA 4.0';
