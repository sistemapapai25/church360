import 'package:supabase_flutter/supabase_flutter.dart';

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

class FamilyRelationshipsRepository {
  final SupabaseClient _supabase;
  FamilyRelationshipsRepository(this._supabase);

  Future<List<FamilyRelationship>> getByMember(String memberId) async {
    final dirRes = await _supabase
        .from('relacionamentos_familiares')
        .select('id,membro_id,parente_id,tipo_relacionamento,created_at,updated_at')
        .eq('membro_id', memberId)
        .order('created_at');
    final dirList = (dirRes as List<dynamic>).map((r) => FamilyRelationship(
          id: r['id'] as String,
          membroId: r['membro_id'] as String,
          parenteId: r['parente_id'] as String,
          tipo: r['tipo_relacionamento'] as String,
        )).toList();

    final revRes = await _supabase
        .from('relacionamentos_familiares')
        .select('id,membro_id,parente_id,tipo_relacionamento,created_at,updated_at')
        .eq('parente_id', memberId)
        .order('created_at');
    final revRaw = (revRes as List<dynamic>);

    final ids = {
      memberId,
      ...dirList.map((e) => e.membroId),
      ...dirList.map((e) => e.parenteId),
      ...revRaw.map((r) => r['membro_id'] as String),
    }.toList();

    final cond = ids.map((id) => 'id.eq.$id').join(',');
    final users = await _supabase
        .from('user_account')
        .select('id, full_name, gender')
        .or(cond);
    final nameMap = <String, String>{};
    final genderMap = <String, String?>{};
    for (final u in (users as List<dynamic>)) {
      final uid = u['id'] as String;
      nameMap[uid] = (u['full_name'] as String?) ?? '';
      genderMap[uid] = u['gender'] as String?;
    }

    final revList = revRaw.map((r) {
      final otherId = r['membro_id'] as String; // quem apontou para o membro atual
      final originalTipo = r['tipo_relacionamento'] as String;
      final sexoMembro = _toSexo(genderMap[otherId]); // Gender of the one who pointed
      // Sempre usamos o sexo do membro que criou o vínculo original para determinar o inverso
      // Ex: se A (pai) criou link 'filho' para B. Inverso depende do sexo de A (pai -> pai).
      // Ex: se A (filho) criou link 'pai' para B. Inverso depende do sexo de A (filho -> filho).
      final sexoRef = sexoMembro;
      final invTipo = _getTipoInverso(originalTipo, sexoRef) ?? originalTipo;
      return FamilyRelationship(
        id: r['id'] as String,
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

  Future<void> addRelationship(String memberId, String parenteId, String type) async {
    await _addRelationshipCore(memberId, parenteId, type);
    await _propagateChain(memberId, parenteId, type);
  }

  Future<void> _addRelationshipCore(
      String memberId, String parenteId, String type) async {
    // Evitar duplicado
    final existing = await _supabase
        .from('relacionamentos_familiares')
        .select('id')
        .eq('membro_id', memberId)
        .eq('parente_id', parenteId)
        .maybeSingle();
    if (existing != null) return;

    // Buscar gêneros de AMBOS
    final members = await _supabase
        .from('user_account')
        .select('id, gender')
        .or('id.eq.$memberId,id.eq.$parenteId');

    String? genderParente;

    for (final m in (members as List<dynamic>)) {
      if (m['id'] == parenteId) genderParente = m['gender'];
    }

    // Inserir direto
    await _supabase.from('relacionamentos_familiares').insert({
      'membro_id': memberId,
      'parente_id': parenteId,
      'tipo_relacionamento': type,
    });

    // Inserir inverso
    // O tipo inverso depende do gênero do parente (quem será o sujeito do relacionamento inverso)
    // Ex: A (Pai) -> B (Filha). Inverso: B -> A. O que B é de A?
    // Se A -> B é 'pai', e B é mulher ('F'), então B -> A é 'filha'.
    // Portanto, usamos o gênero do parenteId para determinar o inverso.
    final sexoParenteRef = _toSexo(genderParente);
    final tipoInverso = _getTipoInverso(type, sexoParenteRef);

    if (tipoInverso != null) {
      final inverseExisting = await _supabase
          .from('relacionamentos_familiares')
          .select('id')
          .eq('membro_id', parenteId)
          .eq('parente_id', memberId)
          .maybeSingle();

      if (inverseExisting == null) {
        try {
          await _supabase.from('relacionamentos_familiares').insert({
            'membro_id': parenteId,
            'parente_id': memberId,
            'tipo_relacionamento': tipoInverso,
          });
        } catch (_) {
          // ignorar falhas por RLS
        }
      }
    }
  }

  Future<void> _propagateChain(
      String memberId, String parenteId, String type) async {
    // Lógica de propagação de vínculos (Ex: Pai + Pai = Avô)
    // memberId -> parenteId (type)

    // Precisamos do gênero do memberId para definir se ele entra como Avô ou Avó
    final mRes = await _supabase
        .from('user_account')
        .select('gender')
        .eq('id', memberId)
        .maybeSingle();
    final memberGender = _toSexo(mRes?['gender'] as String?);
    final isMemberMale = memberGender == 'M';

    // Se estamos adicionando um PAI ou MÃE (memberId é pai/mãe de parenteId)
    if (type == 'pai' || type == 'mae') {
      // 1. Verificar se o PAI (memberId) tem PAIS (Avós do parenteId)
      final memberRelations = await getByMember(memberId);
      final parentsOfMember = memberRelations
          .where((r) => r.tipo == 'pai' || r.tipo == 'mae')
          .toList();

      for (final gp in parentsOfMember) {
        // gp.parenteId é o pai/mãe de memberId.
        // Logo, gp.parenteId é AVÔ/AVÓ de parenteId.
        // O tipo (Avô/Avó) depende do gênero de gp.parenteId.
        // Podemos deduzir o gênero pelo tipo da relação (pai=M, mae=F).
        final isGpMale = gp.tipo == 'pai';
        final grandParentType = isGpMale ? 'avo' : 'ava';

        // Criar vínculo: GP -> Neto(a)
        await _addRelationshipCore(
            gp.parenteId, parenteId, grandParentType);
      }

      // 2. Verificar se o FILHO (parenteId) tem FILHOS (Netos do memberId)
      final childRelations = await getByMember(parenteId);
      final childrenOfChild = childRelations
          .where((r) => r.tipo == 'pai' || r.tipo == 'mae') // Ele é pai/mãe deles
          .toList();
      
      for (final gc in childrenOfChild) {
        // memberId é AVÔ/AVÓ de gc.parenteId
        final grandParentType = isMemberMale ? 'avo' : 'ava';
        await _addRelationshipCore(
             memberId, gc.parenteId, grandParentType);
      }
    }

    // Se estamos adicionando um FILHO ou FILHA (memberId é filho/filha de parenteId)
    // É o inverso do caso acima, mas tratado separadamente para clareza
    if (type == 'filho' || type == 'filha') {
      // memberId (Filho) -> parenteId (Pai/Mãe)
      
      // 1. Verificar se o PAI (parenteId) tem PAIS (Avós do memberId)
      final parentRelations = await getByMember(parenteId);
      final grandparents = parentRelations
          .where((r) => r.tipo == 'pai' || r.tipo == 'mae')
          .toList();
      
      for (final gp in grandparents) {
        // gp.parenteId é avô/avó de memberId
        final isGpMale = gp.tipo == 'pai';
        final grandParentType = isGpMale ? 'avo' : 'ava';
        await _addRelationshipCore(gp.parenteId, memberId, grandParentType);
      }

       // 2. Verificar se o FILHO (memberId) tem FILHOS (Netos do parenteId)
       // Se o memberId já tem filhos, o parenteId vira Avô/Avó deles.
       // Precisamos saber o gênero do parenteId.
       final pRes = await _supabase
          .from('user_account')
          .select('gender')
          .eq('id', parenteId)
          .maybeSingle();
       final parentGender = _toSexo(pRes?['gender'] as String?);
       final isParentMale = parentGender == 'M';

       final memberRelations = await getByMember(memberId);
       final grandChildren = memberRelations
          .where((r) => r.tipo == 'pai' || r.tipo == 'mae') // member é pai deles
          .toList();

        for (final gc in grandChildren) {
          // parenteId é Avô/Avó de gc.parenteId
          final grandParentType = isParentMale ? 'avo' : 'ava';
          await _addRelationshipCore(parenteId, gc.parenteId, grandParentType);
        }
    }
  }

  Future<void> removeRelationship(FamilyRelationship rel) async {
    await _supabase
        .from('relacionamentos_familiares')
        .delete()
        .eq('id', rel.id);
    try {
      await _supabase
          .from('relacionamentos_familiares')
          .delete()
          .eq('membro_id', rel.parenteId)
          .eq('parente_id', rel.membroId);
    } catch (_) {
      // Se a política de RLS não permitir apagar o inverso, ignorar silenciosamente
    }
  }

  static String? _getTipoInverso(String tipo, String sexoParente) {
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
    return inv[tipo]?[sexoParente];
  }

  static String _toSexo(String? gender) {
    if (gender == 'male') return 'M';
    if (gender == 'female') return 'F';
    return 'M';
  }
}
