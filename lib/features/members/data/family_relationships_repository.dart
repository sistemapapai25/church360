import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/family_chain_propagation.dart';

const Map<String, String> familyRelationshipTypeLabels = {
  'pai': 'Pai',
  'mae': 'Mãe',
  'filho': 'Filho',
  'filha': 'Filha',
  'irmao': 'Irmão',
  'irma': 'Irmã',
  'conjuge': 'Cônjuge',
  'genro': 'Genro',
  'nora': 'Nora',
  'sogro': 'Sogro',
  'sogra': 'Sogra',
  'neto': 'Neto',
  'neta': 'Neta',
  'avo': 'Avô',
  'ava': 'Avó',
  'sobrinho': 'Sobrinho',
  'sobrinha': 'Sobrinha',
  'tio': 'Tio',
  'tia': 'Tia',
  'primo': 'Primo',
  'prima': 'Prima',
  'tutor': 'Tutor',
  'tutora': 'Tutora',
  'tutelado': 'Tutelado',
  'tutelada': 'Tutelada',
};

String familyRelationshipLabel(String tipo) =>
    familyRelationshipTypeLabels[tipo] ?? tipo;

class FamilyRelationship {
  final String id;
  final String membroId;
  final String parenteId;
  final String tipo;
  final String? membroNome;
  final String? parenteNome;

  FamilyRelationship({
    required this.id,
    required this.membroId,
    required this.parenteId,
    required this.tipo,
    this.membroNome,
    this.parenteNome,
  });
}

/// Converte uma linha de `relacionamentos_familiares` em vínculo, ou devolve
/// `null` quando a linha está órfã.
///
/// Em produção `membro_id` e `parente_id` são NULLABLE — a migration
/// `create_family_relationships_v2`, que os declara NOT NULL, é um
/// `CREATE TABLE IF NOT EXISTS` sobre uma tabela que já existia, então nunca
/// chegou a valer — e as FKs para `user_account` levam SET NULL. Excluir a
/// ficha de alguém, portanto, não apaga os vínculos dessa pessoa: deixa as
/// linhas para trás com um dos lados nulo.
///
/// Um `as String` sobre esse null derrubava a lista inteira, e a tela de
/// edição do membro trocava a seção por "Não foi possível carregar os
/// vínculos". Uma linha sem as duas pontas não descreve vínculo nenhum e não
/// tem como ser exibida nem removida pela tela, então é descartada aqui em
/// vez de derrubar as outras.
FamilyRelationship? familyRelationshipFromRow(dynamic row) {
  if (row is! Map) return null;
  final id = _asString(row['id']);
  final membroId = _asString(row['membro_id']);
  final parenteId = _asString(row['parente_id']);
  final tipo = _asString(row['tipo_relacionamento']);
  if (id == null || membroId == null || parenteId == null || tipo == null) {
    return null;
  }
  return FamilyRelationship(
    id: id,
    membroId: membroId,
    parenteId: parenteId,
    tipo: tipo,
  );
}

String? _asString(dynamic v) => v is String ? v : null;

/// O vínculo pedido foi gravado, mas a propagação automática de avós/netos
/// falhou depois disso. Existe para a tela não anunciar como fracasso algo
/// que já está no banco.
class FamilyChainPropagationException implements Exception {
  final Object cause;
  FamilyChainPropagationException(this.cause);

  @override
  String toString() => 'FamilyChainPropagationException: $cause';
}

class FamilyRelationshipsRepository {
  final SupabaseClient _supabase;
  FamilyRelationshipsRepository(this._supabase);

  /// Resolve nome/gênero de um conjunto de ids via RPC
  /// get_tenant_member_directory: a RLS de user_account só libera leitura de
  /// terceiros para papéis elevados, então um SELECT direto na tabela
  /// retorna vazio para um membro comum consultando cônjuge/parente.
  Future<Map<String, Map<String, dynamic>>> _directoryByIds(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return {};
    try {
      final response = await _supabase.rpc(
        'get_tenant_member_directory',
        params: {'p_ids': idList},
      );
      return {
        for (final entry in (response as List))
          (entry as Map)['id'] as String: Map<String, dynamic>.from(entry),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<FamilyRelationship>> getByMember(String memberId) async {
    final dirRes = await _supabase
        .from('relacionamentos_familiares')
        .select('id,membro_id,parente_id,tipo_relacionamento,created_at,updated_at')
        .eq('membro_id', memberId)
        .order('created_at');
    final dirList = (dirRes as List<dynamic>)
        .map(familyRelationshipFromRow)
        .whereType<FamilyRelationship>()
        .toList();

    final revRes = await _supabase
        .from('relacionamentos_familiares')
        .select('id,membro_id,parente_id,tipo_relacionamento,created_at,updated_at')
        .eq('parente_id', memberId)
        .order('created_at');
    final revRows = (revRes as List<dynamic>)
        .map(familyRelationshipFromRow)
        .whereType<FamilyRelationship>()
        .toList();

    final ids = {
      memberId,
      ...dirList.map((e) => e.membroId),
      ...dirList.map((e) => e.parenteId),
      ...revRows.map((e) => e.membroId),
    };

    final directory = await _directoryByIds(ids);
    final nameMap = <String, String>{};
    final genderMap = <String, String?>{};
    for (final entry in directory.entries) {
      nameMap[entry.key] = (entry.value['full_name'] as String?) ?? '';
      genderMap[entry.key] = entry.value['gender'] as String?;
    }

    final revList = revRows.map((r) {
      final otherId = r.membroId; // quem apontou para o membro atual
      final originalTipo = r.tipo;
      final sexoMembro = _toSexo(genderMap[otherId]); // Gender of the one who pointed
      // Sempre usamos o sexo do membro que criou o vínculo original para determinar o inverso
      // Ex: se A (pai) criou link 'filho' para B. Inverso depende do sexo de A (pai -> pai).
      // Ex: se A (filho) criou link 'pai' para B. Inverso depende do sexo de A (filho -> filho).
      final sexoRef = sexoMembro;
      final invTipo = _getTipoInverso(originalTipo, sexoRef) ?? originalTipo;
      return FamilyRelationship(
        id: r.id,
        membroId: memberId,
        parenteId: otherId,
        tipo: invTipo,
        membroNome: nameMap[memberId],
        parenteNome: nameMap[otherId],
      );
    }).toList();

    final normalizedDir = dirList
        .map((e) => FamilyRelationship(
              id: e.id,
              membroId: e.membroId,
              parenteId: e.parenteId,
              tipo: e.tipo,
              membroNome: nameMap[e.membroId],
              parenteNome: nameMap[e.parenteId],
            ))
        .toList();

    final uniqueByParente = <String, FamilyRelationship>{};

    for (final e in normalizedDir) {
      uniqueByParente[e.parenteId] = e; // preferir o vínculo direto
    }
    for (final e in revList) {
      uniqueByParente.putIfAbsent(e.parenteId, () => e); // usar inverso só se não existir direto
    }

    final result = uniqueByParente.values.toList();
    result.sort((a, b) => (a.parenteNome ?? '').compareTo(b.parenteNome ?? ''));
    return result;
  }

  /// Grava o vínculo e, em seguida, tenta propagar a cadeia (avós/netos).
  ///
  /// As duas etapas não têm o mesmo peso: a primeira é o que a pessoa pediu,
  /// a segunda é conveniência. Se a propagação falhar depois de o vínculo já
  /// estar gravado, o erro sobe como [FamilyChainPropagationException] para
  /// que a tela não diga "não foi possível adicionar" sobre algo que foi
  /// adicionado.
  Future<void> addRelationship(String memberId, String parenteId, String type) async {
    await _addRelationshipCore(memberId, parenteId, type);
    try {
      await _propagateChain(memberId, parenteId, type);
    } catch (e) {
      throw FamilyChainPropagationException(e);
    }
  }

  Future<void> _addRelationshipCore(
      String memberId, String parenteId, String type) async {
    // Ninguém é parente de si mesmo, e o banco concorda:
    // check_not_self_relationship CHECK (membro_id != parente_id) devolve
    // 23514. `planGrandparentLinks` já descarta esses pares na origem; o
    // guard fica como rede, porque quem chama daqui de fora não passa por
    // ele. Sair quieto é a resposta certa: não há o que gravar.
    if (memberId == parenteId) return;

    // Evitar duplicado
    // `.limit(1)` antes do `.maybeSingle()` não é decoração: a tabela não
    // tem UNIQUE em (membro_id, parente_id), e um par duplicado — que a
    // propagação antiga sabia criar — fazia o `maybeSingle` estourar. O erro
    // subia como falha de propagação e a tela avisava em laranja logo depois
    // de gravar o vínculo com sucesso.
    final existing = await _supabase
        .from('relacionamentos_familiares')
        .select('id')
        .eq('membro_id', memberId)
        .eq('parente_id', parenteId)
        .limit(1)
        .maybeSingle();
    if (existing != null) return;

    // Buscar gêneros de AMBOS
    final directory = await _directoryByIds([memberId, parenteId]);
    final genderMembro = directory[memberId]?['gender'] as String?;

    // Inserir direto
    await _supabase.from('relacionamentos_familiares').insert({
      'membro_id': memberId,
      'parente_id': parenteId,
      'tipo_relacionamento': type,
    });

    // ---- ponto de não retorno ----
    // Daqui para baixo o vínculo pedido JÁ ESTÁ no banco. Nada abaixo pode
    // escapar como exceção: o `catch` genérico de member_form_screen não
    // sabe distinguir, e mostraria "Não foi possível adicionar o vínculo"
    // em cima de uma linha gravada — foi assim que o 23514 enganou o
    // diagnóstico por duas sessões. O inverso é conveniência, igual à
    // propagação de avós: se falhar, some em silêncio no log.

    // Inserir inverso.
    //
    // Convenção da tela (member_form_screen `_buildFamilyRelationRow` e
    // member_profile_screen): a linha mostra o NOME DO PARENTE com o TIPO
    // como legenda, ou seja, `tipo` diz o que o parente é do membro.
    // Ex.: (Ramon → Matheus, 'filho') lê-se "Matheus é filho do Ramon".
    //
    // Logo a linha inversa (parente → membro) descreve o que o MEMBRO é do
    // parente, e portanto depende do gênero do MEMBRO — não do parente.
    // Ex.: (Ramon → Maria, 'filha') tem inverso (Maria → Ramon, 'pai'),
    // porque quem é pai/mãe ali é o Ramon. Usar o gênero da Maria fazia o
    // perfil dela mostrar "Ramon — Mãe".
    try {
      final sexoMembroRef = _toSexo(genderMembro);
      final tipoInverso = _getTipoInverso(type, sexoMembroRef);

      if (tipoInverso != null) {
        // O SELECT abaixo também conta: era ele, e não o insert, que
        // estourava fora de qualquer try e virava mensagem vermelha.
        final inverseExisting = await _supabase
            .from('relacionamentos_familiares')
            .select('id')
            .eq('membro_id', parenteId)
            .eq('parente_id', memberId)
            .limit(1)
            .maybeSingle();

        if (inverseExisting == null) {
          await _supabase.from('relacionamentos_familiares').insert({
            'membro_id': parenteId,
            'parente_id': memberId,
            'tipo_relacionamento': tipoInverso,
          });
        }
      }
    } catch (e) {
      // Falha de RLS, de rede ou de duplicidade no inverso. O vínculo
      // direto continua gravado e a tela deve dizer que deu certo.
      debugPrint('Vínculo inverso não pôde ser criado: $e');
    }
  }

  /// Cria os vínculos de avô/avó/neto que decorrem de um vínculo de
  /// filiação recém-gravado.
  ///
  /// Toda a decisão mora em `planGrandparentLinks`, que é pura e testada.
  /// Aqui só sobra o que precisa do banco: descobrir as duas listas e o
  /// gênero de quem é pai/mãe.
  ///
  /// A versão anterior lia a convenção da tabela ao contrário (tratava
  /// `(membro, parente, 'pai')` como "membro é pai do parente") e, por
  /// causa disso, ao cadastrar o segundo genitor de uma criança ligava os
  /// dois genitores entre si como avô e avó — a CHU-367.
  Future<void> _propagateChain(
      String memberId, String parenteId, String type) async {
    final filiacao = normalizeFiliacao(
      membroId: memberId,
      parenteId: parenteId,
      tipo: type,
    );
    if (filiacao == null) return;

    final parentId = filiacao.parentId;
    final childId = filiacao.childId;

    final parentRelations = await getByMember(parentId);
    final childRelations = await getByMember(childId);
    final parentDirectory = await _directoryByIds([parentId]);
    final parentSexo = _toSexo(parentDirectory[parentId]?['gender'] as String?);

    final links = planGrandparentLinks(
      parentId: parentId,
      childId: childId,
      parentRelations: parentRelations
          .map((r) => FamilyTie(parenteId: r.parenteId, tipo: r.tipo))
          .toList(),
      childRelations: childRelations
          .map((r) => FamilyTie(parenteId: r.parenteId, tipo: r.tipo))
          .toList(),
      parentSexo: parentSexo,
    );

    for (final link in links) {
      await _addRelationshipCore(link.membroId, link.parenteId, link.tipo);
    }
  }

  /// Desfaz o vínculo nas DUAS direções.
  ///
  /// Não dá para apagar só por `rel.id`: a lista da tela mistura linhas
  /// diretas com linhas derivadas do inverso, e nas derivadas `membroId` e
  /// `parenteId` já vêm trocados em relação à linha real do banco
  /// (ver `getByMember`). Apagar por id removia a linha certa e a segunda
  /// consulta ia atrás da MESMA linha de novo, deixando a direção
  /// complementar viva — o vínculo reaparecia na recarga seguinte.
  ///
  /// Apagar pelo par, nos dois sentidos, funciona para os dois casos e é
  /// idempotente: o que já não existe simplesmente não casa.
  Future<void> removeRelationship(FamilyRelationship rel) async {
    await _supabase
        .from('relacionamentos_familiares')
        .delete()
        .eq('membro_id', rel.membroId)
        .eq('parente_id', rel.parenteId);

    await _supabase
        .from('relacionamentos_familiares')
        .delete()
        .eq('membro_id', rel.parenteId)
        .eq('parente_id', rel.membroId);
  }

  /// Dado `tipo`, devolve o tipo da relação vista do outro lado.
  ///
  /// `sexoSujeito` é o gênero de QUEM SERÁ DESCRITO pelo tipo devolvido —
  /// não o de quem já está descrito por `tipo`. Trocar os dois é o bug que
  /// fazia um pai virar "Mãe" no perfil da filha.
  static String? _getTipoInverso(String tipo, String sexoSujeito) {
    final inv = <String, Map<String, String>>{
      'pai': {'M': 'filho', 'F': 'filha'},
      'mae': {'M': 'filho', 'F': 'filha'},
      'filho': {'M': 'pai', 'F': 'mae'},
      'filha': {'M': 'pai', 'F': 'mae'},
      'irmao': {'M': 'irmao', 'F': 'irma'},
      'irma': {'M': 'irmao', 'F': 'irma'},
      'conjuge': {'M': 'conjuge', 'F': 'conjuge'},
      'genro': {'M': 'sogro', 'F': 'sogra'},
      'nora': {'M': 'sogro', 'F': 'sogra'},
      'sogro': {'M': 'genro', 'F': 'nora'},
      'sogra': {'M': 'genro', 'F': 'nora'},
      'neto': {'M': 'avo', 'F': 'ava'},
      'neta': {'M': 'avo', 'F': 'ava'},
      'avo': {'M': 'neto', 'F': 'neta'},
      'ava': {'M': 'neto', 'F': 'neta'},
      'sobrinho': {'M': 'tio', 'F': 'tia'},
      'sobrinha': {'M': 'tio', 'F': 'tia'},
      'tio': {'M': 'sobrinho', 'F': 'sobrinha'},
      'tia': {'M': 'sobrinho', 'F': 'sobrinha'},
      'primo': {'M': 'primo', 'F': 'prima'},
      'prima': {'M': 'primo', 'F': 'prima'},
      'tutor': {'M': 'tutelado', 'F': 'tutelada'},
      'tutora': {'M': 'tutelado', 'F': 'tutelada'},
      'tutelado': {'M': 'tutor', 'F': 'tutora'},
      'tutelada': {'M': 'tutor', 'F': 'tutora'},
    };
    return inv[tipo]?[sexoSujeito];
  }

  static String _toSexo(String? gender) {
    if (gender == 'male') return 'M';
    if (gender == 'female') return 'F';
    return 'M';
  }
}
