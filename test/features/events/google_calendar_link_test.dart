import 'package:church360_app/features/events/domain/google_calendar_link.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event({String? end, String? location}) => Event(
  id: 'e1',
  name: 'Culto de Jovens',
  startDate: DateTime.parse('2026-10-10T20:00:00+00:00'),
  endDate: end == null ? null : DateTime.parse(end),
  location: location,
  createdAt: DateTime.parse('2026-10-01T00:00:00+00:00'),
);

void main() {
  test('usa a hora de parede gravada, com fuso de SP', () {
    final uri = googleCalendarLink(
      _event(end: '2026-10-10T22:30:00+00:00', location: 'Templo'),
    );
    expect(uri.queryParameters['dates'], '20261010T200000/20261010T223000');
    expect(uri.queryParameters['ctz'], 'America/Sao_Paulo');
    expect(uri.queryParameters['text'], 'Culto de Jovens');
    expect(uri.queryParameters['location'], 'Templo');
  });

  test('sem fim assume 1 hora e omite local vazio', () {
    final uri = googleCalendarLink(_event());
    expect(uri.queryParameters['dates'], '20261010T200000/20261010T210000');
    expect(uri.queryParameters.containsKey('location'), isFalse);
  });
}
