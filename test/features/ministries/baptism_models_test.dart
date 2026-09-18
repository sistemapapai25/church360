import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _studentJson(Map<String, dynamic> overrides) {
  return {
    'id': 's1',
    'tenant_id': 't1',
    'turma_id': 'turma-1',
    'user_id': null,
    'full_name': 'Ana Paula Souza',
    'phone': '(11) 91234-5678',
    'email': null,
    'birth_date': null,
    'status': 'ativo',
    'source': 'manual',
    'notes': null,
    'created_at': '2026-09-18T12:00:00Z',
    ...overrides,
  };
}

void main() {
  group('BaptismStudent', () {
    test('le o nome da turma do embed', () {
      final s = BaptismStudent.fromJson(
        _studentJson({
          'baptism_turma': {
            'id': 'turma-1',
            'name': 'Sexta 19h',
            'ministry_id': 'm1',
          },
        }),
      );

      expect(s.turmaName, 'Sexta 19h');
      expect(s.turmaId, 'turma-1');
    });

    test('sobrevive a consulta sem embed da turma', () {
      final s = BaptismStudent.fromJson(_studentJson({}));
      expect(s.turmaName, isNull);
    });

    test('status desconhecido cai em ativo em vez de estourar', () {
      // O CHECK do banco garante os tres valores, mas uma coluna nova ou um
      // valor legado nao pode derrubar a tela inteira.
      final s = BaptismStudent.fromJson(_studentJson({'status': 'sei-la'}));
      expect(s.status, BaptismStudentStatus.ativo);
    });

    test('idade conta aniversario ainda nao feito no ano', () {
      final now = DateTime.now();
      final aniversarioDepois = DateTime(now.year - 30, 12, 31);
      final aniversarioAntes = DateTime(now.year - 30, 1, 1);

      final depois = BaptismStudent.fromJson(
        _studentJson({'birth_date': aniversarioDepois.toIso8601String()}),
      );
      final antes = BaptismStudent.fromJson(
        _studentJson({'birth_date': aniversarioAntes.toIso8601String()}),
      );

      // Em 31/12 o de dezembro ainda nao fez aniversario (29), o de janeiro
      // ja fez (30) — exceto no proprio 31/12, quando os dois tem 30.
      expect(depois.age, now.month == 12 && now.day == 31 ? 30 : 29);
      expect(antes.age, 30);
    });

    test('sem data de nascimento a idade e nula', () {
      expect(BaptismStudent.fromJson(_studentJson({})).age, isNull);
    });

    test(
      'toWriteJson nao manda source: a origem nao pode ser forjada pela tela',
      () {
        final s = BaptismStudent.fromJson(_studentJson({'source': 'publica'}));
        expect(s.source, BaptismStudentSource.publica);
        expect(s.toWriteJson().containsKey('source'), isFalse);
      },
    );

    test('toWriteJson grava data como DATE, sem hora', () {
      final s = BaptismStudent.fromJson(
        _studentJson({'birth_date': '1995-03-07'}),
      );
      expect(s.toWriteJson()['birth_date'], '1995-03-07');
    });

    test('campos em branco viram null em vez de string vazia', () {
      final s = BaptismStudent.fromJson(_studentJson({'phone': '   '}));
      expect(s.toWriteJson()['phone'], isNull);
    });

    test('primeiro nome sai do nome completo', () {
      final s = BaptismStudent.fromJson(_studentJson({}));
      expect(s.firstName, 'Ana');
    });
  });

  group('BaptismTurma', () {
    test('le nome e data do evento vinculado', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_id': 'e1',
        'name': 'Sexta 19h',
        'description': null,
        'start_date': '2026-09-19',
        'end_date': '2026-10-24',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
        'event': {'name': 'Batismo nas Águas', 'start_date': '2026-10-25'},
      });

      expect(t.eventName, 'Batismo nas Águas');
      expect(t.eventDate, DateTime.parse('2026-10-25'));
      expect(t.startDate, DateTime.parse('2026-09-19'));
    });

    test('turma sem evento nao quebra', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_id': null,
        'name': 'Sem data',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(t.eventId, isNull);
      expect(t.eventName, isNull);
      expect(t.startDate, isNull);
      expect(t.toWriteJson()['event_id'], isNull);
    });

    test('copyWith limpa o evento so quando pedido', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_id': 'e1',
        'name': 'Sexta 19h',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(t.copyWith(name: 'Outro').eventId, 'e1');
      expect(t.copyWith(clearEventId: true).eventId, isNull);
    });
  });
}
