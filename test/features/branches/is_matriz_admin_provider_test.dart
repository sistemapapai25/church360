// CHU-289: cobre isMatrizAdminProvider — gate de tenant.kind == 'matriz' +
// access_level_number >= 5 usado por MatrizAdminOnlyRoute e pelo item
// "Filiais" do drawer.
//
// A "unidade atual" é decidida comparando tenantId com
// SupabaseConstants.currentTenantId (não a flag `is_current` da RPC, que é
// calculada via jwt_tenant_id() e pode ficar desatualizada — ver comentário
// em branches_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/constants/supabase_constants.dart';
import 'package:church360_app/features/branches/data/branches_repository.dart';
import 'package:church360_app/features/branches/domain/models/tenant_unit.dart';
import 'package:church360_app/features/branches/presentation/providers/branches_provider.dart';

class _FakeBranchesRepository extends BranchesRepository {
  _FakeBranchesRepository(this._accessLevelNumber)
      : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  final int? _accessLevelNumber;

  @override
  Future<int?> getMyAccessLevelNumber(String tenantId) async =>
      _accessLevelNumber;
}

ProviderContainer _buildContainer({
  required List<TenantUnit> units,
  int? accessLevelNumber,
}) {
  final container = ProviderContainer(
    overrides: [
      myNetworkUnitsProvider.overrideWith((ref) async => units),
      branchesRepositoryProvider.overrideWithValue(
        _FakeBranchesRepository(accessLevelNumber),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final currentTenantId = SupabaseConstants.currentTenantId;

  group('isMatrizAdminProvider', () {
    test('retorna true quando tenant atual é matriz e nível >= 5', () async {
      final container = _buildContainer(
        units: [
          TenantUnit(
            tenantId: currentTenantId,
            name: 'Matriz',
            kind: 'matriz',
            isCurrent: false,
          ),
        ],
        accessLevelNumber: 5,
      );

      expect(await container.read(isMatrizAdminProvider.future), isTrue);
    });

    test('retorna false quando tenant atual é filial, independente do nível', () async {
      final container = _buildContainer(
        units: [
          TenantUnit(
            tenantId: currentTenantId,
            name: 'Filial',
            kind: 'filial',
            parentTenantId: 'matriz-1',
            isCurrent: false,
          ),
        ],
        accessLevelNumber: 5,
      );

      expect(await container.read(isMatrizAdminProvider.future), isFalse);
    });

    test('retorna false quando tenant atual é matriz mas nível < 5', () async {
      final container = _buildContainer(
        units: [
          TenantUnit(
            tenantId: currentTenantId,
            name: 'Matriz',
            kind: 'matriz',
            isCurrent: false,
          ),
        ],
        accessLevelNumber: 3,
      );

      expect(await container.read(isMatrizAdminProvider.future), isFalse);
    });

    test('retorna false quando o tenant atual não está na lista de unidades', () async {
      final container = _buildContainer(
        units: const [
          TenantUnit(
            tenantId: 'outro-tenant',
            name: 'Matriz',
            kind: 'matriz',
            isCurrent: false,
          ),
        ],
        accessLevelNumber: 5,
      );

      expect(await container.read(isMatrizAdminProvider.future), isFalse);
    });
  });
}
