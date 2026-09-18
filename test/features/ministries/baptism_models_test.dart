import 'package:church360_app/features/ministries/batismo/domain/models/baptism_member_suggestion.dart';
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
    test('le a categoria e o periodo', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_type_code': 'batismo_nas_águas',
        'name': 'Sexta 19h',
        'description': null,
        'start_date': '2026-09-19',
        'end_date': '2026-10-24',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(t.eventTypeCode, 'batismo_nas_águas');
      expect(t.startDate, DateTime.parse('2026-09-19'));
      expect(t.endDate, DateTime.parse('2026-10-24'));
      expect(t.hasWindow, isTrue);
      expect(t.toWriteJson()['event_type_code'], 'batismo_nas_águas');
      // event_id nao e mais gravado pelo app: a coluna ainda existe no
      // banco, e nao manda-la preserva o valor legado das turmas antigas.
      expect(t.toWriteJson().containsKey('event_id'), isFalse);
    });

    test('a chave do link publico sobe e desce do json', () {
      final fechada = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'name': 'Sexta 19h',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      // Consulta antiga (ou banco sem a coluna) nao abre turma nenhuma.
      expect(fechada.acceptsPublicRegistration, isFalse);
      expect(fechada.toWriteJson()['accepts_public_registration'], isFalse);

      final aberta = BaptismTurma.fromJson({
        'id': 'turma-2',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'name': 'Domingo 9h',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
        'accepts_public_registration': true,
      });

      expect(aberta.acceptsPublicRegistration, isTrue);
      expect(aberta.toWriteJson()['accepts_public_registration'], isTrue);
      expect(
        aberta.copyWith(acceptsPublicRegistration: false)
            .acceptsPublicRegistration,
        isFalse,
      );
    });

    test('turma sem categoria nao quebra', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_type_code': null,
        'name': 'Sem data',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(t.eventTypeCode, isNull);
      expect(t.startDate, isNull);
      expect(t.hasWindow, isFalse);
      expect(t.toWriteJson()['event_type_code'], isNull);
    });

    test('copyWith limpa a categoria so quando pedido', () {
      final t = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_type_code': 'batismo_nas_águas',
        'name': 'Sexta 19h',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(t.copyWith(name: 'Outro').eventTypeCode, 'batismo_nas_águas');
      expect(t.copyWith(clearEventTypeCode: true).eventTypeCode, isNull);
    });

    group('coversEvent', () {
      final turma = BaptismTurma.fromJson({
        'id': 'turma-1',
        'tenant_id': 't1',
        'ministry_id': 'm1',
        'event_type_code': 'batismo_nas_águas',
        'name': 'Sexta 19h',
        'start_date': '2026-09-19',
        'end_date': '2026-10-25',
        'status': 'ativa',
        'created_at': '2026-09-18T12:00:00Z',
      });

      test('pega o evento da categoria dentro da janela', () {
        expect(
          turma.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-10-01T20:00:00Z'),
          ),
          isTrue,
        );
      });

      test('as duas pontas entram', () {
        expect(
          turma.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-09-19T20:00:00Z'),
          ),
          isTrue,
        );
        // A cerimonia no ultimo dia da janela conta — e o caso real de
        // producao (batismo de 25/10 fechando o curso).
        expect(
          turma.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-10-25T09:00:00Z'),
          ),
          isTrue,
        );
      });

      test('evento de 23h no ultimo dia nao escorrega para fora', () {
        // Se a comparacao convertesse para instante, as 23h de parede de
        // 25/10 virariam 26/10 e a cerimonia sairia da turma.
        expect(
          turma.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-10-25T23:00:00Z'),
          ),
          isTrue,
        );
      });

      test('fora da janela e de outra categoria ficam de fora', () {
        expect(
          turma.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-10-26T09:00:00Z'),
          ),
          isFalse,
        );
        expect(
          turma.coversEvent(
            eventTypeCode: 'culto',
            eventStart: DateTime.parse('2026-10-01T20:00:00Z'),
          ),
          isFalse,
        );
      });

      test('turma sem janela nao recolhe evento nenhum', () {
        final semJanela = turma.copyWith(clearEndDate: true);
        expect(
          semJanela.coversEvent(
            eventTypeCode: 'batismo_nas_águas',
            eventStart: DateTime.parse('2026-10-01T20:00:00Z'),
          ),
          isFalse,
        );
      });
    });

  });

  group('BaptismMemberSuggestion', () {
    test('le a ficha inteira da RPC', () {
      final m = BaptismMemberSuggestion.fromJson({
        'id': 'u1',
        'full_name': 'Ana Paula',
        'nickname': 'Aninha',
        'phone': '(11) 91234-5678',
        'email': 'ana@exemplo.com',
        'birthdate': '1990-04-12',
      });

      expect(m.displayName, 'Ana Paula');
      expect(m.birthdate, DateTime.parse('1990-04-12'));
      expect(m.subtitle, '(11) 91234-5678 · ana@exemplo.com');
    });

    test('ficha magra diz que esta magra em vez de ficar muda', () {
      // O caso comum: telefone preenchido em 21 das 199 fichas.
      final m = BaptismMemberSuggestion.fromJson({
        'id': 'u2',
        'full_name': null,
        'nickname': 'Zeca',
        'phone': null,
        'email': null,
        'birthdate': null,
      });

      expect(m.displayName, 'Zeca');
      expect(m.subtitle, 'Sem telefone ou e-mail na ficha');
      expect(m.birthdate, isNull);
    });
  });
}
