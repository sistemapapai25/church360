import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

EventRegistration _reg({String? token, String? qr}) => EventRegistration(
  id: 'r',
  eventId: 'e',
  memberId: 'm',
  registeredAt: DateTime(2026, 10, 19),
  checkinToken: token,
  qrCode: qr,
);

void main() {
  test('E2: token vira C360:TKT e vence o legado', () {
    expect(
      _reg(token: 'abc', qr: 'EVENT_TICKET:e:m').ticketPayload,
      'C360:TKT:abc',
    );
  });

  test('sem token, cai no legado', () {
    expect(_reg(qr: 'EVENT_TICKET:e:m').ticketPayload, 'EVENT_TICKET:e:m');
  });
}
