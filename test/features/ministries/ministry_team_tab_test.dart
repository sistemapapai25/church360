import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_team_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

MinistryMember _member(
  String name,
  MinistryRole role, {
  String? cargoName,
}) {
  final now = DateTime(2026, 9, 18);
  return MinistryMember(
    id: 'mm-$name',
    ministryId: _ministryId,
    memberId: 'u-$name',
    memberName: name,
    role: role,
    joinedAt: now,
    createdAt: now,
    cargoName: cargoName,
  );
}

Widget _host(List<MinistryMember> members) {
  return ProviderScope(
    overrides: [
      ministryMembersProvider(_ministryId).overrideWith((ref) async => members),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: MinistryTeamTab(ministryId: _ministryId)),
    ),
  );
}

void main() {
  testWidgets('separa lideranca de membros', (tester) async {
    await tester.pumpWidget(_host([
      _member('Ana', MinistryRole.member),
      _member('Bruno', MinistryRole.leader),
      _member('Carla', MinistryRole.coordinator),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('LIDERANÇA (2)'), findsOneWidget);
    expect(find.text('MEMBROS (1)'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('mostra papel e cargo juntos quando os dois existem',
      (tester) async {
    await tester.pumpWidget(_host([
      _member('Bruno', MinistryRole.leader, cargoName: 'Pastor'),
      _member('Ana', MinistryRole.member),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Líder · Pastor'), findsOneWidget);
    // Sem cargo, so o papel no ministerio.
    expect(find.text('Membro'), findsOneWidget);
  });

  testWidgets('estado vazio quando nao ha ninguem vinculado', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum membro vinculado a este ministério ainda.'),
      findsOneWidget,
    );
    expect(find.text('LIDERANÇA (0)'), findsNothing);
  });

  testWidgets('oferece o caminho para a ficha completa', (tester) async {
    await tester.pumpWidget(_host([_member('Ana', MinistryRole.member)]));
    await tester.pumpAndSettle();

    // A aba e so leitura: cadastrar membro e escala continuam na ficha, e o
    // usuario precisa de um caminho visivel ate la.
    expect(find.text('Abrir ficha completa do ministério'), findsOneWidget);
  });
}
