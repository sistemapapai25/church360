import 'package:supabase_flutter/supabase_flutter.dart';

import '../../access_levels/domain/models/access_level.dart';
import '../domain/models/tenant_unit.dart';

/// Repository para gestão de filiais (matriz/filial, CHU-289).
class BranchesRepository {
  final SupabaseClient _supabase;

  BranchesRepository(this._supabase);

  /// Matriz + filiais da rede do usuário atual.
  Future<List<TenantUnit>> listMyNetworkUnits() async {
    final response = await _supabase.rpc('listar_minhas_igrejas');
    return (response as List)
        .map((json) => TenantUnit.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cria uma filial sob a matriz do usuário atual. Retorna o novo tenant_id.
  Future<String> criarFilial({
    required String nome,
    required String pastorResponsavelId,
  }) async {
    final response = await _supabase.rpc('criar_filial', params: {
      'p_nome': nome,
      'p_pastor_responsavel_id': pastorResponsavelId,
    });
    return response as String;
  }

  /// Nível de acesso do usuário atual no tenant informado. Espelha a checagem
  /// que `criar_filial` já faz no servidor — defesa em profundidade no
  /// cliente, não a autorização real.
  Future<int?> getMyAccessLevelNumber(String tenantId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('user_tenant_membership')
        .select('access_level_number')
        .eq('user_id', userId)
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .maybeSingle();
    return row?['access_level_number'] as int?;
  }

  /// Confirma que o `Member.id` escolhido no picker de pastor tem conta
  /// auth provisionada, antes de mandar pro `criar_filial` (que exige um
  /// `auth.users.id` válido). Mesmo padrão de `assign_role_screen.dart`.
  Future<String?> resolveAuthUserId(String candidateId) async {
    final row = await _supabase
        .from('user_access_level')
        .select('user_id')
        .eq('user_id', candidateId)
        .maybeSingle();
    return row?['user_id'] as String?;
  }

  /// Concede um cargo específico a um usuário numa unidade que não é a
  /// atual do chamador (CHU-301) — sem precisar trocar de unidade antes.
  /// Autorização real é feita no servidor por `conceder_acesso_em_unidade`.
  Future<void> concederAcessoEmUnidade({
    required String tenantId,
    required String userId,
    required AccessLevelType accessLevel,
  }) async {
    await _supabase.rpc('conceder_acesso_em_unidade', params: {
      'p_tenant_id': tenantId,
      'p_user_id': userId,
      'p_access_level': accessLevel.name,
    });
  }
}
