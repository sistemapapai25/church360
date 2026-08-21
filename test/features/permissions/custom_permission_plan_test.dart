// CHU-317: "marcar todas" na tela de Permissões do Usuário. A gravação ali é
// imediata e a decisão por permissão não é on/off — compara o que o cargo
// concede com o override manual. Estes testes travam a regra do lote contra a
// regra item a item, que é o critério de aceite da issue.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/permissions/domain/custom_permission_plan.dart';

UserPermissionState _state(
  String id, {
  required bool roleGranted,
  bool? customGranted,
}) =>
    UserPermissionState(
      permissionId: id,
      roleGranted: roleGranted,
      customGranted: customGranted,
    );

void main() {
  group('habilitar em lote', () {
    test('grava override só onde o cargo não concede', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [
          _state('sem-cargo', roleGranted: false),
          _state('com-cargo', roleGranted: true),
        ],
        isGranted: true,
      );

      expect(plan.grantIds, ['sem-cargo']);
      expect(plan.denyIds, isEmpty);
      expect(plan.clearIds, isEmpty);
    });

    test('remove o bloqueio manual quando o cargo já concede', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [_state('bloqueada', roleGranted: true, customGranted: false)],
        isGranted: true,
      );

      expect(plan.clearIds, ['bloqueada']);
      expect(plan.grantIds, isEmpty);
    });

    test('ignora o que já está habilitado', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [
          _state('pelo-cargo', roleGranted: true),
          _state('override', roleGranted: false, customGranted: true),
        ],
        isGranted: true,
      );

      expect(plan.isEmpty, isTrue);
      expect(plan.affectedCount, 0);
    });
  });

  group('desabilitar em lote', () {
    test('bloqueia manualmente o que vem do cargo', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [_state('pelo-cargo', roleGranted: true)],
        isGranted: false,
      );

      expect(plan.denyIds, ['pelo-cargo']);
    });

    test('remove o override quando o cargo também não concede', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [_state('so-override', roleGranted: false, customGranted: true)],
        isGranted: false,
      );

      expect(plan.clearIds, ['so-override']);
      expect(plan.denyIds, isEmpty);
    });

    test('ignora o que já está desabilitado', () {
      final plan = CustomPermissionPlan.forTarget(
        permissions: [
          _state('nem-cargo-nem-override', roleGranted: false),
          _state('ja-bloqueada', roleGranted: true, customGranted: false),
        ],
        isGranted: false,
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  test('o lote produz o mesmo resultado que marcar item a item', () {
    final permissoes = [
      _state('a', roleGranted: true),
      _state('b', roleGranted: false),
      _state('c', roleGranted: true, customGranted: false),
      _state('d', roleGranted: false, customGranted: true),
      _state('e', roleGranted: false, customGranted: false),
    ];

    for (final alvo in [true, false]) {
      final loteId = <String, String>{};
      final lote = CustomPermissionPlan.forTarget(
        permissions: permissoes,
        isGranted: alvo,
      );
      for (final id in lote.grantIds) {
        loteId[id] = 'grant';
      }
      for (final id in lote.denyIds) {
        loteId[id] = 'deny';
      }
      for (final id in lote.clearIds) {
        loteId[id] = 'clear';
      }

      final itemAItem = <String, String>{};
      for (final permissao in permissoes) {
        final plan = CustomPermissionPlan.forTarget(
          permissions: [permissao],
          isGranted: alvo,
        );
        for (final id in plan.grantIds) {
          itemAItem[id] = 'grant';
        }
        for (final id in plan.denyIds) {
          itemAItem[id] = 'deny';
        }
        for (final id in plan.clearIds) {
          itemAItem[id] = 'clear';
        }
      }

      expect(loteId, itemAItem, reason: 'isGranted: $alvo');
    }
  });
}
