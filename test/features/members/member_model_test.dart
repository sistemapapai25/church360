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

  group('Ficha do Raízes (004800)', () {
    final baseJson = <String, dynamic>{
      'id': 'member-1',
      'email': 'test@example.com',
      'created_at': '2026-01-01T10:00:00.000Z',
    };

    test('lê e devolve os campos do visitante', () {
      final member = Member.fromJson({
        ...baseJson,
        'invited_by': 'Maria',
        'first_visit_event_id': 'ev-1',
        'wants_visit': true,
        'wants_life_house': false,
        'visitor_profiles': ['casais', 'jovens'],
        'decision_type': 'reconciliation',
      });

      expect(member.invitedBy, 'Maria');
      expect(member.visitorProfiles, ['casais', 'jovens']);
      final json = member.toJson();
      expect(json['first_visit_event_id'], 'ev-1');
      expect(json['wants_visit'], isTrue);
      expect(json['wants_life_house'], isFalse);
      expect(json['decision_type'], 'reconciliation');
    });

    test('sem os campos, perfil vem vazio e não nulo', () {
      final member = Member.fromJson(baseJson);
      expect(member.visitorProfiles, isEmpty);
      expect(member.toJson()['visitor_profiles'], isEmpty);
    });
  });
}
