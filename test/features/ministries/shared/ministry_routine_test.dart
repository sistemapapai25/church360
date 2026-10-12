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
      'worship_service_id': 'ws-$id',
      'confirmed_at': confirmed ? '2026-10-12T22:00:00Z' : null,
      'worship_service': {
        'service_date': '2026-10-12',
        'service_time': '19:00:00',
      },
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
}
