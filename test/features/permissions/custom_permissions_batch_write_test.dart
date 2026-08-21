// CHU-317: marcar uma categoria inteira na tela de Usuário salvava permissão
// por permissão — `ministries` sozinha são 19 `await` sequenciais com a UI
// travada. Estes testes interceptam o HTTP do PostgREST e travam o número de
// requisições em 2 (um upsert + um delete), independentemente do tamanho da
// categoria.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/permissions/data/permissions_repository.dart'
    show CrossTenantPermissionException, PermissionsRepository;
import 'package:church360_app/features/permissions/data/user_roles_repository.dart'
    show MemberWithoutAccountException;
import 'package:church360_app/features/permissions/domain/custom_permission_plan.dart';

const _accountId = '11111111-0000-4000-8000-000000000001';
const _authUserId = '22222222-0000-4000-8000-000000000002';

class _CustomPermissionsApiSpy {
  _CustomPermissionsApiSpy({
    this.authUserId = _authUserId,
    this.idsDeOutroTenant = const {},
  });

  /// `null` simula membro sem conta de acesso.
  final String? authUserId;

  /// Ids que o catálogo do tenant atual **não** contém — o `GET /permissions`
  /// da guarda os omite da resposta, como o banco faria (CHU-314).
  final Set<String> idsDeOutroTenant;

  final List<String> customPermissionCalls = [];
  final List<Map<String, dynamic>> upsertedRows = [];
  final List<Uri> upserts = [];
  final List<Uri> deletes = [];
  final List<Uri> catalogoConsultado = [];

  http.Client get client => MockClient((request) async {
        final path = request.url.path;
        final json = {'content-type': 'application/json; charset=utf-8'};

        if (path.endsWith('/user_account')) {
          return http.Response(
            jsonEncode([
              {'auth_user_id': authUserId}
            ]),
            200,
            request: request,
            headers: json,
          );
        }

        // Guarda de tenant: devolve só os ids pedidos que são "do tenant".
        if (path.endsWith('/permissions') && request.method == 'GET') {
          catalogoConsultado.add(request.url);
          final filtro = request.url.queryParameters['id'] ?? '';
          final pedidos = RegExp(r'in\.\((.*)\)')
                  .firstMatch(filtro)
                  ?.group(1)
                  ?.split(',')
                  .map((s) => s.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty) ??
              const <String>[];
          return http.Response(
            jsonEncode([
              for (final id in pedidos)
                if (!idsDeOutroTenant.contains(id)) {'id': id}
            ]),
            200,
            request: request,
            headers: json,
          );
        }

        if (path.endsWith('/user_custom_permissions')) {
          customPermissionCalls.add(request.method);
          if (request.method == 'POST') {
            upserts.add(request.url);
            for (final row in (jsonDecode(request.body) as List)) {
              upsertedRows.add(row as Map<String, dynamic>);
            }
            return http.Response('', 201, request: request);
          }
          if (request.method == 'DELETE') {
            deletes.add(request.url);
            return http.Response('', 204, request: request);
          }
        }

        return http.Response('[]', 200, request: request, headers: json);
      });
}

PermissionsRepository _repoWith(_CustomPermissionsApiSpy spy) =>
    PermissionsRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: spy.client,
      ),
    );

void main() {
  test('uma categoria inteira vira 2 requisições, não uma por permissão',
      () async {
    final spy = _CustomPermissionsApiSpy();
    final plan = CustomPermissionPlan(
      grantIds: List.generate(12, (i) => 'grant-$i'),
      denyIds: const ['deny-0'],
      clearIds: List.generate(6, (i) => 'clear-$i'),
    );

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: plan,
    );

    expect(spy.customPermissionCalls, ['POST', 'DELETE']);
    expect(spy.upsertedRows.length, 13);
    expect(spy.deletes, hasLength(1));
  });

  test('o upsert grava is_granted por permissão e resolve o auth user id',
      () async {
    final spy = _CustomPermissionsApiSpy();

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: const CustomPermissionPlan(
        grantIds: ['perm-liberada'],
        denyIds: ['perm-bloqueada'],
        clearIds: [],
      ),
    );

    expect(spy.customPermissionCalls, ['POST']);
    expect(
      spy.upsertedRows,
      containsAll([
        containsPair('permission_id', 'perm-liberada'),
        containsPair('permission_id', 'perm-bloqueada'),
      ]),
    );
    expect(
      spy.upsertedRows
          .firstWhere((r) => r['permission_id'] == 'perm-liberada')['is_granted'],
      isTrue,
    );
    expect(
      spy.upsertedRows
          .firstWhere((r) => r['permission_id'] == 'perm-bloqueada')['is_granted'],
      isFalse,
    );
    expect(
      spy.upsertedRows.map((r) => r['user_id']).toSet(),
      {_authUserId},
    );
  });

  test('só clears não disparam upsert vazio', () async {
    final spy = _CustomPermissionsApiSpy();

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: const CustomPermissionPlan(
        grantIds: [],
        denyIds: [],
        clearIds: ['perm-a', 'perm-b'],
      ),
    );

    expect(spy.customPermissionCalls, ['DELETE']);
    final query = spy.deletes.single.queryParameters;
    expect(query['user_id'], 'eq.$_authUserId');
    expect(query['permission_id'], 'in.("perm-a","perm-b")');
  });

  test('plano vazio não bate no banco', () async {
    final spy = _CustomPermissionsApiSpy();

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: const CustomPermissionPlan(grantIds: [], denyIds: [], clearIds: []),
    );

    expect(spy.customPermissionCalls, isEmpty);
  });

  // Sem `onConflict` o PostgREST infere a PK (`id`), que nunca colide porque o
  // app não a envia: o upsert vira INSERT puro e a UNIQUE
  // (user_id, permission_id) derruba o lote com 409. Reproduzido contra a base
  // de produção em 21/08/2026 — acontece sempre que a permissão já tem
  // override gravado (virar um "permitido" em "negado", por exemplo).
  test('o upsert declara o conflito por (user_id, permission_id)', () async {
    final spy = _CustomPermissionsApiSpy();

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: const CustomPermissionPlan(
        grantIds: ['perm-a'],
        denyIds: [],
        clearIds: [],
      ),
    );

    expect(
      spy.upserts.single.queryParameters['on_conflict'],
      'user_id,permission_id',
    );
  });

  test('permissão de outro tenant é recusada antes de qualquer escrita',
      () async {
    final spy = _CustomPermissionsApiSpy(
      idsDeOutroTenant: {'perm-de-outra-igreja'},
    );

    await expectLater(
      _repoWith(spy).applyCustomPermissions(
        userId: _accountId,
        plan: const CustomPermissionPlan(
          grantIds: ['perm-da-casa', 'perm-de-outra-igreja'],
          denyIds: [],
          clearIds: [],
        ),
      ),
      throwsA(
        isA<CrossTenantPermissionException>().having(
          (e) => e.permissionIds,
          'permissionIds',
          ['perm-de-outra-igreja'],
        ),
      ),
    );

    expect(spy.customPermissionCalls, isEmpty);
    expect(spy.catalogoConsultado, hasLength(1));
  });

  test('a guarda consulta o catálogo uma vez só, não uma por permissão',
      () async {
    final spy = _CustomPermissionsApiSpy();

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: CustomPermissionPlan(
        grantIds: List.generate(12, (i) => 'grant-$i'),
        denyIds: const ['deny-0'],
        clearIds: List.generate(6, (i) => 'clear-$i'),
      ),
    );

    expect(spy.catalogoConsultado, hasLength(1));
    expect(spy.customPermissionCalls, ['POST', 'DELETE']);
  });

  test('clears de vínculos legados não passam pela guarda', () async {
    // Apagar um vínculo cruzado é justamente o que se quer poder fazer.
    final spy = _CustomPermissionsApiSpy(
      idsDeOutroTenant: {'legado-cruzado'},
    );

    await _repoWith(spy).applyCustomPermissions(
      userId: _accountId,
      plan: const CustomPermissionPlan(
        grantIds: [],
        denyIds: [],
        clearIds: ['legado-cruzado'],
      ),
    );

    expect(spy.customPermissionCalls, ['DELETE']);
  });

  test('membro sem conta de acesso falha antes de gravar', () async {
    final spy = _CustomPermissionsApiSpy(authUserId: null);

    await expectLater(
      _repoWith(spy).applyCustomPermissions(
        userId: _accountId,
        plan: const CustomPermissionPlan(
          grantIds: ['perm-a'],
          denyIds: [],
          clearIds: [],
        ),
      ),
      throwsA(isA<MemberWithoutAccountException>()),
    );
    expect(spy.customPermissionCalls, isEmpty);
  });
}
