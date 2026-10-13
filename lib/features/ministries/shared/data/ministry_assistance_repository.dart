import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/ministry_assistance.dart';
import 'ministry_routine_repository.dart';

/// Assistência do ministério. O cliente só faz SELECT; toda escrita passa
/// pelas RPCs da migration `20261008004300_ministerio_assistencia` (que
/// também gravam o registro LGPD). Erros saem como [MinistryRoutineException].
class MinistryAssistanceRepository {
  final SupabaseClient _supabase;

  MinistryAssistanceRepository(this._supabase);

  /// (vê, gerencia).
  Future<(bool, bool)> caps(String ministryId) async {
    final r = await _rpc('ministry_assist_caps', {'p_ministry_id': ministryId});
    final m = r is Map ? r : const {};
    return (m['can_view'] == true, m['can_manage'] == true);
  }

  Future<List<AssistedFamily>> getFamilies(String ministryId) async {
    try {
      final rows = await _supabase
          .from('ministry_assisted_family')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('ministry_id', ministryId)
          .order('name');
      return [
        for (final r in rows as List)
          AssistedFamily.fromJson(r as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw MinistryRoutineException(e.message);
    }
  }

  Future<List<Assistance>> getAssistances(String familyId) async {
    try {
      final rows = await _supabase
          .from('ministry_assistance')
          .select('*, ministry_stock_item(name)')
          .eq('family_id', familyId)
          .order('happened_on', ascending: false)
          .limit(100);
      return [
        for (final r in rows as List)
          Assistance.fromJson(r as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw MinistryRoutineException(e.message);
    }
  }

  Future<void> saveFamily({
    required String ministryId,
    String? familyId,
    String? memberId,
    required String name,
    String? phone,
    String? address,
    int? householdSize,
    String? need,
    FamilyStatus status = FamilyStatus.ativa,
    String? notes,
  }) => _rpc('ministry_assist_family_save', {
    'p_ministry_id': ministryId,
    'p_family_id': familyId,
    'p_member_id': memberId,
    'p_name': name,
    'p_phone': phone,
    'p_address': address,
    'p_household_size': householdSize,
    'p_need': need,
    'p_status': status.value,
    'p_notes': notes,
  });

  Future<void> deleteFamily(String familyId) =>
      _rpc('ministry_assist_family_delete', {'p_family_id': familyId});

  Future<void> record({
    required String familyId,
    required AssistanceKind kind,
    DateTime? happenedOn,
    String? notes,
    String? stockItemId,
    double? quantity,
  }) => _rpc('ministry_assist_record', {
    'p_family_id': familyId,
    'p_kind': kind.value,
    'p_happened_on': happenedOn?.toIso8601String().substring(0, 10),
    'p_notes': notes,
    'p_stock_item_id': stockItemId,
    'p_quantity': quantity,
  });

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw MinistryRoutineException(_acentuar(e.message));
    }
  }

  static const _acentos = {
    'Sem permissao': 'Sem permissão',
    'familias assistidas': 'famílias assistidas',
    'Assistencia esta desligada neste ministerio':
        'Assistência está desligada neste ministério',
    'Situacao invalida': 'Situação inválida',
    'Familia nao encontrada': 'Família não encontrada',
    'Membro nao encontrado': 'Membro não encontrado',
    'Tipo de atendimento invalido': 'Tipo de atendimento inválido',
    'nao pode ser no futuro': 'não pode ser no futuro',
    'A observacao': 'A observação',
    'nao encontrado neste ministerio': 'não encontrado neste ministério',
    'so numero inteiro': 'só número inteiro',
    'Estoque disponivel': 'Estoque disponível',
  };

  String _acentuar(String s) {
    var out = s;
    _acentos.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
