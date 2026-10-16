import 'package:church360_app/features/kids/domain/kids_badges_pdf.dart';
import 'package:church360_app/features/kids/domain/models/kids_checkin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ana = KidsChildCard(
    childId: 'c1',
    name: 'Ana Júlia — 🌟',
    age: 5,
    allergies: 'Amendoim',
    foodAlert: true,
    attendanceId: 'ab12cd34-0000-0000-0000-000000000000',
    roomName: 'Maternal',
  );

  test('código de retirada: 4 primeiros do check-in, maiúsculos', () {
    expect(kidsPickupCode(ana), 'AB12');
  });

  test('gera o PDF com acento, travessão e emoji sem estourar', () async {
    final bytes = await buildKidsBadgesPdf([
      ana,
    ], eventName: 'Culto de domingo');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
