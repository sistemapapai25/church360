import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/domain/models/course_purchase.dart';
import 'package:church360_app/features/courses/presentation/hub/course_hub.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_purchase_card.dart';

final _course = Course(
  id: 'c1',
  title: 'Curso pago',
  isPaid: true,
  price: 50,
  paymentInfo: 'PIX chave kit@igreja',
  courseType: CourseType.onlineRecorded,
  createdAt: DateTime(2026, 10, 1),
);

CoursePurchase _purchase(String status, {String? notes}) => CoursePurchase(
  id: 'p1',
  courseId: 'c1',
  userId: 'u1',
  status: status,
  amount: 50,
  receiptPath: 't/u1/c1/1.png',
  notes: notes,
  createdAt: DateTime(2026, 10, 14),
);

Widget _host({
  required CourseHubState hub,
  CoursePurchase? purchase,
}) => ProviderScope(
  overrides: [
    courseHubProvider.overrideWith((ref, id) async => hub),
    myCoursePurchaseProvider.overrideWith((ref, id) async => purchase),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: CoursePurchaseCard(course: _course)),
    ),
  ),
);

void main() {
  const visitor = CourseHubState(management: false);

  testWidgets('sem compra: valor, PIX e botão de enviar comprovante', (
    tester,
  ) async {
    await tester.pumpWidget(_host(hub: visitor));
    await tester.pumpAndSettle();

    expect(find.text('Valor: R\$ 50.00'), findsOneWidget);
    expect(find.text('PIX chave kit@igreja'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-receipt')), findsOneWidget);
    expect(find.text('Enviar comprovante do PIX'), findsOneWidget);
  });

  testWidgets('pendente: em análise, sem botão', (tester) async {
    await tester.pumpWidget(
      _host(hub: visitor, purchase: _purchase('pending')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Comprovante em análise'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-receipt')), findsNothing);
  });

  testWidgets('recusada: motivo e "Enviar outro comprovante"', (tester) async {
    await tester.pumpWidget(
      _host(hub: visitor, purchase: _purchase('rejected', notes: 'valor errado')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comprovante recusado: valor errado'), findsOneWidget);
    expect(find.text('Enviar outro comprovante'), findsOneWidget);
  });

  testWidgets('aprovada: pagamento confirmado, sem botão', (tester) async {
    await tester.pumpWidget(
      _host(hub: visitor, purchase: _purchase('approved')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pagamento confirmado'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-receipt')), findsNothing);
  });

  testWidgets('quem gerencia o curso não vê o botão', (tester) async {
    await tester.pumpWidget(
      _host(hub: const CourseHubState(management: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Valor: R\$ 50.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-receipt')), findsNothing);
  });
}
