import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/layout/breakpoints.dart';

void main() {
  test('faixas: 640 e 900 são os cortes', () {
    expect(breakpointOf(639), Breakpoint.compact);
    expect(breakpointOf(640), Breakpoint.medium);
    expect(breakpointOf(899), Breakpoint.medium);
    expect(breakpointOf(900), Breakpoint.expanded);
  });

  test('colunas da grade: pela faixa, sem coluna abaixo de 320', () {
    expect(gridColumns(360), 1);
    expect(gridColumns(700), 2);
    expect(gridColumns(900), 2, reason: '3 colunas dariam 300 cada');
    expect(gridColumns(1000), 3);
    expect(gridColumns(1600), 3, reason: 'nunca passa de 3');
  });
}
