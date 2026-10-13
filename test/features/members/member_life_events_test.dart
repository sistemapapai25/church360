import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/domain/models/member.dart';
import 'package:church360_app/features/members/presentation/widgets/member_life_events.dart';

void main() {
  test('marcos da ficha: só datas preenchidas, sem decisão nem credencial', () {
    final member = Member.fromJson({
      'id': 'member-1',
      'email': 'test@example.com',
      'created_at': '2026-01-01T10:00:00.000Z',
      'baptism_date': '2020-05-10',
      'salvation_date': '2019-01-01',
      'credencial_date': '2030-10-17T00:00:00.000Z',
    });

    final titles = memberLifeEvents(member).map((e) => e.title).toList();

    expect(titles, ['Batismo']);
  });
}
