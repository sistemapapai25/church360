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

import 'package:church360_app/features/permissions/data/permissions_repository.dart';
import 'package:church360_app/features/permissions/data/user_roles_repository.dart'
    show MemberWithoutAccountException;
import 'package:church360_app/features/permissions/domain/custom_permission_plan.dart';

const _accountId = '11111111-0000-4000-8000-000000000001';
const _authUserId = '22222222-0000-4000-8000-000000000002';

class _CustomPermissionsApiSpy {
  _CustomPermissionsApiSpy({this.authUserId = _authUserId});

  /// `null` simula membro sem conta de acesso.
  final String? authUserId;

  final List<String> customPermissionCalls = [];
  final List<Map<String, dynamic>> upsertedRows = [];
  final List<Uri> deletes = [];

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

        if (path.endsWith('/user_custom_permissions')) {
          customPermissionCalls.add(request.method);
          if (request.method == 'POST') {
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
