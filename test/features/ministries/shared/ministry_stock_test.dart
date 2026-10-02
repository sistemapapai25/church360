import 'package:church360_app/features/ministries/shared/domain/ministry_stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseStockQuantity lê número digitado no Brasil', () {
    expect(parseStockQuantity('2,5'), 2.5);
    expect(parseStockQuantity('1.234,5'), 1234.5);
    expect(parseStockQuantity('3'), 3);
    expect(parseStockQuantity(' -2 '), -2);
    expect(parseStockQuantity(''), isNull);
    expect(parseStockQuantity('abc'), isNull);
  });

  test('formatStockQuantity e formatStockDelta', () {
    expect(formatStockQuantity(1234.5), '1.234,5');
    expect(formatStockQuantity(3.0), '3');
    expect(formatStockDelta(500), '+500');
    expect(formatStockDelta(-1.5), '−1,5');
  });

  test('financeSides mostra só o que a pessoa pode abrir, na ordem', () {
    expect(
      financeSides(caixa: true, estoque: true, auditoria: true),
      [FinanceSide.caixa, FinanceSide.estoque, FinanceSide.auditoria],
    );
    expect(financeSides(caixa: false, estoque: true, auditoria: false), [
      FinanceSide.estoque,
    ]);
    expect(financeSides(caixa: false, estoque: false, auditoria: false), isEmpty);
  });

  test('isLow vale quando a quantidade chega no mínimo', () {
    StockItem item(double q, double? min) => StockItem(
      id: 'i',
      ministryId: 'm',
      name: 'x',
      unit: 'un',
      quantity: q,
      minQuantity: min,
    );
    expect(item(4, 4).isLow, isTrue);
    expect(item(5, 4).isLow, isFalse);
    expect(item(0, null).isLow, isFalse);
  });
}
