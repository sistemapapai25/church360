import 'package:church360_app/features/events/domain/models/event_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  EventUpdate change(List<Map<String, dynamic>> changes) =>
      EventUpdate.fromJson({
        'id': 'u1',
        'event_id': 'e1',
        'kind': 'change',
        'changes': changes,
        'created_at': '2026-10-06T12:00:00+00:00',
      });

  test(
    'mesmo dia: "Horário alterado — de 19:00 para 19:30" (parede-como-UTC)',
    () {
      final u = change([
        {
          'field': 'start_date',
          'old_value': '2026-10-10T19:00:00+00:00',
          'new_value': '2026-10-10T19:30:00+00:00',
        },
      ]);
      expect(u.changeTitle, 'Horário alterado');
      expect(u.changes.single.fromTo, 'de 19:00 para 19:30');
    },
  );

  test('dia diferente vira "Data alterada" com a data', () {
    final c = change([
      {
        'field': 'start_date',
        'old_value': '2026-10-10T19:00:00+00:00',
        'new_value': '2026-10-11T19:00:00+00:00',
      },
    ]).changes.single;
    expect(c.title, 'Data alterada');
    expect(c.fromTo, 'de 10/10 às 19:00 para 11/10 às 19:00');
  });

  test('vários campos: título genérico; nulos e status legíveis', () {
    final u = change([
      {'field': 'location', 'old_value': null, 'new_value': 'Templo'},
      {'field': 'status', 'old_value': 'published', 'new_value': 'cancelled'},
    ]);
    expect(u.changeTitle, 'Evento atualizado');
    expect(u.changes[0].fromTo, 'de sem local para Templo');
    expect(u.changes[1].title, 'Evento cancelado');
    expect(u.changes[1].fromTo, 'de Publicado para Cancelado');
  });

  test('tempo relativo e cabeçalho de dia', () {
    final now = DateTime(2026, 10, 6, 15);
    expect(
      eventUpdateTimeAgo(DateTime(2026, 10, 6, 14, 58), now: now),
      'há 2 min',
    );
    expect(eventUpdateTimeAgo(DateTime(2026, 10, 6, 9), now: now), 'há 6 h');
    expect(eventUpdateTimeAgo(DateTime(2026, 10, 5, 23), now: now), 'ontem');
    expect(eventUpdateDayHeader(DateTime(2026, 10, 6, 1), now: now), 'HOJE');
    expect(eventUpdateDayHeader(DateTime(2026, 10, 5, 1), now: now), 'ONTEM');
    expect(
      eventUpdateDayHeader(DateTime(2026, 10, 1), now: now),
      '1 DE OUTUBRO',
    );
  });
}
