import 'package:church360_app/core/constants/supabase_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const casa = SupabaseConstants.defaultTenantId;

  test('rede do app = a igreja do build e as filiais dela', () {
    expect(SupabaseConstants.isInAppNetwork({'tenant_id': casa}), isTrue);
    expect(
      SupabaseConstants.isInAppNetwork(
          {'tenant_id': 'filial', 'parent_tenant_id': casa}),
      isTrue,
    );
    expect(
      SupabaseConstants.isInAppNetwork(
          {'tenant_id': 'outra', 'parent_tenant_id': null}),
      isFalse,
    );
    expect(
      SupabaseConstants.isInAppNetwork(
          {'tenant_id': 'filial-de-outra', 'parent_tenant_id': 'outra'}),
      isFalse,
    );
  });
}
