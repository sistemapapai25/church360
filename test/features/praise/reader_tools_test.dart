import 'package:church360_app/features/ministries/louvor/presentation/widgets/reader_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('painel arrasta pelo cabeçalho e não sai da tela', (t) async {
    SharedPreferences.setMockInitialValues({});
    const area = Size(400, 600);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.fromSize(
            size: area,
            child: Stack(
              children: [
                FloatingTool(
                  area: area,
                  initial: const Offset(12, 12),
                  prefsKey: 'pos',
                  child: TunerPanel(onClose: () {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Positioned pos() => t.widget<Positioned>(
      find
          .ancestor(
            of: find.text('Afinador'),
            matching: find.byType(Positioned),
          )
          .first,
    );

    await t.drag(find.text('Afinador'), const Offset(-100, -50));
    await t.pump();
    expect(pos().right, closeTo(112, 1));
    expect(pos().bottom, closeTo(62, 1));

    // Puxado para fora, fica preso na borda com o cabeçalho visível.
    await t.drag(find.text('Afinador'), const Offset(-2000, -2000));
    await t.pump();
    expect(pos().right, 400 - 288);
    expect(pos().bottom, 600 - 56);

    // Solto o painel, a posição fica salva para a próxima abertura.
    final saved = (await SharedPreferences.getInstance()).getStringList('pos');
    expect(saved, ['${400 - 288.0}', '${600 - 56.0}']);
  });
}
