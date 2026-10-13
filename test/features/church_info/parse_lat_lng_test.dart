import 'package:church360_app/features/church_info/domain/models/church_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê as coordenadas copiadas do Google Maps', () {
    expect(parseLatLng('-16.812345, -49.245678'), (-16.812345, -49.245678));
    expect(parseLatLng(' -16.8123,-49.2456 '), (-16.8123, -49.2456));
  });

  test('lê as coordenadas de um link do Google Maps', () {
    expect(
      parseLatLng('https://www.google.com/maps/@-16.8123456,-49.2456789,17z'),
      (-16.8123456, -49.2456789),
    );
  });

  test('recusa texto sem par válido', () {
    expect(parseLatLng('Avenida B, Quadra F Lote 13'), isNull);
    expect(parseLatLng('-16, -49'), isNull);
    expect(parseLatLng('95.1, 10.2'), isNull);
  });
}
