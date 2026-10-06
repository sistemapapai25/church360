import 'package:church360_app/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tipos atendidos somam os contextos; sem lista, atende tudo', () {
    final served = servedEventTypes([
      {
        'schedule_rules': {
          'event_types': ['aula'],
        },
      },
      null,
      {
        'schedule_rules': {
          'event_types': ['aula', 'ensaio'],
        },
      },
    ]);
    expect(served, ['aula', 'ensaio']);
    expect(servesEventType(served, 'aula'), isTrue);
    expect(servesEventType(served, 'culto_normal'), isFalse);
    expect(servesEventType(const [], 'qualquer'), isTrue);
  });

  test('evento sem tipo conta como culto_normal', () {
    expect(servesEventType(['culto_normal'], null), isTrue);
    expect(servesEventType(['culto_normal'], ''), isTrue);
    expect(servesEventType(['aula'], null), isFalse);
  });
}
