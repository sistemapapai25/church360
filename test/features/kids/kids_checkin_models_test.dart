import 'package:church360_app/features/kids/domain/models/kids_checkin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kids_board: culto, presentes com selos e retirados', () {
    final board = KidsBoard.fromJson({
      'event': {'id': 'e1', 'name': 'Culto de domingo'},
      'present': [
        {
          'child_id': 'c1',
          'name': 'Ana',
          'age': 5,
          'allergies': 'Amendoim',
          'food_alert': true,
          'image_consent': false,
          'missing': ['responsável'],
          'attendance_id': 'a1',
          'room_name': 'Maternal',
          'checkin_time': '2026-10-18T13:05:00Z',
        },
      ],
      'checked_out': 2,
    });

    expect(board.hasEvent, isTrue);
    expect(board.checkedOut, 2);
    final ana = board.present.single;
    expect(ana.isPresent, isTrue);
    expect(ana.foodAlert, isTrue);
    expect(ana.missing, ['responsável']);
    expect(ana.healthAlert, 'Alergia: Amendoim');
  });

  test('sem culto hoje e criança sem nome não quebram', () {
    final board = KidsBoard.fromJson({'event': null, 'present': []});
    expect(board.hasEvent, isFalse);

    final card = KidsChildCard.fromJson({'child_id': 'c2', 'name': ' '});
    expect(card.name, 'Criança');
    expect(card.isPresent, isFalse);
    expect(card.missing, isEmpty);
  });

  test('faixa da sala', () {
    expect(
      const KidsRoom(name: 'A', minAge: 3, maxAge: 5).ageLabel,
      '3 a 5 anos',
    );
    expect(const KidsRoom(name: 'B', maxAge: 2).ageLabel, 'Até 2 anos');
    expect(const KidsRoom(name: 'C').ageLabel, 'Qualquer idade');
  });
}
