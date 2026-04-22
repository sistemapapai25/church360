import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/domain/models/member.dart';

void main() {
  group('Member credential parsing', () {
    final baseJson = <String, dynamic>{
      'id': 'member-1',
      'email': 'test@example.com',
      'created_at': '2026-01-01T10:00:00.000Z',
    };

    test('parses credencial_date when present', () {
      final member = Member.fromJson({
        ...baseJson,
        'credencial_date': '2030-10-17T00:00:00.000Z',
      });

      expect(member.credentialDate, isNotNull);
      expect(member.credentialDate!.toUtc().year, 2030);
    });

    test('parses credential_date alias when present', () {
      final member = Member.fromJson({
        ...baseJson,
        'credential_date': '2031-05-01T00:00:00.000Z',
      });

      expect(member.credentialDate, isNotNull);
      expect(member.credentialDate!.toUtc().year, 2031);
    });
  });

  group('Member LGPD parsing', () {
    final baseJson = <String, dynamic>{
      'id': 'member-1',
      'email': 'test@example.com',
      'created_at': '2026-01-01T10:00:00.000Z',
    };

    test('uses lgpd_consent and lgpd_consent_at when present', () {
      final member = Member.fromJson({
        ...baseJson,
        'lgpd_consent': true,
        'lgpd_consent_at': '2026-03-01T08:30:00.000Z',
      });

      expect(member.lgpdConsent, isTrue);
      expect(member.lgpdConsentAt, isNotNull);
      expect(member.lgpdConsentAt!.toUtc().year, 2026);
      expect(member.toJson()['lgpd_consent'], isTrue);
      expect(member.toJson()['lgpd_consent_at'], isNotNull);
    });

    test('falls back to consentimento_lgpd aliases', () {
      final member = Member.fromJson({
        ...baseJson,
        'consentimento_lgpd': 'sim',
        'consentimento_lgpd_at': '2026-03-10T12:00:00.000Z',
      });

      expect(member.lgpdConsent, isTrue);
      expect(member.lgpdConsentAt, isNotNull);
      expect(member.lgpdConsentAt!.toUtc().day, 10);
    });

    test('falls back to privacy_consent aliases', () {
      final member = Member.fromJson({
        ...baseJson,
        'privacy_consent': 0,
        'privacy_consent_at': '2026-03-20T09:15:00.000Z',
      });

      expect(member.lgpdConsent, isFalse);
      expect(member.lgpdConsentAt, isNotNull);
      expect(member.lgpdConsentAt!.toUtc().month, 3);
    });
  });
}
