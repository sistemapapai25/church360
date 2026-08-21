// CHU-315/316/318: a tela de Permissões do Usuário mostrava o código cru da
// categoria (`ministries`), abria todos os cards de uma vez — 28 categorias,
// `ministries` sozinha com 19 permissões — e não tinha contador de resultados.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/permissions/data/permissions_repository.dart';
import 'package:church360_app/features/permissions/domain/custom_permission_plan.dart';
import 'package:church360_app/features/permissions/domain/models/permission.dart';
import 'package:church360_app/features/permissions/domain/models/user_effective_permission.dart';
import 'package:church360_app/features/permissions/presentation/screens/user_permissions_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

const _userId = 'user-1';

final _permissoes = [
  const Permission(
    id: 'p1',
    code: 'ministries.view',
    name: 'Ver Ministérios',
    category: 'ministries',
  ),
  const Permission(
    id: 'p2',
    code: 'ministries.manage_members',
    name: 'Gerenciar Membros do Ministério',
    category: 'ministries',
  ),
  const Permission(
    id: 'p3',
    code: 'church_info.view',
    name: 'Ver Informações da Igreja',
    category: 'church_info',
  ),
];

final _efetivas = [
  const UserEffectivePermission(
    permissionCode: 'ministries.view',
    permissionName: 'Ver Ministérios',
    source: 'role',
    isGranted: true,
  ),
];

/// Registra o que a tela mandaria gravar, sem tocar no banco.
class _RepositorioEspiao extends PermissionsRepository {
  _RepositorioEspiao()
      : super(SupabaseClient(
          'http://localhost',
          'test-key',
          // Sem isso o GoTrue deixa um `Timer.periodic` de auto-refresh vivo e
          // o flutter_test falha o teste por timer pendente.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final List<CustomPermissionPlan> planos = [];

  @override
  Future<void> applyCustomPermissions({
    required String userId,
    required CustomPermissionPlan plan,
  }) async {
    planos.add(plan);
  }
}

Widget _tela({PermissionsRepository? repositorio}) => ProviderScope(
      overrides: [
        memberByIdProvider(_userId).overrideWith((ref) async => null),
        permissionsProvider.overrideWith((ref) async => _permissoes),
        userEffectivePermissionsProvider(_userId)
            .overrideWith((ref) async => _efetivas),
        if (repositorio != null)
          permissionsRepositoryProvider.overrideWithValue(repositorio),
      ],
      child: const MaterialApp(
        home: UserPermissionsScreen(userId: _userId),
      ),
    );

void main() {
  testWidgets('mostra a categoria traduzida, não o código do banco',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    expect(find.text('Ministérios'), findsOneWidget);
    expect(find.text('Igreja'), findsOneWidget);
    expect(find.text('ministries'), findsNothing);
    expect(find.text('church_info'), findsNothing);
  });

  testWidgets('cards começam recolhidos, com o contador visível no header',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    // Contador dá a noção do estado sem precisar abrir.
    expect(find.text('1/2 selecionadas'), findsOneWidget);
    expect(find.text('0/1 selecionadas'), findsOneWidget);
    // Nenhuma permissão listada antes de abrir.
    expect(find.text('Ver Ministérios'), findsNothing);
    expect(find.text('Ver Informações da Igreja'), findsNothing);
  });

  testWidgets('abrir uma categoria não fecha as outras', (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ministérios'));
    await tester.pumpAndSettle();
    expect(find.text('Ver Ministérios'), findsOneWidget);

    await tester.tap(find.text('Igreja'));
    await tester.pumpAndSettle();
    expect(find.text('Ver Informações da Igreja'), findsOneWidget);
    expect(find.text('Ver Ministérios'), findsOneWidget);
  });

  testWidgets('busca expande as categorias com resultado e conta os achados',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('busca-permissoes')), 'gerenciar');
    // A busca é debounced (250ms).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('1 permissão encontrada'), findsOneWidget);
    expect(find.text('Gerenciar Membros do Ministério'), findsOneWidget);
    expect(find.text('Igreja'), findsNothing);
  });

  testWidgets(
      'marcar a categoria inteira confirma e grava um plano só (CHU-317)',
      (tester) async {
    final repositorio = _RepositorioEspiao();
    await tester.pumpWidget(_tela(repositorio: repositorio));
    await tester.pumpAndSettle();

    final cardMinisterios = find.ancestor(
      of: find.text('Ministérios'),
      matching: find.byType(ExpansionTile),
    );
    await tester.tap(find.descendant(
      of: cardMinisterios,
      matching: find.byType(Checkbox),
    ));
    await tester.pumpAndSettle();

    // A gravação é imediata (não há botão SALVAR), então confirma antes.
    expect(find.text('Habilitar categoria?'), findsOneWidget);
    expect(repositorio.planos, isEmpty);

    await tester.tap(find.text('HABILITAR'));
    await tester.pumpAndSettle();

    expect(repositorio.planos, hasLength(1));
    // `ministries.view` já vem do cargo; só a outra precisa de override.
    expect(repositorio.planos.single.grantIds, ['p2']);
    expect(repositorio.planos.single.denyIds, isEmpty);
    expect(repositorio.planos.single.clearIds, isEmpty);

    // Deixa o SnackBar de confirmação expirar antes de encerrar o teste.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('limpar a busca devolve os cards recolhidos', (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('busca-permissoes')), 'ministérios');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Ver Ministérios'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Ver Ministérios'), findsNothing);
    expect(find.text('Ministérios'), findsOneWidget);
  });
}
