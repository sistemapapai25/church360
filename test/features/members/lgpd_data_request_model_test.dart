import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/data/members_repository.dart';

void main() {
  group('LgpdDataRequest.fromJson', () {
    test('parses resolution fields when present', () {
      final request = LgpdDataRequest.fromJson({
        'id': 'req-1',
        'request_type': 'export',
        'status': 'completed',
        'reason': 'Solicito cópia completa',
        'resolution_notes': 'Arquivo entregue por e-mail',
        'retention_until': '2030-01-01T00:00:00.000Z',
        'requested_at': '2026-04-20T10:30:00.000Z',
        'resolved_at': '2026-04-21T16:45:00.000Z',
      });

      expect(request.id, 'req-1');
      expect(request.requestType, 'export');
      expect(request.status, 'completed');
      expect(request.reason, 'Solicito cópia completa');
      expect(request.resolutionNotes, 'Arquivo entregue por e-mail');
      expect(request.requestedAt, isNotNull);
      expect(request.resolvedAt, isNotNull);
      expect(request.retentionUntil, isNotNull);
      expect(request.resolvedAt!.toUtc().day, 21);
    });

    test('keeps nullable fields as null when values are absent or invalid', () {
      final request = LgpdDataRequest.fromJson({
        'id': 'req-2',
        'request_type': 'retention',
        'status': 'pending',
        'resolution_notes': null,
        'requested_at': 'invalid-date',
        'resolved_at': null,
      });

      expect(request.id, 'req-2');
      expect(request.requestType, 'retention');
      expect(request.status, 'pending');
      expect(request.reason, isNull);
      expect(request.resolutionNotes, isNull);
      expect(request.requestedAt, isNull);
      expect(request.resolvedAt, isNull);
      expect(request.retentionUntil, isNull);
    });

    test('accepts DateTime instances for date fields', () {
      final requestedAt = DateTime.utc(2026, 4, 22, 14, 0, 0);
      final resolvedAt = DateTime.utc(2026, 4, 23, 9, 30, 0);
      final retentionUntil = DateTime.utc(2027, 1, 1, 0, 0, 0);

      final request = LgpdDataRequest.fromJson({
        'id': 'req-3',
        'request_type': 'anonymization',
        'status': 'in_review',
        'requested_at': requestedAt,
        'resolved_at': resolvedAt,
        'retention_until': retentionUntil,
      });

      expect(request.requestedAt, requestedAt);
      expect(request.resolvedAt, resolvedAt);
      expect(request.retentionUntil, retentionUntil);
    });
  });
}
