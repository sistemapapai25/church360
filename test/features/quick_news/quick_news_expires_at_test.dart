import 'package:flutter_test/flutter_test.dart';
import 'package:church360_app/features/quick_news/domain/models/quick_news.dart';

void main() {
  test('expires_at volta do banco como o mesmo instante, em hora local', () {
    final local = DateTime(2026, 10, 10, 20, 0);
    final news = QuickNews.fromJson({
      'id': '1',
      'title': 't',
      'description': 'd',
      'created_by': 'u',
      'created_at': '2026-10-10T00:00:00+00:00',
      'updated_at': '2026-10-10T00:00:00+00:00',
      // O que o repositório grava: instante real em UTC.
      'expires_at': local.toUtc().toIso8601String(),
    });
    expect(news.expiresAt!.isUtc, isFalse);
    expect(news.expiresAt, local);
  });
}
