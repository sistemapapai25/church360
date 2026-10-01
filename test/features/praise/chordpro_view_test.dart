import 'package:church360_app/features/ministries/louvor/presentation/widgets/chordpro_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  const src = '{key: G}\n{soc}\n[G]Santo [D/F#]santo\n{eoc}\n{c: 2x}';

  testWidgets('desenha acorde em cima da letra, seção e comentário', (t) async {
    await t.pumpWidget(_wrap(const ChordProView(source: src)));
    expect(find.text('G     D/F#'), findsOneWidget);
    expect(find.text('Santo santo'), findsOneWidget);
    expect(find.text('Refrão'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
  });

  testWidgets('transpõe só na tela', (t) async {
    await t.pumpWidget(_wrap(const ChordProView(source: src, semitones: 2)));
    expect(find.text('A     E/G#'), findsOneWidget);
    expect(find.text('Santo santo'), findsOneWidget);
  });
}
