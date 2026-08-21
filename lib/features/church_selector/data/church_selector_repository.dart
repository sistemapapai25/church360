import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository para troca de unidade ativa (matriz/filial, CHU-300).
class ChurchSelectorRepository {
  final SupabaseClient _supabase;

  ChurchSelectorRepository(this._supabase);

  /// Ativa [tenantId] como a unidade atual do usuário (flip de
  /// `user_tenant_membership.is_active` no servidor).
  Future<void> trocarDeIgreja(String tenantId) async {
    await _supabase.rpc('trocar_de_igreja', params: {
      'p_tenant_id': tenantId,
    });
  }
}
