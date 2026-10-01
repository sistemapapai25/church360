import 'package:church360_app/features/ministries/louvor/presentation/widgets/chordpro_view.dart';
import 'package:church360_app/features/praise/domain/chord.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

/// A coluna (acorde em cima, sílaba embaixo) que contém [lyric].
Finder _pieceOf(String lyric) =>
    find.ancestor(of: find.text(lyric), matching: find.byType(Column)).first;

void main() {
  const src = '{key: G}\n{soc}\n[G]Santo [D/F#]santo\n{eoc}\n{c: 2x}';

  testWidgets('desenha acorde em cima da letra, seção e comentário', (t) async {
    await t.pumpWidget(_wrap(const ChordProView(source: src)));
    expect(find.text('G'), findsOneWidget);
    expect(find.text('D/F#'), findsOneWidget);
    expect(find.text('Santo'), findsOneWidget);
    expect(find.text('santo'), findsOneWidget);
    expect(find.text('Refrão'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    // O acorde fica no mesmo bloco da sílaba dele.
    expect(
      find.descendant(of: _pieceOf('santo'), matching: find.text('D/F#')),
      findsOneWidget,
    );
  });

  testWidgets('transpõe só na tela', (t) async {
    await t.pumpWidget(_wrap(const ChordProView(source: src, semitones: 2)));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('E/G#'), findsOneWidget);
    expect(find.text('G'), findsNothing);
  });

  testWidgets('linha longa quebra em vez de estourar a largura', (t) async {
    const long =
        '[G]Grande é o Senhor e mui digno de [D]louvor na cidade do nosso '
        '[Em]Deus no seu santo [C]monte';
    await t.pumpWidget(_wrap(const ChordProView(source: long), width: 220));
    expect(t.takeException(), isNull);
    final top = t.getTopLeft(find.text('Grande')).dy;
    expect(t.getTopLeft(find.text('monte')).dy, greaterThan(top));
    // Acorde no meio da linha continua em cima da sílaba depois da quebra.
    expect(
      t.getTopLeft(find.text('C')).dx,
      t.getTopLeft(find.text('monte')).dx,
    );
  });

  testWidgets('tocar no acorde devolve o acorde no tom da tela', (t) async {
    Chord? tapped;
    await t.pumpWidget(
      _wrap(
        ChordProView(source: src, semitones: 2, onChordTap: (c) => tapped = c),
      ),
    );
    await t.tap(find.text('E/G#'));
    expect(tapped.toString(), 'E/G#');
  });

  testWidgets('duas colunas só quando o usuário pede e a tela é larga', (
    t,
  ) async {
    final song = List.generate(
      4,
      (i) => '{c: Parte $i}\n[G]linha um\n[D]linha dois\n[C]linha três',
    ).join('\n\n');
    await t.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    // Tela larga sem a escolha: uma coluna só.
    await t.pumpWidget(_wrap(ChordProView(source: song), width: 1000));
    expect(
      t.getTopLeft(find.text('Parte 2')).dx,
      t.getTopLeft(find.text('Parte 0')).dx,
    );
    await t.pumpWidget(
      _wrap(ChordProView(source: song, twoColumns: true), width: 1000),
    );
    final left = t.getTopLeft(find.text('Parte 0'));
    final right = t.getTopLeft(find.text('Parte 2'));
    expect(right.dx, greaterThan(left.dx + 300));
    expect(right.dy, left.dy);
  });
}
