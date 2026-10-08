import 'package:church360_app/core/utils/digit_mask_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cpf = DigitMaskTextInputFormatter('###.###.###-##');

  test('format aplica a máscara de CPF a valor cru do banco', () {
    expect(cpf.format('12345678901'), '123.456.789-01');
    expect(cpf.format('123.456.789-01'), '123.456.789-01');
    expect(cpf.format(''), '');
  });

  test('digitação ignora letras e corta além de 11 números', () {
    final out = cpf.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '123abc45678901999'),
    );
    expect(out.text, '123.456.789-01');
  });
}
