import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_checklist_progress.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_checklist.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_checklist_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/widgets/student_card.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

BaptismStudent _student(
  String name, {
  String turmaId = 'turma-1',
  BaptismStudentStatus status = BaptismStudentStatus.ativo,
}) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    status: status,
    source: BaptismStudentSource.manual,
    createdAt: DateTime(2026, 9, 18),
  );
}

BaptismChecklistItem _item(
  String id, {
  String? title,
  String? turmaId,
  int order = 0,
  bool active = true,
}) {
  return BaptismChecklistItem(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    turmaId: turmaId,
    title: title ?? 'Etapa $id',
    orderIndex: order,
    isActive: active,
    createdAt: DateTime(2026, 9, 18),
  );
}

BaptismChecklistEntry _entry(String studentId, String itemId) {
  return BaptismChecklistEntry(
    id: '$studentId-$itemId',
    tenantId: 't1',
    studentId: studentId,
    itemId: itemId,
    doneAt: DateTime(2026, 9, 18),
  );
}

BaptismTurma _turma(String id, String name) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 9, 1),
  );
}

Widget _host({
  required List<BaptismStudent> students,
  required List<BaptismChecklistItem> items,
  required List<BaptismChecklistEntry> entries,
  List<BaptismTurma> turmas = const [],
  bool canEdit = true,
}) {
  return ProviderScope(
    overrides: [
      baptismStudentsProvider(_ministryId).overrideWith((ref) async => students),
      baptismTurmasProvider(_ministryId).overrideWith((ref) async => turmas),
      baptismChecklistItemsProvider(_ministryId)
          .overrideWith((ref) async => items),
      baptismChecklistEntriesProvider(_ministryId)
          .overrideWith((ref) async => entries),
      ministryByIdProvider(_ministryId).overrideWith((ref) async => null),
      for (final action in BaptismWriteAction.values)
        baptismCanWriteProvider((ministryId: _ministryId, action: action))
            .overrideWith((ref) async => canEdit),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: BatismoChecklistTab(ministryId: _ministryId)),
    ),
  );
}

/// A `ListView` não constrói o que fica fora da viewport, e a de teste é
/// 800x600. Sem `setSurfaceSize` os cards de baixo simplesmente não existem
/// na árvore e o teste falha por motivo errado.
Future<void> _pumpTab(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('BaptismChecklistItem', () {
    test('etapa sem turma vale para qualquer turma', () {
      final item = _item('i1');
      expect(item.appliesToTurma('turma-1'), isTrue);
      expect(item.appliesToTurma('turma-9'), isTrue);
    });

    test('etapa de turma vale só para a dela', () {
      final item = _item('i1', turmaId: 'turma-1');
      expect(item.appliesToTurma('turma-1'), isTrue);
      expect(item.appliesToTurma('turma-2'), isFalse);
    });

    test('toWriteJson manda o que o banco espera e nada mais', () {
      final json = _item('i1', title: '  Entrevista  ', order: 3).toWriteJson();

      expect(json['ministry_id'], _ministryId);
      expect(json['title'], 'Entrevista');
      expect(json['order_index'], 3);
      expect(json['is_active'], isTrue);
      expect(json['turma_id'], isNull);
      // id, tenant_id e created_at são do banco.
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('tenant_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });

    test('fromJson aceita as colunas reais', () {
      final item = BaptismChecklistItem.fromJson({
        'id': 'i1',
        'tenant_id': 't1',
        'ministry_id': _ministryId,
        'turma_id': null,
        'title': 'Aula 1',
        'description': 'Primeira aula',
        'order_index': 2,
        'is_active': false,
        'created_at': '2026-09-18T10:00:00Z',
      });

      expect(item.title, 'Aula 1');
      expect(item.orderIndex, 2);
      expect(item.isActive, isFalse);
      expect(item.scopeLabel, 'Todas as turmas');
    });
  });

  group('buildBaptismChecklistProgress', () {
    test('conta só as etapas que se aplicam ao aluno', () {
      final progress = buildBaptismChecklistProgress(
        students: [_student('Ana'), _student('Bruno', turmaId: 'turma-2')],
        items: [
          _item('geral'),
          _item('so-t1', turmaId: 'turma-1'),
        ],
        entries: [_entry('id-Ana', 'geral')],
      );

      final ana = progress.first;
      final bruno = progress.last;

      expect(ana.total, 2);
      expect(ana.done, 1);
      // Bruno é da turma-2: a etapa da turma-1 não entra no denominador
      // dele.
      expect(bruno.total, 1);
      expect(bruno.done, 0);
    });

    test('etapa desligada sai do denominador', () {
      final progress = buildBaptismChecklistProgress(
        students: [_student('Ana')],
        items: [_item('i1'), _item('i2', active: false)],
        entries: [_entry('id-Ana', 'i1')],
      );

      expect(progress.single.total, 1);
      expect(progress.single.isComplete, isTrue);
    });

    test('marcação de etapa que não se aplica não infla o progresso', () {
      // O caso real: o aluno cumpriu uma etapa da turma-1 e depois foi
      // movido para a turma-2. A linha continua no banco.
      final progress = buildBaptismChecklistProgress(
        students: [_student('Ana', turmaId: 'turma-2')],
        items: [_item('geral'), _item('so-t1', turmaId: 'turma-1')],
        entries: [_entry('id-Ana', 'so-t1')],
      );

      expect(progress.single.total, 1);
      expect(progress.single.done, 0);
    });

    test('sem etapa aplicável o progresso é 0, não 1', () {
      final progress = buildBaptismChecklistProgress(
        students: [_student('Ana')],
        items: const [],
        entries: const [],
      );

      expect(progress.single.total, 0);
      expect(progress.single.ratio, 0);
      expect(progress.single.isComplete, isFalse);
    });

    test('ordena por order_index e desempata pelo título', () {
      final progress = buildBaptismChecklistProgress(
        students: [_student('Ana')],
        items: [
          _item('c', title: 'Zeta', order: 1),
          _item('a', title: 'Alfa', order: 1),
          _item('b', title: 'Primeira', order: 0),
        ],
        entries: const [],
      );

      expect(
        progress.single.items.map((i) => i.title).toList(),
        ['Primeira', 'Alfa', 'Zeta'],
      );
    });

    test('tally reduz a feitas/total por aluno', () {
      final tally = baptismChecklistTallyByStudent(
        buildBaptismChecklistProgress(
          students: [_student('Ana'), _student('Bruno')],
          items: [_item('i1'), _item('i2')],
          entries: [_entry('id-Ana', 'i1')],
        ),
      );

      expect(tally['id-Ana'], (done: 1, total: 2));
      expect(tally['id-Bruno'], (done: 0, total: 2));
    });
  });

  group('BatismoChecklistTab', () {
    testWidgets('sem etapa cadastrada explica o que a aba faz', (tester) async {
      await _pumpTab(
        tester,
        _host(
          students: [_student('Ana')],
          items: const [],
          entries: const [],
        ),
      );

      expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
      // Nome de aluno não aparece: sem etapa não há o que marcar.
      expect(find.text('Ana'), findsNothing);
    });

    testWidgets('lista os alunos com o progresso de cada um', (tester) async {
      await _pumpTab(
        tester,
        _host(
          students: [_student('Ana'), _student('Bruno')],
          items: [_item('i1'), _item('i2')],
          entries: [_entry('id-Ana', 'i1')],
          turmas: [_turma('turma-1', 'Sexta 19h')],
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('expandir mostra as etapas daquele aluno', (tester) async {
      await _pumpTab(
        tester,
        _host(
          students: [_student('Ana')],
          items: [_item('i1', title: 'Entrevista'), _item('i2', title: 'Aula 1')],
          entries: [_entry('id-Ana', 'i1')],
        ),
      );

      expect(find.text('Entrevista'), findsNothing);
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Entrevista'), findsOneWidget);
      expect(find.text('Aula 1'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('sem baptism.edit o "Marcar tudo" não aparece', (tester) async {
      await _pumpTab(
        tester,
        _host(
          students: [_student('Ana')],
          items: [_item('i1')],
          entries: const [],
          canEdit: false,
        ),
      );

      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      // A etapa continua visível — quem não edita precisa enxergar o que
      // já foi cumprido.
      expect(find.text('Etapa i1'), findsOneWidget);
      expect(find.text('Marcar tudo'), findsNothing);
    });

    testWidgets('aluno de turma sem etapa aplicável diz isso', (tester) async {
      await _pumpTab(
        tester,
        _host(
          students: [_student('Bruno', turmaId: 'turma-2')],
          items: [_item('i1', turmaId: 'turma-1')],
          entries: const [],
        ),
      );

      await tester.tap(find.text('Bruno'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhuma etapa se aplica à turma deste aluno.'),
        findsOneWidget,
      );
    });
  });

  group('StudentCard com checklist', () {
    Widget host(({int done, int total})? checklist) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StudentCard(student: _student('Ana'), checklist: checklist),
        ),
      );
    }

    testWidgets('mostra a pílula de etapas quando há checklist', (tester) async {
      await tester.pumpWidget(host((done: 2, total: 5)));
      await tester.pumpAndSettle();

      expect(find.text('2/5 etapas'), findsOneWidget);
    });

    testWidgets('sem checklist ou com total zero não mostra nada',
        (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pumpAndSettle();
      expect(find.textContaining('etapas'), findsNothing);

      await tester.pumpWidget(host((done: 0, total: 0)));
      await tester.pumpAndSettle();
      expect(find.textContaining('etapas'), findsNothing);
    });
  });
}
