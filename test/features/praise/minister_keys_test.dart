import 'package:church360_app/features/ministries/louvor/data/praise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Espontâneo: agrupa tons por música, mais usado primeiro', () {
    final h = praiseKeyHistory([
      (songId: 's1', key: 'G', at: DateTime(2026, 8, 1)),
      (songId: 's1', key: 'G', at: DateTime(2026, 9, 1)),
      (songId: 's1', key: 'G', at: DateTime(2026, 7, 1)),
      (songId: 's1', key: 'A', at: DateTime(2026, 9, 20)),
      (songId: 's2', key: 'D', at: DateTime(2026, 9, 1)),
    ]);

    expect(h['s1']!.map((u) => '${u.key}${u.times}'), ['G3', 'A1']);
    expect(h['s1']!.first.last, DateTime(2026, 9, 1));
    expect(h['s2']!.single.key, 'D');
    // Destaque é o mais recente, não o mais frequente.
    expect(praiseLatestKey(h['s1']!).key, 'A');
  });
}
