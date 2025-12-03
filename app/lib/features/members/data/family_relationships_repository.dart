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
      final sexoMembro = _toSexo(genderMap[otherId]);
      final sexoParente = _toSexo(genderMap[memberId]);
      final ref = _sexoReferenteParaInverso(originalTipo);
      final sexoRef = ref == 'membro' ? sexoMembro : sexoParente;
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

    return [
      ...normalizedDir,
      ...revList,
    ];
  }

  Future<void> addRelationship(String memberId, String parenteId, String tipo) async {
    // Evitar duplicado
    final existing = await _supabase
        .from('relacionamentos_familiares')
        .select('id')
        .eq('membro_id', memberId)
        .eq('parente_id', parenteId)
        .maybeSingle();
    if (existing != null) return;

    // Buscar gêneros
    final m = await _supabase
        .from('user_account')
        .select('id, gender')
        .eq('id', memberId)
        .maybeSingle();
    final p = await _supabase
        .from('user_account')
        .select('id, gender')
        .eq('id', parenteId)
        .maybeSingle();
    final sexoMembro = _toSexo(m?['gender'] as String?);
    final sexoParente = _toSexo(p?['gender'] as String?);

    await _supabase.from('relacionamentos_familiares').insert({
      'membro_id': memberId,
      'parente_id': parenteId,
      'tipo_relacionamento': tipo,
    });

    final sexoReferencia = _sexoReferenteParaInverso(tipo) == 'membro' ? sexoMembro : sexoParente;
    final tipoInverso = _getTipoInverso(tipo, sexoReferencia);
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
          // ignorar falhas por RLS ao inserir o inverso
        }
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

  static String _sexoReferenteParaInverso(String tipo) {
    if ({'filho', 'filha', 'genro', 'nora', 'neto', 'neta', 'sobrinho', 'sobrinha'}.contains(tipo)) {
      return 'membro';
    }
    if ({'pai', 'mae', 'irmao', 'irma', 'sogro', 'sogra', 'primo', 'prima', 'tio', 'tia', 'avo', 'ava'}.contains(tipo)) {
      return 'parente';
    }
    return 'parente';
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
    };
    return inv[tipo]?[sexoParente];
  }

  static String _toSexo(String? gender) {
    if (gender == 'male') return 'M';
    if (gender == 'female') return 'F';
    return 'M';
  }
}
