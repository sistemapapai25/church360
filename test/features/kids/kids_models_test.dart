import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/kids/domain/models/kids_attendance.dart';
import 'package:church360_app/features/kids/domain/models/kids_guardian.dart';
import 'package:church360_app/features/kids/domain/models/kids_token.dart';

void main() {
  group('KidsCheckInToken', () {
    test('isValid is true when token not used and not expired', () {
      final token = KidsCheckInToken(
        token: 'abc',
        childId: 'child-1',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        createdAt: DateTime.now(),
      );

      expect(token.isValid, isTrue);
    });

    test('isValid is false when token already used', () {
      final now = DateTime.now();
      final token = KidsCheckInToken(
        token: 'abc',
        childId: 'child-1',
        expiresAt: now.add(const Duration(minutes: 10)),
        usedAt: now,
        createdAt: now,
      );

      expect(token.isValid, isFalse);
    });

    test('isValid is false when token is expired', () {
      final now = DateTime.now();
      final token = KidsCheckInToken(
        token: 'abc',
        childId: 'child-1',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      expect(token.isValid, isFalse);
    });

    test('fromJson uses checkin as default token type', () {
      final token = KidsCheckInToken.fromJson({
        'token': 'qwerty',
        'child_id': 'child-9',
        'expires_at': '2026-04-22T19:00:00.000Z',
        'created_at': '2026-04-22T18:00:00.000Z',
      });

      expect(token.type, 'checkin');
      expect(token.eventId, isNull);
      expect(token.generatedBy, isNull);
    });
  });

  group('KidsAttendance', () {
    test('isCheckedOut is true only when checkout_time exists', () {
      final checkedInOnly = KidsAttendance.fromJson({
        'id': 'a-1',
        'child_id': 'c-1',
        'worship_service_id': 'ws-1',
        'checkin_time': '2026-04-20T09:00:00.000Z',
      });
      final checkedOut = KidsAttendance.fromJson({
        'id': 'a-2',
        'child_id': 'c-1',
        'worship_service_id': 'ws-1',
        'checkin_time': '2026-04-20T09:00:00.000Z',
        'checkout_time': '2026-04-20T11:00:00.000Z',
      });

      expect(checkedInOnly.isCheckedOut, isFalse);
      expect(checkedOut.isCheckedOut, isTrue);
    });

    test('toJson includes checkout and room fields when present', () {
      final model = KidsAttendance.fromJson({
        'id': 'a-3',
        'child_id': 'c-9',
        'worship_service_id': 'ws-3',
        'checkin_time': '2026-04-20T09:00:00.000Z',
        'checkout_time': '2026-04-20T10:30:00.000Z',
        'checkout_by': 'u-1',
        'picked_up_by': 'u-2',
        'checkout_token_id': 'tok-2',
        'room_name': 'Sala 2',
        'notes': 'Sem intercorrencias',
      });

      final json = model.toJson();
      expect(json['checkout_time'], isNotNull);
      expect(json['checkout_by'], 'u-1');
      expect(json['picked_up_by'], 'u-2');
      expect(json['room_name'], 'Sala 2');
      expect(json['notes'], 'Sem intercorrencias');
    });
  });

  group('KidsAuthorizedGuardian', () {
    test('fromJson uses default flags when omitted', () {
      final guardian = KidsAuthorizedGuardian.fromJson({
        'id': 'g-1',
        'child_id': 'c-1',
        'guardian_id': 'u-2',
        'relationship': 'uncle',
        'created_at': '2026-04-20T09:00:00.000Z',
      });

      expect(guardian.canCheckIn, isTrue);
      expect(guardian.canCheckOut, isTrue);
      expect(guardian.isTemporary, isFalse);
    });

    test('toJson serializes permission flags and validity date', () {
      final guardian = KidsAuthorizedGuardian.fromJson({
        'id': 'g-2',
        'child_id': 'c-1',
        'guardian_id': 'u-9',
        'relationship': 'grandmother',
        'can_checkin': false,
        'can_checkout': true,
        'is_temporary': true,
        'valid_until': '2026-05-20T09:00:00.000Z',
        'created_at': '2026-04-20T09:00:00.000Z',
      });

      final json = guardian.toJson();
      expect(json['can_checkin'], isFalse);
      expect(json['can_checkout'], isTrue);
      expect(json['is_temporary'], isTrue);
      expect(json['valid_until'], '2026-05-20T09:00:00.000Z');
    });
  });
}
