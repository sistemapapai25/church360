import 'package:church360_app/core/utils/pix_br_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRC-16/CCITT-FALSE: valor de conferência do catálogo', () {
    expect(crc16Ccitt('123456789'), '29B1');
  });

  test('exemplo do Manual de Padrões do BACEN', () {
    expect(
      pixBrCode(
        key: '123e4567-e12b-12d1-a456-426655440000',
        name: 'Fulano de Tal',
        city: 'BRASILIA',
      ),
      '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000'
      '5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D',
    );
  });

  test('telefone ganha +55, nome perde acento e corta em 25', () {
    final code = pixBrCode(
      key: '(11) 91234-5678',
      keyType: 'Telefone',
      name: 'Igreja Águas Purificadoras de Goiânia',
      city: 'Aparecida de Goiânia',
    );
    expect(code, contains('0114+5511912345678'));
    expect(code, contains('5925Igreja Aguas Purificadora'));
    expect(code, contains('6015Aparecida de Go'));
    final body = code.substring(0, code.length - 4);
    expect(code.substring(code.length - 4), crc16Ccitt(body));
  });

  test('valor opcional vai no campo 54', () {
    expect(
      pixBrCode(key: '12345678901', keyType: 'CPF', name: 'X', amount: 10),
      contains('540510.00'),
    );
  });
}
