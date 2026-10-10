import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/data/ministries_repository.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_team_tab.dart';
import 'package:church360_app/features/permissions/data/role_contexts_repository.dart';
import 'package:church360_app/features/permissions/domain/models/role_context.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/tags/domain/models/tag.dart';
import 'package:church360_app/features/tags/presentation/providers/tags_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

MinistryMember _member(String name, MinistryRole role, {String? cargoName}) {
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

// Batismo em 08/10: cargos ligados, mas só "Professor(a)" como função.
class _FakeContexts extends Fake implements RoleContextsRepository {
  @override
  Future<List<RoleContext>> getContextsByMinistry(String ministryId) async => [
    const RoleContext(
      id: 'c1',
      roleId: 'r1',
      contextName: 'Líder – Batismo',
      metadata: {
        'ministry_id': _ministryId,
        'functions': ['Professor(a)'],
      },
    ),
  ];
}

class _FakeMinistries extends Fake implements MinistriesRepository {
  @override
  Future<Map<String, List<String>>> getMemberFunctionsByMinistry(
    String ministryId,
  ) async => {};
}

Widget _host(
  List<MinistryMember> members, {
  bool canManage = false,
  Map<String, List<Tag>> tagsByMember = const {},
}) {
  return ProviderScope(
    overrides: [
      tagsByMemberProvider.overrideWith((ref) async => tagsByMember),
      allTagsProvider.overrideWith(
        (ref) async => {
          for (final tags in tagsByMember.values)
            for (final t in tags) t.id: t,
        }.values.toList(),
      ),
      roleContextsRepositoryProvider.overrideWithValue(_FakeContexts()),
      ministriesRepositoryProvider.overrideWithValue(_FakeMinistries()),
      allRolesProvider.overrideWith((ref) async => const []),
      ministryMembersProvider(_ministryId).overrideWith((ref) async => members),
      currentUserHasPermissionProvider(
        'ministries.manage_members',
      ).overrideWith((ref) async => canManage),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: MinistryTeamTab(ministryId: _ministryId)),
    ),
  );
}

void main() {
  testWidgets('mostra as tags da pessoa e filtra a equipe por tag', (
    tester,
  ) async {
    final visita = Tag(
      id: 't1',
      name: 'Precisa de visita',
      color: '#E53935',
      createdAt: DateTime(2026, 10, 10),
    );
    await tester.pumpWidget(
      _host(
        [_member('Ana', MinistryRole.member), _member('Bruno', MinistryRole.member)],
        tagsByMember: {
          'u-Ana': [visita],
        },
      ),
    );
    await tester.pumpAndSettle();

    // Chip no cartão da Ana + chip do filtro.
    expect(find.text('Precisa de visita'), findsNWidgets(2));
    expect(find.text('MEMBROS (2)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Precisa de visita'));
    await tester.pumpAndSettle();

    expect(find.text('MEMBROS (1)'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsNothing);
  });

  testWidgets('separa lideranca de membros', (tester) async {
    await tester.pumpWidget(
      _host([
        _member('Ana', MinistryRole.member),
        _member('Bruno', MinistryRole.leader),
        _member('Carla', MinistryRole.coordinator),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIDERANÇA (2)'), findsOneWidget);
    expect(find.text('MEMBROS (1)'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('mostra papel e cargo juntos quando os dois existem', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _member('Bruno', MinistryRole.leader, cargoName: 'Pastor'),
        _member('Ana', MinistryRole.member),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Líder · Pastor'), findsOneWidget);
    // Sem cargo, so o papel no ministerio.
    expect(find.text('Membro'), findsOneWidget);
  });

  test('subtitulo junta papel, cargos e funcoes sem repetir nome', () {
    MinistryMember m(List<String> cargos, List<String> funcs) =>
        _member('X', MinistryRole.leader).copyWith(
          cargoName: cargos.isEmpty ? null : cargos.first,
          cargoNames: cargos,
          assignedFunctions: funcs,
        );

    // Gabriel: cargo "Líder" + função individual.
    expect(
      m(['Líder'], ['Líder Auxiliar']).teamSubtitle,
      'Líder · Líder Auxiliar',
    );
    // Berg/Débora: cargo contextualizado próprio.
    expect(
      m(['Líder de Departamento'], []).teamSubtitle,
      'Líder · Líder de Departamento',
    );
    // Romullo: só o papel no ministério.
    expect(m([], []).teamSubtitle, 'Líder');
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

  testWidgets('nao oferece mais link para a ficha do ministerio', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_member('Ana', MinistryRole.member)]));
    await tester.pumpAndSettle();

    // Descricao, notificacoes e edicao subiram para o cabecalho do
    // workspace — nao sobrou nada na ficha que esta aba precise alcancar.
    expect(find.text('Abrir ficha completa do ministério'), findsNothing);
  });

  testWidgets('sem permissao nao oferece incluir nem acoes por membro', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_member('Ana', MinistryRole.member)]));
    await tester.pumpAndSettle();

    expect(find.text('Incluir membro'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('com permissao oferece incluir membro e o menu de acoes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([_member('Ana', MinistryRole.member)], canManage: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incluir membro'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Alterar função'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);
  });

  testWidgets('busca recorta a lista por nome', (tester) async {
    await tester.pumpWidget(
      _host([
        _member('Ana', MinistryRole.member),
        _member('Bruno', MinistryRole.leader),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bru');
    await tester.pumpAndSettle();

    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('busca sem resultado avisa em vez de sumir com tudo', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_member('Ana', MinistryRole.member)]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Ninguém na equipe bate com essa busca.'), findsOneWidget);
  });

  testWidgets('Alterar função cria função nova e marca, mesmo sem cargo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host([_member('Ana', MinistryRole.member)], canManage: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alterar função'));
    await tester.pumpAndSettle();

    // A lista é do ministério: aparece sem cargo escolhido.
    expect(
      find.widgetWithText(CheckboxListTile, 'Professor(a)'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Nova função'),
      'Recepção',
    );
    await tester.tap(find.byTooltip('Adicionar função'));
    await tester.pumpAndSettle();

    final nova = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Recepção'),
    );
    expect(nova.value, isTrue);
  });
}
