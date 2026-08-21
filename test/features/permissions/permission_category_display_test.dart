// CHU-315: os títulos das categorias apareciam em inglês/snake_case para o
// usuário final — a tela de Usuário mostrava o código cru do banco e a de
// Cargo tinha um mapa incompleto (faltavam agents, bible, dispatch, kids,
// lgpd, notifications e settings) com chaves mortas sobrando.
//
// A lista abaixo é o catálogo real do tenant principal (28 categorias,
// 143 permissões), conferido direto no banco.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/permissions/presentation/permission_category_display.dart';

const _categoriasDoTenant = <String>[
  'agents',
  'banners',
  'bible',
  'church_info',
  'courses',
  'dashboard',
  'devotionals',
  'dispatch',
  'events',
  'financial',
  'groups',
  'kids',
  'lgpd',
  'live_stream',
  'members',
  'ministries',
  'news',
  'notifications',
  'prayer_requests',
  'reading_plans',
  'reports',
  'settings',
  'study_groups',
  'support_materials',
  'tags',
  'testimonies',
  'visitors',
  'worship',
];

void main() {
  group('rótulos das categorias', () {
    test('as 28 categorias do catálogo têm tradução própria', () {
      final semTraducao = _categoriasDoTenant
          .where((c) => !PermissionCategoryDisplay.knownCategories.contains(c))
          .toList();

      expect(semTraducao, isEmpty,
          reason: 'categorias sem rótulo em português: $semTraducao');
    });

    test('nenhum rótulo sai em snake_case', () {
      for (final categoria in _categoriasDoTenant) {
        expect(PermissionCategoryDisplay.label(categoria), isNot(contains('_')),
            reason: 'categoria $categoria');
      }
    });

    test('nenhum rótulo é igual ao código cru em inglês', () {
      // Termos que o produto já usa como estão em português (o app inteiro
      // fala "Banners", "Tags", "Dashboard", "Kids"); o resto não pode
      // aparecer como veio do banco.
      // ('lgpd' é sigla brasileira — vira 'LGPD', mas bate na comparação
      // case-insensitive.)
      const emprestimos = {'banners', 'tags', 'dashboard', 'kids', 'lgpd'};
      for (final categoria in _categoriasDoTenant) {
        if (emprestimos.contains(categoria)) continue;
        expect(
          PermissionCategoryDisplay.label(categoria).toLowerCase(),
          isNot(categoria),
          reason: 'categoria $categoria segue em inglês',
        );
      }
    });

    test('o mapa não guarda categorias que não existem no catálogo', () {
      final mortas = PermissionCategoryDisplay.knownCategories
          .where((c) => !_categoriasDoTenant.contains(c))
          .toList();

      expect(mortas, isEmpty, reason: 'chaves mortas no mapa: $mortas');
    });

    test('categoria desconhecida cai num fallback sem snake_case', () {
      expect(PermissionCategoryDisplay.label('small_groups'), 'Small Groups');
      expect(PermissionCategoryDisplay.label('MEETINGS'), 'Meetings');
      // Código malformado não pode estourar (o fallback antigo indexava w[0]).
      expect(PermissionCategoryDisplay.label('_'), 'Outras');
      expect(PermissionCategoryDisplay.label(''), 'Outras');
    });
  });

  group('opções do filtro de categoria', () {
    test('monta a lista a partir dos dados, ordenada pelo rótulo', () {
      final options = PermissionCategoryDisplay.optionsFrom(
        ['worship', 'agents', 'church_info', 'agents'],
      );

      expect(options.first.value, isNull);
      expect(options.first.label, 'Todas categorias');
      expect(
        options.skip(1).map((o) => o.value).toList(),
        ['agents', 'worship', 'church_info'], // Agentes IA, Cultos, Igreja
      );
      expect(options.skip(1).map((o) => o.label).toList(),
          ['Agentes IA', 'Cultos', 'Igreja']);
    });
  });
}
