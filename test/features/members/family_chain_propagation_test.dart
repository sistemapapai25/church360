import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/domain/family_chain_propagation.dart';

/// Elenco fixo, para os testes se lerem como frases.
const ramon = 'ramon';
const debora = 'debora';
const matheus = 'matheus';
const jose = 'jose';
const antonia = 'antonia';
const netinho = 'netinho';

void main() {
  group('normalizeFiliacao', () {
    test('tipo "pai" diz que o PARENTE é pai do membro', () {
      final r = normalizeFiliacao(
        membroId: matheus,
        parenteId: ramon,
        tipo: 'pai',
      );
      expect(r, isNotNull);
      expect(r!.parentId, ramon);
      expect(r.childId, matheus);
    });

    test('tipo "filho" diz que o PARENTE é filho do membro', () {
      final r = normalizeFiliacao(
        membroId: ramon,
        parenteId: matheus,
        tipo: 'filho',
      );
      expect(r, isNotNull);
      expect(r!.parentId, ramon);
      expect(r.childId, matheus);
    });

    test('os dois lados do mesmo fato normalizam para o mesmo par', () {
      final porCima = normalizeFiliacao(
        membroId: matheus,
        parenteId: ramon,
        tipo: 'pai',
      );
      final porBaixo = normalizeFiliacao(
        membroId: ramon,
        parenteId: matheus,
        tipo: 'filho',
      );
      expect(porCima, porBaixo);
    });

    test('tipo que não é de filiação não propaga nada', () {
      for (final tipo in ['conjuge', 'irmao', 'tio', 'sogro', 'avo']) {
        expect(
          normalizeFiliacao(membroId: ramon, parenteId: debora, tipo: tipo),
          isNull,
          reason: '"$tipo" não abre uma geração',
        );
        expect(tipoPropagaGeracao(tipo), isFalse);
      }
    });
  });

  group('planGrandparentLinks', () {
    test(
      'CHU-367: cadastrar a mãe não faz dela avó do pai, nem o contrário',
      () {
        // Matheus já tem o pai Ramon cadastrado. Agora entra a mãe, Débora.
        // Nem Débora nem Matheus têm outros vínculos: não há avô nenhum a
        // criar, e principalmente os dois genitores não se tocam.
        final links = planGrandparentLinks(
          parentId: debora,
          childId: matheus,
          parentRelations: const [], // Débora não tem pais cadastrados
          childRelations: const [
            FamilyTie(parenteId: ramon, tipo: 'pai'), // o outro genitor
          ],
          parentSexo: 'F',
        );

        expect(
          links,
          isEmpty,
          reason: 'o pai do Matheus não é parente da mãe do Matheus',
        );
      },
    );

    test('pais de quem é pai viram avós de quem é filho', () {
      // José é pai do Ramon; Antônia é mãe do Ramon.
      // Ao ligar Ramon como pai do Matheus, os dois viram avós do Matheus.
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [
          FamilyTie(parenteId: jose, tipo: 'pai'),
          FamilyTie(parenteId: antonia, tipo: 'mae'),
        ],
        childRelations: const [],
        parentSexo: 'M',
      );

      expect(links, hasLength(2));
      expect(
        links,
        contains(
          const PlannedFamilyLink(
            membroId: matheus,
            parenteId: jose,
            tipo: 'avo',
          ),
        ),
      );
      expect(
        links,
        contains(
          const PlannedFamilyLink(
            membroId: matheus,
            parenteId: antonia,
            tipo: 'ava',
          ),
        ),
      );
    });

    test('o gênero do avô sai do tipo da linha, não de cadastro', () {
      // `mae` só pode gerar avó, mesmo sem consultar o gênero de ninguém.
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [FamilyTie(parenteId: antonia, tipo: 'mae')],
        childRelations: const [],
        parentSexo: 'M',
      );
      expect(links.single.tipo, 'ava');
    });

    test('filhos de quem é filho viram netos de quem é pai', () {
      // Matheus já tem um filho, o Netinho. Ao ligar Ramon como pai do
      // Matheus, Ramon vira avô do Netinho.
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [],
        childRelations: const [FamilyTie(parenteId: netinho, tipo: 'filho')],
        parentSexo: 'M',
      );

      expect(
        links,
        [
          const PlannedFamilyLink(
            membroId: netinho,
            parenteId: ramon,
            tipo: 'avo',
          ),
        ],
      );
    });

    test('para baixo, o gênero vem de quem é pai — mãe gera avó', () {
      final links = planGrandparentLinks(
        parentId: debora,
        childId: matheus,
        parentRelations: const [],
        childRelations: const [FamilyTie(parenteId: netinho, tipo: 'filha')],
        parentSexo: 'F',
      );
      expect(links.single.tipo, 'ava');
    });

    test('as duas direções convivem na mesma chamada', () {
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [FamilyTie(parenteId: jose, tipo: 'pai')],
        childRelations: const [FamilyTie(parenteId: netinho, tipo: 'filho')],
        parentSexo: 'M',
      );
      expect(links, hasLength(2));
    });

    test('nunca planeja alguém como parente de si mesmo (23514)', () {
      // Listas sujas de propósito: o filho aparecendo como pai do pai, e o
      // pai aparecendo como filho do filho. O banco recusaria os dois com
      // check_not_self_relationship, e a recusa chegava na tela como erro
      // depois de o vínculo pedido já estar gravado.
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [
          FamilyTie(parenteId: matheus, tipo: 'pai'),
          FamilyTie(parenteId: ramon, tipo: 'mae'),
        ],
        childRelations: const [
          FamilyTie(parenteId: ramon, tipo: 'filho'),
          FamilyTie(parenteId: matheus, tipo: 'filha'),
        ],
        parentSexo: 'M',
      );

      expect(links, isEmpty);
      for (final link in links) {
        expect(link.membroId, isNot(link.parenteId));
      }
    });

    test('vínculos que não são de filiação são ignorados nas duas listas', () {
      // Cônjuge, irmão e tio não produzem avô nenhum — foi justamente um
      // filtro largo demais (pai/mae dos DOIS lados) que criou a CHU-367.
      final links = planGrandparentLinks(
        parentId: ramon,
        childId: matheus,
        parentRelations: const [
          FamilyTie(parenteId: debora, tipo: 'conjuge'),
          FamilyTie(parenteId: jose, tipo: 'irmao'),
        ],
        childRelations: const [
          FamilyTie(parenteId: debora, tipo: 'mae'),
          FamilyTie(parenteId: antonia, tipo: 'tia'),
        ],
        parentSexo: 'M',
      );

      expect(links, isEmpty);
    });
  });
}
