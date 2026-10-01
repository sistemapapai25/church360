import 'dart:ui' as ui;

import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// B3 (manchas cinzas): num card largo o reflexo diagonal vira listra
/// vertical, e um degradê que parte de `Colors.transparent` (preto com
/// alfa 0) passa por cinza no meio. Vidro branco sobre fundo branco tem
/// que continuar branco em toda a largura.
void main() {
  testWidgets('GlassCard largo sobre branco não escurece', (tester) async {
    tester.view.physicalSize = const Size(1900, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: ColoredBox(
          color: Colors.white,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 1868,
                  height: 120,
                  child: GlassCard(child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });

    // Linha do meio, longe das bordas e da sombra.
    const y = 60;
    var darkest = 255;
    for (var x = 20; x < 1848; x++) {
      final i = (y * 1868 + x) * 4;
      final r = bytes!.getUint8(i);
      if (r < darkest) darkest = r;
    }
    // A sombra do card aparece através do vidro e tira ~8 tons (247).
    // Com o degradê partindo de preto transparente caía para 232.
    expect(darkest, greaterThanOrEqualTo(240));
  });
}
