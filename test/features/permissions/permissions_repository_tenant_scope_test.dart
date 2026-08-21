// CHU-313: o catálogo de permissões é multi-tenant (`permissions` é
// `tenant_id NOT NULL`, UNIQUE real `(tenant_id, code)`). Sem filtro de tenant
// as queries devolviam o catálogo das 5 igrejas do sistema — 327 linhas para
// 144 códigos únicos — e a tela remarcava todas as cópias do mesmo código.
//
// Estes testes interceptam o HTTP do PostgREST e travam o filtro na query.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/constants/supabase_constants.dart';
import 'package:church360_app/features/permissions/data/permissions_repository.dart';

const _tenantA = 'aaaaaaaa-0000-4000-8000-000000000001';
const _tenantB = 'bbbbbbbb-0000-4000-8000-000000000002';

/// Guarda as URLs de GET em `/rest/v1/permissions` e responde com um catálogo
/// mínimo. Os POSTs (upserts de `_ensureCorePermissions` /
/// `_ensureAgentPermissions`) são aceitos e ignorados.
class _PermissionsApiSpy {
  final List<Uri> permissionGets = [];
  final List<Map<String, dynamic>> upsertedRows = [];

  http.Client get client => MockClient((request) async {
        final path = request.url.path;

        if (request.method == 'GET' && path.endsWith('/permissions')) {
          permissionGets.add(request.url);
          return http.Response(
            jsonEncode([
              {
                'id': '11111111-0000-4000-8000-000000000001',
                'code': 'members.view',
                'name': 'Ver Membros',
                'description': null,
                'category': 'members',
                'subcategory': 'view',
                'is_active': true,
                'requires_context': false,
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.method == 'POST' && path.endsWith('/permissions')) {
          final body = jsonDecode(request.body);
          for (final row in (body as List)) {
            upsertedRows.add(row as Map<String, dynamic>);
          }
          return http.Response('', 201, request: request);
        }

        // agent_config e qualquer outra leitura auxiliar.
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
}

void main() {
  late String originalTenantId;

  setUp(() {
    originalTenantId = SupabaseConstants.currentTenantId;
    SupabaseConstants.currentTenantId = _tenantA;
  });

  tearDown(() {
    SupabaseConstants.currentTenantId = originalTenantId;
  });

  PermissionsRepository repoWith(_PermissionsApiSpy spy) => PermissionsRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          httpClient: spy.client,
        ),
      );

  group('catálogo de permissões filtra por tenant', () {
    test('getPermissions() envia tenant_id=eq.<tenant atual>', () async {
      final spy = _PermissionsApiSpy();

      await repoWith(spy).getPermissions();

      final query = spy.permissionGets.last.queryParameters;
      expect(query['tenant_id'], 'eq.$_tenantA');
      expect(query['is_active'], 'eq.true');
    });

    test('getPermissionsByCategory() envia tenant_id junto da categoria',
        () async {
      final spy = _PermissionsApiSpy();

      await repoWith(spy).getPermissionsByCategory('members');

      final query = spy.permissionGets.last.queryParameters;
      expect(query['tenant_id'], 'eq.$_tenantA');
      expect(query['category'], 'eq.members');
    });

    test('getCategories() envia tenant_id', () async {
      final spy = _PermissionsApiSpy();

      await repoWith(spy).getCategories();

      expect(spy.permissionGets.last.queryParameters['tenant_id'],
          'eq.$_tenantA');
    });

    test(
        'getPermissionByCode() envia tenant_id e limita a 1 linha '
        '(maybeSingle sozinho estoura com código duplicado)', () async {
      final spy = _PermissionsApiSpy();

      final permission = await repoWith(spy).getPermissionByCode('members.view');

      final query = spy.permissionGets.last.queryParameters;
      expect(query['tenant_id'], 'eq.$_tenantA');
      expect(query['code'], 'eq.members.view');
      expect(query['limit'], '1');
      expect(permission?.code, 'members.view');
    });
  });

  group('seed do catálogo', () {
    test('grava as permissões core com o tenant atual', () async {
      final spy = _PermissionsApiSpy();

      await repoWith(spy).getPermissions();

      expect(spy.upsertedRows, isNotEmpty);
      expect(
        spy.upsertedRows.map((r) => r['tenant_id']).toSet(),
        {_tenantA},
      );
    });

    test('re-semeia depois de trocar de igreja em vez de reusar o cache',
        () async {
      final spy = _PermissionsApiSpy();
      final repo = repoWith(spy);

      await repo.getPermissions();
      final upsertsTenantA = spy.upsertedRows.length;

      SupabaseConstants.currentTenantId = _tenantB;
      await repo.getPermissions();

      expect(spy.upsertedRows.length, greaterThan(upsertsTenantA));
      expect(
        spy.upsertedRows.map((r) => r['tenant_id']).toSet(),
        {_tenantA, _tenantB},
      );
      expect(
        spy.permissionGets.last.queryParameters['tenant_id'],
        'eq.$_tenantB',
      );
    });
  });
}
