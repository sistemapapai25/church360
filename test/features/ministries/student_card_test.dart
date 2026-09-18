import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/presentation/widgets/student_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BaptismStudent _student({
  String name = 'Ana Souza',
  String? phone,
  String? turmaName = 'Sexta 19h',
  DateTime? birthDate,
  BaptismStudentStatus status = BaptismStudentStatus.ativo,
  BaptismStudentSource source = BaptismStudentSource.manual,
}) {
  return BaptismStudent(
    id: 's1',
    tenantId: 't1',
    turmaId: 'turma-1',
    fullName: name,
    phone: phone,
    birthDate: birthDate,
    status: status,
    source: source,
    createdAt: DateTime(2026, 9, 18),
    turmaName: turmaName,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('mostra nome, status e turma', (tester) async {
    await tester.pumpWidget(_host(StudentCard(student: _student())));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.text('Sexta 19h'), findsOneWidget);
  });

  testWidgets('idade e telefone aparecem na mesma linha de meta',
      (tester) async {
    final birth = DateTime(DateTime.now().year - 27, 1, 1);
    await tester.pumpWidget(_host(
      StudentCard(student: _student(phone: '(11) 91234-5678', birthDate: birth)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('27 anos · (11) 91234-5678'), findsOneWidget);
  });

  testWidgets('marca a origem do formulario publico', (tester) async {
    await tester.pumpWidget(_host(
      StudentCard(student: _student(source: BaptismStudentSource.publica)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Inscrição Pública'), findsOneWidget);
  });

  testWidgets('cadastro manual nao ganha a tag de inscricao publica',
      (tester) async {
    await tester.pumpWidget(_host(StudentCard(student: _student())));
    await tester.pumpAndSettle();

    expect(find.text('Inscrição Pública'), findsNothing);
  });

  testWidgets('sem telefone o botao de WhatsApp fica desabilitado',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(
      StudentCard(student: _student(), onWhatsApp: null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_outlined));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
  });

  testWidgets('com telefone o botao de WhatsApp dispara', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(
      StudentCard(
        student: _student(phone: '(11) 91234-5678'),
        onWhatsApp: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_outlined));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('o menu oferece so as acoes permitidas', (tester) async {
    await tester.pumpWidget(_host(
      StudentCard(student: _student(), onEdit: () {}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
  });

  testWidgets('desistente usa tom neutro, nao de erro', (tester) async {
    await tester.pumpWidget(_host(
      StudentCard(
        student: _student(status: BaptismStudentStatus.desistente),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DESISTENTE'), findsOneWidget);
    expect(
      BaptismStudentStatus.desistente.tone.color(
        tester.element(find.byType(StudentCard)),
      ),
      isNot(AppTheme.errorColor),
    );
  });
}
