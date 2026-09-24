import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/presentation/screens/generic_ministry_home_screen.dart';
import 'package:church360_app/features/ministries/shared/domain/ministry_contact.dart';
import 'package:church360_app/features/ministries/shared/presentation/providers/ministry_finance_providers.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_notices_tab.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 24);

Ministry _ministry() => Ministry(
  id: 'm1',
  name: 'Som das Águas',
  description: 'Equipe de som',
  icon: 'church',
  color: '0xFF2563EB',
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

MinistryMember _member({
  required String name,
  String? phone,
  MinistryRole role = MinistryRole.member,
}) => MinistryMember(
  id: 'mm-$name',
  ministryId: 'm1',
  memberId: 'u-$name',
  memberName: name,
  role: role,
  joinedAt: _now,
  createdAt: _now,
  phone: phone,
);

Override _permission(String code, bool value) =>
    currentUserHasPermissionProvider(code).overrideWith((ref) async => value);

/// Overrides comuns: sem visão global, e o vínculo decidido por
/// [linked] — é a régua de escopo do workspace.
List<Override> _base({
  required bool linked,
  List<MinistryMember> members = const [],
}) => [
  ministryByIdProvider('m1').overrideWith((ref) async => _ministry()),
  currentMemberMinistriesProvider.overrideWith(
    (ref) async => linked ? [_ministry()] : <Ministry>[],
  ),
  ministryMembersProvider('m1').overrideWith((ref) async => members),
  ministrySchedulesProvider('m1').overrideWith((ref) async => []),
  ministryFinanceAccessProvider(
    'm1',
  ).overrideWith((ref) async => MinistryFinanceAccess.none),
  // As cinco que compõem a visão global — todas falsas: quem abre a tela
  // nestes testes é o vínculo, não o cargo.
  _permission('ministries.view_all', false),
  _permission('ministries.manage', false),
  _permission('ministries.create', false),
  _permission('ministries.edit', false),
  _permission('ministries.delete', false),
  _permission('ministries.manage_members', false),
  _permission('ministries.manage_schedule', false),
];

Widget _app(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const GenericMinistryHomeScreen(ministryId: 'm1'),
  ),
);

void main() {
  // O ListView das abas não constrói na altura padrão do teste.
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('workspace genérico monta as cinco abas base', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_base(linked: true)));
    await tester.pumpAndSettle();

    for (final label in [
      'Equipe',
      'Escala',
      'Financeiro',
      'Avisos',
      'Relatórios',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'aba $label sumiu');
    }
  });

  testWidgets('sem vínculo e sem visão global, o workspace barra', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_base(linked: false)));
    await tester.pumpAndSettle();

    expect(find.text('Acesso restrito'), findsOneWidget);
    // O botão de saída aponta para este mesmo workspace: mostrá-lo aqui
    // seria um vai-e-volta entre duas telas fechadas.
    expect(find.text('Abrir ministério'), findsNothing);
  });

  testWidgets('telefone incompleto não vira conversa na aba Avisos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(
          linked: true,
          members: [
            _member(name: 'Ana', phone: '(11) 98888-7777'),
            _member(name: 'Bruno', phone: '(11) '),
            _member(name: 'Carla'),
          ],
        ),
        child: const MaterialApp(
          home: Scaffold(body: MinistryNoticesTab(ministryId: 'm1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 de 3 pessoas tem telefone · 1 com telefone incompleto'),
      findsOneWidget,
    );
    expect(find.text('Avisar a equipe (1)'), findsOneWidget);
    expect(find.textContaining('telefone incompleto'), findsWidgets);
    expect(find.textContaining('sem telefone'), findsOneWidget);
  });

  test('a régua do telefone separa os três estados', () {
    expect(ministryPhoneState('(11) 98888-7777'), MinistryPhoneState.usable);
    expect(ministryPhoneState('5511988887777'), MinistryPhoneState.usable);
    expect(ministryPhoneState('(11) '), MinistryPhoneState.incomplete);
    expect(ministryPhoneState('11'), MinistryPhoneState.incomplete);
    expect(ministryPhoneState(''), MinistryPhoneState.missing);
    expect(ministryPhoneState(null), MinistryPhoneState.missing);
  });
}
