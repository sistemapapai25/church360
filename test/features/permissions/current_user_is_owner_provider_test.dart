// CHU-310: cobre currentUserIsOwnerProvider, extraído do check ad hoc de
// role_global == 'owner' que existia embutido em dashboard_screen.dart (fora
// da camada de permissões, ao contrário do resto do gating do Dashboard).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/members/domain/models/member.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/permissions/data/permissions_repository.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;

class _FakePermissionsRepository extends PermissionsRepository {
  _FakePermissionsRepository(this._isOwner)
      : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  final bool _isOwner;

  @override
  Future<bool> isOwnerByMemberId(String memberId) async => _isOwner;
}

Member _member(String id) =>
    Member(id: id, email: '$id@example.com', createdAt: DateTime(2026, 1, 1));

void main() {
  group('currentUserIsOwnerProvider', () {
    test('retorna true quando role_global do usuário é owner', () async {
      final container = ProviderContainer(
        overrides: [
          currentMemberProvider.overrideWith((ref) async => _member('owner-1')),
          permissionsRepositoryProvider.overrideWithValue(
            _FakePermissionsRepository(true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final isOwner = await container.read(currentUserIsOwnerProvider.future);

      expect(isOwner, isTrue);
    });

    test('retorna false para usuário comum (não owner)', () async {
      final container = ProviderContainer(
        overrides: [
          currentMemberProvider.overrideWith((ref) async => _member('member-1')),
          permissionsRepositoryProvider.overrideWithValue(
            _FakePermissionsRepository(false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final isOwner = await container.read(currentUserIsOwnerProvider.future);

      expect(isOwner, isFalse);
    });

    test('retorna false quando não há usuário autenticado', () async {
      final container = ProviderContainer(
        overrides: [
          currentMemberProvider.overrideWith((ref) async => null),
          permissionsRepositoryProvider.overrideWithValue(
            _FakePermissionsRepository(true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final isOwner = await container.read(currentUserIsOwnerProvider.future);

      expect(isOwner, isFalse);
    });
  });
}
