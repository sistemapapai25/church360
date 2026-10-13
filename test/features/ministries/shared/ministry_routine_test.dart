import 'package:church360_app/features/ministries/shared/domain/ministry_routine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _check(
  String id,
  String stage,
  int order,
  String title, {
  bool done = false,
}) => {
  'id': id,
  'stage': stage,
  'sort_order': order,
  'title': title,
  'done': done,
};

RoutineRun _run(String id, {bool confirmed = true, required List checks}) =>
    RoutineRun.fromJson({
      'id': id,
      'event_id': 'ev-$id',
      'confirmed_at': confirmed ? '2026-10-12T22:00:00Z' : null,
      'event': {'name': 'Culto Domingo', 'start_date': '2026-10-12T19:00:00Z'},
      'ministry_routine_check': checks,
    });

void main() {
  test('a rotina lê o culto e ordena os itens por etapa e ordem', () {
    final r = _run(
      'a',
      checks: [
        _check('3', 'pos', 1, 'Trancar portas', done: true),
        _check('2', 'durante', 1, 'Recepção'),
        _check('1', 'pre', 2, 'Luzes', done: true),
        _check('0', 'pre', 1, 'Oração'),
      ],
    );
    expect([for (final c in r.checks) c.id], ['0', '1', '2', '3']);
    expect(r.doneCount, 2);
    expect(r.confirmed, isTrue);
    expect(r.serviceDate, DateTime(2026, 10, 12));
  });

  test('o que mais fica sem fazer conta só as rotinas confirmadas', () {
    final runs = [
      _run(
        'a',
        checks: [
          _check('1', 'pre', 1, 'Luzes'),
          _check('2', 'pre', 2, 'Água', done: true),
        ],
      ),
      _run(
        'b',
        checks: [_check('3', 'pre', 1, 'Luzes'), _check('4', 'pre', 2, 'Água')],
      ),
      // Aberta: não entra no relatório.
      _run('c', confirmed: false, checks: [_check('5', 'pre', 1, 'Água')]),
    ];
    expect(mostMissedRoutineItems(runs), [('Luzes', 2, 2), ('Água', 1, 2)]);
  });

  test('a entrega das ofertas vem junto da rotina (objeto ou lista)', () {
    Map<String, dynamic> base(Object? off) => {
      'id': 'r',
      'event_id': 'ev',
      'ministry_routine_check': const [],
      'ministry_offering_delivery': off,
    };
    final off = {
      'id': 'd',
      'envelopes': 12,
      'cash_amount': 345.5,
      'delivered_by_1': 'u1',
      'received_by': 't1',
      'received_confirmed_at': '2026-10-13T01:00:00Z',
    };
    for (final shape in [
      off,
      [off],
    ]) {
      final o = RoutineRun.fromJson(base(shape)).offering!;
      expect(o.envelopes, 12);
      expect(o.cashAmount, 345.5);
      expect(o.received, isTrue);
    }
    expect(RoutineRun.fromJson(base(null)).offering, isNull);
    expect(RoutineRun.fromJson(base(const [])).offering, isNull);
  });

  test('valor em reais: lê com vírgula ou ponto e escreve no padrão BR', () {
    expect(parseReais('1.234,50'), 1234.5);
    expect(parseReais('345,5'), 345.5);
    expect(parseReais('345.50'), 345.5);
    expect(parseReais(r'R$ 10'), 10);
    expect(parseReais('  '), isNull);
    // O intl põe espaço sem quebra entre o símbolo e o número.
    expect(formatReais(1234.5).replaceAll(' ', ' '), r'R$ 1.234,50');
    expect(formatReais(null), '—');
  });
  test('culto da Agenda: hora de parede e itens validados', () {
    final run = RoutineRun.fromJson({
      'id': 'r',
      'event_id': 'ev',
      'event': {
        'name': 'Culto Quarta',
        'start_date': '2026-10-15T19:30:00+00:00',
      },
      'ministry_routine_check': [
        {
          'id': 'a',
          'stage': 'pre',
          'done': true,
          'validated_at': '2026-10-15T20:00:00Z',
        },
        {'id': 'b', 'stage': 'pre', 'done': true},
        {'id': 'c', 'stage': 'pos', 'done': false},
      ],
    });
    // 19:30 "UTC" é 19:30 de parede: não converte fuso.
    expect(run.serviceDate, DateTime(2026, 10, 15));
    expect(run.serviceTime, '19:30');
    expect(run.serviceName, 'Culto Quarta');
    expect(run.doneCount, 2);
    expect(run.validatedCount, 1);
  });
}
