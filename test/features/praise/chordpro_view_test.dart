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

  testWidgets('batida em setas com a contagem embaixo', (t) async {
    await t.pumpWidget(
      _wrap(
        const ChordProView(source: '{c: Intro}\n{batida: D . U}\n[G]Santo'),
      ),
    );
    expect(find.text('↓'), findsOneWidget);
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('&'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await t.pumpWidget(
      _wrap(
        const ChordProView(
          source: '{batida: D . U}\n[G]Santo',
          strums: StrumDisplay.hidden,
        ),
      ),
    );
    expect(find.text('↓'), findsNothing);
  });

  testWidgets('diagrama no corpo: 1ª vez de cada acorde em cada seção', (
    t,
  ) async {
    const src = '{c: Verso}\n[G]a [D]b [G]c\n{c: Refrão}\n[G]d';
    await t.pumpWidget(
      _wrap(ChordProView(source: src, diagramFor: (c) => Text('diagrama $c'))),
    );
    // G no verso, D no verso, G de novo no refrão.
    expect(find.text('diagrama G'), findsNWidgets(2));
    expect(find.text('diagrama D'), findsOneWidget);
  });

  testWidgets('tablatura: ocultar esconde o bloco inteiro', (t) async {
    const src = '[G]Santo\n{sot}\ne|--3--|\n{eot}\n[C]fim';
    await t.pumpWidget(_wrap(const ChordProView(source: src)));
    expect(find.text('e|--3--|'), findsOneWidget);
    await t.pumpWidget(_wrap(const ChordProView(source: src, showTabs: false)));
    expect(find.text('e|--3--|'), findsNothing);
    expect(find.text('Tablatura'), findsNothing);
    expect(find.text('fim'), findsOneWidget);
  });

  testWidgets('tablatura oculta não desalinha o ▶ das seções seguintes', (
    t,
  ) async {
    const src = '{sot}\ne|--3--|\n{eot}\n{soc}\n[C]fim\n{eoc}';
    int? played;
    await t.pumpWidget(
      _wrap(
        ChordProView(
          source: src,
          showTabs: false,
          onPlaySection: (i) => played = i,
        ),
      ),
    );
    await t.tap(find.byTooltip('Tocar Refrão'));
    expect(played, 1);
  });

  testWidgets('três colunas cortam nas estrofes', (t) async {
    final song = List.generate(
      6,
      (i) => '{c: Parte $i}\n[G]linha um\n[D]linha dois',
    ).join('\n\n');
    await t.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _wrap(
        ChordProView(source: song, twoColumns: true, columnCount: 3),
        width: 1200,
      ),
    );
    final xs = {
      for (var i = 0; i < 6; i++) t.getTopLeft(find.text('Parte $i')).dx,
    };
    expect(xs.length, 3);
  });

  testWidgets('bateria: grade só para quem lê com bateria, sem acordes', (
    t,
  ) async {
    const src = '{c: Intro}\n{bateria: caixa ..x...x.}\n[G]Santo';
    await t.pumpWidget(_wrap(const ChordProView(source: src)));
    expect(find.byType(DrumGrid), findsNothing);
    expect(find.text('G'), findsOneWidget);
    await t.pumpWidget(
      _wrap(const ChordProView(source: src, drums: true, lyricsOnly: true)),
    );
    expect(find.byType(DrumGrid), findsOneWidget);
    expect(find.text('Caixa'), findsOneWidget);
    expect(find.text('G'), findsNothing);
    expect(find.text('Santo'), findsOneWidget);
  });
}
