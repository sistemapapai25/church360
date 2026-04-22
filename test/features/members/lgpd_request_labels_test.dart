import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/domain/lgpd_request_labels.dart';

void main() {
  group('lgpdRequestTypeLabel', () {
    test('returns localized labels for known request types', () {
      expect(lgpdRequestTypeLabel('export'), 'Exportação de dados');
      expect(lgpdRequestTypeLabel('deletion'), 'Exclusão de dados');
      expect(lgpdRequestTypeLabel('anonymization'), 'Anonimização');
      expect(lgpdRequestTypeLabel('retention'), 'Retenção');
    });

    test('normalizes case/whitespace and keeps unknown values', () {
      expect(lgpdRequestTypeLabel('  ExPoRt  '), 'Exportação de dados');
      expect(lgpdRequestTypeLabel('custom_type'), 'custom_type');
    });
  });

  group('lgpdStatusLabel', () {
    test('returns localized labels for known statuses', () {
      expect(lgpdStatusLabel('all'), 'Todos');
      expect(lgpdStatusLabel('pending'), 'Pendente');
      expect(lgpdStatusLabel('in_review'), 'Em análise');
      expect(lgpdStatusLabel('approved'), 'Aprovada');
      expect(lgpdStatusLabel('rejected'), 'Rejeitada');
      expect(lgpdStatusLabel('completed'), 'Concluída');
    });

    test('normalizes case/whitespace and keeps unknown values', () {
      expect(lgpdStatusLabel('  PeNdInG '), 'Pendente');
      expect(lgpdStatusLabel('archived'), 'archived');
    });
  });
}
