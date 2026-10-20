/// PIX "copia e cola" estático (BR Code, EMV MPM) do Manual de Padrões para
/// Iniciação do Pix do BACEN. Sem valor, quem paga digita o valor no banco.
///
/// [keyType] usa os rótulos de `contribution_info.pix_type` (CPF, CNPJ,
/// Email, Telefone, Aleatória) para normalizar a chave como o DICT espera.
String pixBrCode({
  required String key,
  String? keyType,
  required String name,
  String city = 'BRASIL',
  double? amount,
}) {
  final gui = _f('00', 'br.gov.bcb.pix') + _f('01', _pixKey(key, keyType));
  final payload = [
    _f('00', '01'),
    _f('26', gui),
    _f('52', '0000'),
    _f('53', '986'),
    if (amount != null && amount > 0) _f('54', amount.toStringAsFixed(2)),
    _f('58', 'BR'),
    _f('59', _ascii(name, 25)),
    _f('60', _ascii(city, 15)),
    _f('62', _f('05', '***')),
    '6304',
  ].join();
  return payload + crc16Ccitt(payload);
}

/// CRC-16/CCITT-FALSE (polinômio 0x1021, início 0xFFFF), em 4 dígitos hex.
String crc16Ccitt(String s) {
  var crc = 0xFFFF;
  for (final b in s.codeUnits) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

String _f(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

String _pixKey(String key, String? type) {
  final k = key.trim();
  final digits = k.replaceAll(RegExp(r'\D'), '');
  switch (type) {
    case 'CPF':
    case 'CNPJ':
      return digits;
    case 'Telefone':
      // Celular salvo como "(11) 9...." vira +5511 9....; já com 55 fica.
      return digits.length > 11 ? '+$digits' : '+55$digits';
    case 'Email':
    case 'Aleatória':
      return k.toLowerCase();
    default:
      return k;
  }
}

const _from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const _to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

/// Campos 59/60 só aceitam ASCII e têm tamanho máximo.
String _ascii(String s, int max) {
  final out = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = _from.indexOf(ch);
    final c = i < 0 ? ch : _to[i];
    if (c.codeUnitAt(0) < 128) out.write(c);
  }
  final r = out.toString();
  return r.length > max ? r.substring(0, max).trim() : r;
}
