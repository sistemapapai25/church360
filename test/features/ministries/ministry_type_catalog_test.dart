import 'package:church360_app/features/ministries/shared/domain/ministry_type_catalog.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O catálogo de tipos de ministério (Fase 2).
///
/// Dois grupos de teste, com propósitos diferentes:
///
/// 1. **o fallback embutido** — ele é cópia do seed da migration
///    `20260924000200_ministry_type_catalogo.sql` e é o que segura a tela
///    quando o banco não responde. Está travado aqui linha a linha: mudar a
///    lista sem mudar a migration (ou o contrário) vira teste vermelho, e não
///    uma prévia mentirosa na tela de quem vai criar um ministério;
///
/// 2. **o cruzamento com as telas** — `ministryTabsFromCatalog` é quem decide
///    o que aparece. As duas direções de divergência entre catálogo e tela
///    estão cobertas, porque as duas vão acontecer algum dia.
void main() {
  group('fallback embutido — espelho do seed da migration', () {
    const catalog = MinistryTypeCatalog.fallback;

    test('tem os quatro tipos, na ordem do sort_order', () {
      expect(catalog.types.map((t) => t.code).toList(), [
        'generic',
        'batismo',
        'raizes',
        'diaconato',
      ]);
    });

    test('comum abre as cinco de base (generic_ministry_home_screen)', () {
      expect(catalog.tabLabelsFor('generic'), [
        'Equipe',
        'Escala',
        'Financeiro',
        'WhatsApp',
        'Relatórios',
      ]);
    });

    test('batismo tem as do módulo, com a sua própria aba WhatsApp', () {
      final tabs = catalog.tabLabelsFor('batismo');
      expect(tabs, [
        'Equipe',
        'Escala',
        'Financeiro',
        'Alunos',
        'Checklist',
        'Presença',
        'WhatsApp',
        'Relatórios',
      ]);
      // A aba WhatsApp do Batismo é outra tela (batismo_whatsapp_tab.dart):
      // fala com alunos, tem turma e variáveis. A genérica fala com a equipe.
      // Mesmo rótulo, telas diferentes — quem resolve é o slot da tela, não o
      // catálogo, que só sabe a chave 'whatsapp'.
      expect(tabs, isNot(contains('Painel')));
    });

    test('raízes e diaconato são as cinco de base mais o Painel', () {
      const esperado = [
        'Painel',
        'Equipe',
        'Escala',
        'Financeiro',
        'WhatsApp',
        'Relatórios',
      ];
      expect(catalog.tabLabelsFor('raizes'), esperado);
      expect(catalog.tabLabelsFor('diaconato'), esperado);
    });

    test('atalhos de rota batem com as rotas do app_router', () {
      expect(
        catalog.routeFor(ministryId: 'm1', code: 'batismo'),
        '/ministries/m1/batismo',
      );
      expect(
        catalog.routeFor(ministryId: 'm1', code: 'raizes'),
        '/ministries/m1/raizes',
      );
      expect(
        catalog.routeFor(ministryId: 'm1', code: 'diaconato'),
        '/ministries/m1/diaconato',
      );
      // Comum não tem atalho: abre o workspace.
      expect(catalog.routeFor(ministryId: 'm1', code: 'generic'),
          '/ministries/m1');
    });

    test('os quatro são oferecidos na criação, e a RPC valida o mesmo', () {
      // create_ministry_with_leader consulta ministry_type.offered_on_create
      // no servidor e devolve 22023 para qualquer outro valor. Se esta lista
      // e o catálogo do banco divergirem, a criação falha em runtime.
      expect(catalog.offeredOnCreate.map((t) => t.code).toList(), [
        'generic',
        'batismo',
        'raizes',
        'diaconato',
      ]);
    });

    test('todo tipo oferecido tem rótulo, descrição e pelo menos uma aba', () {
      for (final tipo in catalog.offeredOnCreate) {
        expect(tipo.label, isNotEmpty, reason: tipo.code);
        expect(tipo.description, isNotEmpty, reason: tipo.code);
        expect(tipo.tabs, isNotEmpty, reason: tipo.code);
      }
    });

    test('tipo que o catálogo não conhece cai nas abas do comum', () {
      // Um ministério com tipo novo, gravado por uma migration que o app
      // ainda não acompanhou, abre com as cinco de base em vez de abrir sem
      // aba nenhuma.
      expect(catalog.tabLabelsFor('kids'), catalog.tabLabelsFor('generic'));
      expect(
        catalog.routeFor(ministryId: 'm1', code: 'kids'),
        '/ministries/m1',
      );
    });
  });

  group('leitura das linhas do banco', () {
    test('monta a partir das linhas e ordena por sort_order', () {
      final catalog = MinistryTypeCatalog.fromRows([
        {
          'code': 'z',
          'label': 'Zebra',
          'tabs': [
            {'key': 'equipe', 'label': 'Equipe'},
          ],
          'sort_order': 99,
        },
        {
          'code': 'a',
          'label': 'Alfa',
          'tabs': const [],
          'sort_order': 1,
          'offered_on_create': true,
          'route_suffix': '/alfa',
        },
      ]);

      expect(catalog.types.map((t) => t.code).toList(), ['a', 'z']);
      expect(catalog.offeredOnCreate.map((t) => t.code).toList(), ['a']);
      expect(
        catalog.routeFor(ministryId: 'm1', code: 'a'),
        '/ministries/m1/alfa',
      );
    });

    test('ignora linha sem code e elemento de aba malformado', () {
      final catalog = MinistryTypeCatalog.fromRows([
        {'label': 'sem código'},
        {
          'code': 'x',
          'label': 'Xis',
          'tabs': [
            {'key': 'equipe', 'label': 'Equipe'},
            {'key': 'sem_label'},
            'texto solto',
            {'key': '', 'label': 'chave vazia'},
            {'key': 'escala', 'label': 'Escala'},
          ],
        },
      ]);

      expect(catalog.types.map((t) => t.code).toList(), ['x']);
      expect(catalog.tabLabelsFor('x'), ['Equipe', 'Escala']);
    });

    test('linha sem label usa o próprio code, para o erro aparecer', () {
      final catalog = MinistryTypeCatalog.fromRows([
        {'code': 'sem_rotulo'},
      ]);
      expect(catalog.labelFor('sem_rotulo'), 'sem_rotulo');
    });
  });

  group('ministryTabsFromCatalog — catálogo x tela', () {
    Map<String, MinistryTabSlot> slots(List<String> keys) => {
      for (final k in keys)
        k: MinistryTabSlot(
          defaultLabel: 'padrão-$k',
          builder: (_) => const SizedBox.shrink(),
        ),
    };

    const catalog = MinistryTypeCatalog([
      MinistryTypeSpec(
        code: 't',
        label: 'T',
        tabs: [
          MinistryTypeTab('b', 'Bê'),
          MinistryTypeTab('a', 'Á'),
        ],
      ),
    ]);

    test('a ordem e o rótulo vêm do catálogo, não da tela', () {
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 't',
        slots: slots(['a', 'b']),
      );
      expect(tabs.map((t) => t.label).toList(), ['Bê', 'Á']);
    });

    test('chave do catálogo sem widget na tela é ignorada', () {
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 't',
        slots: slots(['a']),
      );
      expect(tabs.map((t) => t.label).toList(), ['Á']);
    });

    test('chave que a tela tem e o catálogo não lista sai da tela', () {
      // É a direção sem rede, e é assumida: o catálogo manda. Por isso a
      // tabela só muda por migration.
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 't',
        slots: slots(['a', 'b', 'extra']),
      );
      expect(tabs.map((t) => t.label).toList(), ['Bê', 'Á']);
    });

    test('tipo fora do catálogo usa as abas que a tela declara', () {
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 'inexistente',
        slots: slots(['a', 'b']),
      );
      expect(tabs.map((t) => t.label).toList(), ['padrão-a', 'padrão-b']);
    });

    test('catálogo que não casa com nada devolve a tela inteira', () {
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 't',
        slots: slots(['nada', 'a_ver']),
      );
      expect(tabs.map((t) => t.label).toList(), [
        'padrão-nada',
        'padrão-a_ver',
      ]);
    });

    test('o contador do slot sobrevive à troca de rótulo', () {
      final tabs = ministryTabsFromCatalog(
        catalog: catalog,
        typeCode: 't',
        slots: {
          'b': MinistryTabSlot(
            defaultLabel: 'padrão-b',
            count: '7',
            builder: (_) => const SizedBox.shrink(),
          ),
        },
      );
      expect(tabs.single.label, 'Bê');
      expect(tabs.single.count, '7');
    });
  });
}
