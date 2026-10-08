import 'package:flutter/services.dart';

/// Máscara só de dígitos: cada `#` da máscara recebe um dígito, o resto é
/// literal (ex.: `###.###.###-##` para CPF). Dígitos além da máscara somem.
class DigitMaskTextInputFormatter extends TextInputFormatter {
  final String mask;

  DigitMaskTextInputFormatter(this.mask);

  /// Aplica a máscara a um texto já existente (ex.: valor vindo do banco).
  String format(String text) => _applyMask(text.replaceAll(RegExp(r'\D'), ''));

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final masked = _applyMask(digits);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  String _applyMask(String digits) {
    if (digits.isEmpty) return '';
    final out = StringBuffer();
    var di = 0;
    for (var i = 0; i < mask.length; i++) {
      final m = mask[i];
      if (m == '#') {
        if (di >= digits.length) break;
        out.write(digits[di]);
        di++;
        continue;
      }
      if (di < digits.length) {
        out.write(m);
      } else {
        break;
      }
    }
    return out.toString();
  }
}
