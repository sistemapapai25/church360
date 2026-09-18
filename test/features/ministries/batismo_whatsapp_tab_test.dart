import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/dispatch/presentation/providers/dispatch_providers.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_whatsapp_tab.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

BaptismStudent _student(
  String name, {
  String turmaId = 'turma-1',
  String? turmaName = 'Sexta 19h',
  String? phone,
  BaptismStudentStatus status = BaptismStudentStatus.ativo,
}) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    phone: phone,
    status: status,
    source: BaptismStudentSource.manual,
    createdAt: DateTime(2026, 9, 18),
    turmaName: turmaName,
  );
}

BaptismTurma _turma(String id, String name) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 9, 18),
  );
}

Widget _host({
  required List<BaptismStudent> students,
  List<BaptismTurma> turmas = const [],
}) {
  return ProviderScope(
    overrides: [
      baptismStudentsProvider(_ministryId).overrideWith((ref) async => students),
      baptismTurmasProvider(_ministryId).overrideWith((ref) async => turmas),
      // Sem estes dois a aba tentaria falar com o Supabase no teste.
      ministryByIdProvider(_ministryId).overrideWith((ref) async => null),
      allMessageTemplatesProvider.overrideWith(
        (ref) async => const <MessageTemplate>[],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: BatismoWhatsAppTab(ministryId: _ministryId)),
    ),
  );
}

/// A aba abre com o bloco de mensagem inteiro antes da lista; na tela
/// padrao de teste (800x600) os alunos ficariam fora da viewport e a
/// ListView nem os construiria.
Future<void> _pumpTab(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('studentHasWhatsAppPhone', () {
    test('telefone nulo ou vazio nao serve', () {
      expect(studentHasWhatsAppPhone(_student('Ana')), isFalse);
      expect(studentHasWhatsAppPhone(_student('Ana', phone: '   ')), isFalse);
    });

    test('numero curto demais nao serve — o campo esta preenchido e nao disca',
        () {
      // "(11)" tem digito e mesmo assim nao disca: o launcher montaria
      // wa.me/5511.
      expect(studentHasWhatsAppPhone(_student('Ana', phone: '(11) ')), isFalse);
      expect(
        studentPhoneState(_student('Ana', phone: '(11) ')),
        StudentPhoneState.incomplete,
      );
      expect(
        studentPhoneState(_student('Ana')),
        StudentPhoneState.missing,
      );
    });

    test('numero ja internacional serve como esta', () {
      expect(
        studentHasWhatsAppPhone(_student('Ana', phone: '+55 11 91234-5678')),
        isTrue,
      );
    });

    test('telefone formatado serve', () {
      expect(
        studentHasWhatsAppPhone(_student('Ana', phone: '(11) 91234-5678')),
        isTrue,
      );
    });
  });

  group('renderBatismoMessage', () {
    final ana = _student(
      'Ana Souza',
      phone: '(11) 91234-5678',
      turmaName: 'Sexta 19h',
    );

    test('troca as variaveis conhecidas pelos dados do aluno', () {
      final out = renderBatismoMessage(
        'Ola, {member_nickname}! Voce esta na turma {turma_name} do '
        '{ministry_name}. Confirmo neste numero: {member_phone}?',
        student: ana,
        ministryName: 'Batismo nas Aguas',
      );

      expect(
        out,
        'Ola, Ana! Voce esta na turma Sexta 19h do Batismo nas Aguas. '
        'Confirmo neste numero: (11) 91234-5678?',
      );
    });

    test('variavel desconhecida sai em branco, nao sai crua', () {
      final out = renderBatismoMessage(
        'Aula em {event_date}.',
        student: ana,
      );

      expect(out, 'Aula em .');
    });

    test('|default: cobre o valor vazio', () {
      final semTurma = _student('Bruno Lima', turmaName: null);
      final out = renderBatismoMessage(
        'Turma: {turma_name|default:a definir}',
        student: semTurma,
      );

      expect(out, 'Turma: a definir');
    });

    test('sem nome de ministerio a variavel some, e nao vira "null"', () {
      final out = renderBatismoMessage('[{ministry_name}]', student: ana);
      expect(out, '[]');
    });
  });

  group('unresolvedBatismoVariables', () {
    test('acha o que esta aba nao sabe resolver', () {
      final found = unresolvedBatismoVariables(
        'Ola {member_nickname}, aula em {event_date} as {event_time}.',
      );
      expect(found, {'event_date', 'event_time'});
    });

    test('modelo so com variaveis conhecidas nao acusa nada', () {
      expect(
        unresolvedBatismoVariables('{member_full_name} — {turma_name}'),
        isEmpty,
      );
    });
  });

  testWidgets('a contagem de telefone e honesta', (tester) async {
    await _pumpTab(
      tester,
      _host(
        students: [
          _student('Ana Souza', phone: '(11) 91234-5678'),
          _student('Bruno Lima', phone: '(21) 98888-0000'),
          _student('Carla Dias'),
        ],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );

    expect(find.text('2 de 3 alunos ativos têm telefone'), findsOneWidget);
  });

  testWidgets('aluno sem telefone aparece com o motivo e o botao apagado', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      _host(
        students: [
          _student('Ana Souza', phone: '(11) 91234-5678'),
          _student('Carla Dias'),
        ],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );

    expect(find.text('Carla Dias'), findsOneWidget);
    expect(
      find.text('Sexta 19h · Sem telefone cadastrado'),
      findsOneWidget,
    );

    // Quem tem telefone vem primeiro na lista; o ultimo botao e o da Carla.
    final buttons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chat_outlined),
        )
        .toList();
    expect(buttons.first.onPressed, isNotNull);
    expect(buttons.last.onPressed, isNull);
  });

  testWidgets('desistente fica fora da selecao padrao', (tester) async {
    await _pumpTab(
      tester,
      _host(
        students: [
          _student('Ana Souza', phone: '(11) 91234-5678'),
          _student(
            'Bruno Lima',
            phone: '(21) 98888-0000',
            status: BaptismStudentStatus.desistente,
          ),
        ],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsNothing);
    expect(find.text('1 de 1 aluno ativo tem telefone'), findsOneWidget);
  });

  testWidgets('a previa mostra a mensagem ja com o nome do aluno', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      _host(
        students: [_student('Ana Souza', phone: '(11) 91234-5678')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );

    expect(find.text('Prévia — Ana Souza'), findsOneWidget);
    expect(find.text('Olá, Ana!'), findsOneWidget);
  });

  testWidgets('sem ninguem com telefone, o botao da fila fica desligado', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      _host(
        students: [_student('Carla Dias')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Ninguém desta seleção tem telefone'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
