import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/notifications/domain/models/notification.dart';

void main() {
  group('Notification enums', () {
    test('NotificationType.fromString returns general as fallback', () {
      expect(NotificationType.fromString('unknown_value'), NotificationType.general);
    });

    test('NotificationType.fromString maps meeting and worship reminders', () {
      expect(
        NotificationType.fromString('meeting_reminder'),
        NotificationType.meetingReminder,
      );
      expect(
        NotificationType.fromString('worship_reminder'),
        NotificationType.worshipReminder,
      );
    });

    test('NotificationStatus.fromString returns pending as fallback', () {
      expect(NotificationStatus.fromString('unknown_status'), NotificationStatus.pending);
    });
  });

  group('AppNotification model', () {
    test('fromJson/toJson preserves expected core fields', () {
      final model = AppNotification.fromJson({
        'id': 'n-1',
        'user_id': 'u-1',
        'type': 'event_reminder',
        'title': 'Evento',
        'body': 'Hoje às 20h',
        'data': {'event_id': 'e-123'},
        'status': 'pending',
        'route': '/events/e-123',
        'created_at': '2026-04-01T10:00:00.000Z',
        'updated_at': '2026-04-01T10:00:00.000Z',
        'sent_at': null,
        'read_at': null,
      });

      expect(model.type, NotificationType.eventReminder);
      expect(model.status, NotificationStatus.pending);
      expect(model.isUnread, isTrue);
      expect(model.data?['event_id'], 'e-123');

      final json = model.toJson();
      expect(json['type'], 'event_reminder');
      expect(json['status'], 'pending');
      expect(json['route'], '/events/e-123');
    });

    test('fromJson falls back to general when type is unknown', () {
      final model = AppNotification.fromJson({
        'id': 'n-2',
        'user_id': 'u-1',
        'type': 'invalid_type',
        'title': 'Aviso',
        'body': 'Mensagem',
        'data': null,
        'status': 'pending',
        'route': null,
        'created_at': '2026-04-01T10:00:00.000Z',
        'updated_at': '2026-04-01T10:00:00.000Z',
      });

      expect(model.type, NotificationType.general);
      expect(model.isUnread, isTrue);
    });
  });

  group('NotificationPreferences model', () {
    test('fromJson applies explicit values and defaults', () {
      final model = NotificationPreferences.fromJson({
        'id': 'p-1',
        'user_id': 'u-1',
        'event_reminder': false,
        'meeting_reminder': true,
        'worship_reminder': false,
        'general': true,
        'quiet_hours_enabled': true,
        'quiet_hours_start': '22:00',
        'quiet_hours_end': '06:00',
        'created_at': '2026-04-01T10:00:00.000Z',
        'updated_at': '2026-04-01T10:00:00.000Z',
      });

      expect(model.eventReminder, isFalse);
      expect(model.meetingReminder, isTrue);
      expect(model.worshipReminder, isFalse);
      expect(model.general, isTrue);
      expect(model.devotionalDaily, isTrue);
      expect(model.birthdayReminder, isTrue);
      expect(model.quietHoursEnabled, isTrue);
      expect(model.quietHoursStart, '22:00');
    });

    test('copyWith updates only provided fields', () {
      final base = NotificationPreferences.fromJson({
        'id': 'p-2',
        'user_id': 'u-2',
        'event_reminder': true,
        'meeting_reminder': true,
        'worship_reminder': true,
        'general': true,
        'created_at': '2026-04-01T10:00:00.000Z',
        'updated_at': '2026-04-01T10:00:00.000Z',
      });

      final changed = base.copyWith(
        meetingReminder: false,
        worshipReminder: false,
      );

      expect(changed.eventReminder, isTrue);
      expect(changed.meetingReminder, isFalse);
      expect(changed.worshipReminder, isFalse);
      expect(changed.general, isTrue);
    });
  });

  group('FcmToken model', () {
    test('fromJson/toJson preserves token payload', () {
      final token = FcmToken.fromJson({
        'id': 't-1',
        'user_id': 'u-1',
        'token': 'abc',
        'device_id': 'dev-1',
        'device_name': 'Pixel',
        'platform': 'android',
        'is_active': true,
        'created_at': '2026-04-01T10:00:00.000Z',
        'updated_at': '2026-04-01T10:00:00.000Z',
        'last_used_at': '2026-04-01T11:00:00.000Z',
      });

      expect(token.token, 'abc');
      expect(token.platform, 'android');
      expect(token.isActive, isTrue);

      final json = token.toJson();
      expect(json['device_id'], 'dev-1');
      expect(json['platform'], 'android');
      expect(json['is_active'], isTrue);
    });
  });
}
