/// Decide quais vínculos de avô/avó/neto devem nascer quando um vínculo de
/// pai/mãe/filho é criado.
///
/// Isto aqui é lógica pura de propósito: a versão anterior morava dentro do
/// repositório, misturada com as idas ao banco, e por isso o erro que ela
/// tinha nunca pôde ser testado — só apareceu como dado errado em produção
/// (CHU-367: os dois pais do mesmo filho viravam avô e avó um do outro).
library;

/// A convenção da tabela `relacionamentos_familiares`, que vale para o app
/// inteiro: numa linha `(membro_id, parente_id, tipo)`, o **tipo diz o que o
/// parente é do membro**.
///
/// Exemplo: `(Matheus, Ramon, 'pai')` lê-se "Ramon é pai do Matheus". A tela
/// mostra o nome do parente com o tipo como legenda, e `getByMember` devolve
/// as linhas já normalizadas nesse sentido — inclusive as que vieram da
/// direção inversa.
///
/// Era exatamente essa convenção que a propagação antiga lia ao contrário:
/// ela tratava `(memberId, parenteId, 'pai')` como "memberId é pai de
/// parenteId". Com a premissa invertida, ao cadastrar a mãe de uma criança
/// ela buscava *os pais da criança* onde deveria buscar *os pais da mãe*, e
/// ligava o pai já cadastrado à mãe recém-cadastrada como avô dela.
class FamilyTie {
  /// A outra pessoa do vínculo.
  final String parenteId;

  /// O que [parenteId] é da pessoa cuja lista está sendo lida.
  final String tipo;

  const FamilyTie({required this.parenteId, required this.tipo});
}

/// Um vínculo a gravar, na mesma convenção: [tipo] diz o que [parenteId] é
/// de [membroId].
class PlannedFamilyLink {
  final String membroId;
  final String parenteId;
  final String tipo;

  const PlannedFamilyLink({
    required this.membroId,
    required this.parenteId,
    required this.tipo,
  });

  @override
  bool operator ==(Object other) =>
      other is PlannedFamilyLink &&
      other.membroId == membroId &&
      other.parenteId == parenteId &&
      other.tipo == tipo;

  @override
  int get hashCode => Object.hash(membroId, parenteId, tipo);

  @override
  String toString() => 'PlannedFamilyLink($membroId, $parenteId, $tipo)';
}

/// Os quatro tipos que abrem uma geração e por isso disparam propagação.
const Set<String> _tiposDeFiliacao = {'pai', 'mae', 'filho', 'filha'};

bool tipoPropagaGeracao(String tipo) => _tiposDeFiliacao.contains(tipo);

/// Normaliza um vínculo de filiação para o par (quem é o pai/mãe, quem é o
/// filho/filha), independente de qual dos dois lados a pessoa cadastrou.
///
/// Devolve `null` para qualquer tipo que não seja de filiação — cônjuge,
/// irmão, tio e o resto não criam avô nenhum.
({String parentId, String childId})? normalizeFiliacao({
  required String membroId,
  required String parenteId,
  required String tipo,
}) {
  switch (tipo) {
    // "parenteId é pai/mãe do membroId"
    case 'pai':
    case 'mae':
      return (parentId: parenteId, childId: membroId);
    // "parenteId é filho/filha do membroId"
    case 'filho':
    case 'filha':
      return (parentId: membroId, childId: parenteId);
    default:
      return null;
  }
}

/// Planeja os vínculos de avô/avó que decorrem de "[parentId] é pai/mãe de
/// [childId]".
///
/// São exatamente duas direções, e nenhuma outra:
///
/// 1. **Para cima** — os pais de [parentId] viram avós de [childId]. O gênero
///    do avô sai do próprio tipo da linha (`pai` → avô, `mae` → avó), sem
///    precisar consultar cadastro.
/// 2. **Para baixo** — os filhos de [childId] viram netos de [parentId]. Aqui
///    o gênero tem de vir de fora, em [parentSexo], porque é o de [parentId].
///
/// [parentRelations] e [childRelations] são as listas já normalizadas de cada
/// um (o que devolve `getByMember`).
///
/// Nunca devolve um vínculo de alguém consigo mesmo: o banco recusaria com
/// `23514` (`check_not_self_relationship`), e era essa recusa que chegava na
/// tela como "erro" logo depois de o vínculo pedido ter sido gravado com
/// sucesso.
List<PlannedFamilyLink> planGrandparentLinks({
  required String parentId,
  required String childId,
  required List<FamilyTie> parentRelations,
  required List<FamilyTie> childRelations,
  required String parentSexo,
}) {
  final links = <PlannedFamilyLink>[];

  // 1. Pais de quem é pai → avós de quem é filho.
  for (final tie in parentRelations) {
    if (tie.tipo != 'pai' && tie.tipo != 'mae') continue;
    final avoId = tie.parenteId;
    if (avoId == childId || avoId == parentId) continue;
    links.add(
      PlannedFamilyLink(
        membroId: childId,
        parenteId: avoId,
        tipo: tie.tipo == 'pai' ? 'avo' : 'ava',
      ),
    );
  }

  // 2. Filhos de quem é filho → netos de quem é pai.
  for (final tie in childRelations) {
    if (tie.tipo != 'filho' && tie.tipo != 'filha') continue;
    final netoId = tie.parenteId;
    if (netoId == parentId || netoId == childId) continue;
    links.add(
      PlannedFamilyLink(
        membroId: netoId,
        parenteId: parentId,
        tipo: parentSexo == 'M' ? 'avo' : 'ava',
      ),
    );
  }

  return links;
}
