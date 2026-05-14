import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/ministry_notification_config.dart';

/// Lote 11.5 — Repository pra `ministry_change_notification_config`.
/// CRUD direto via supabase. RLS é permissiva (qualquer authenticated);
/// o controle de quem pode editar fica na UI (permissão `ministries.edit`).
class MinistryNotificationConfigRepository {
  final SupabaseClient _supabase;
  MinistryNotificationConfigRepository(this._supabase);

  static const _table = 'ministry_change_notification_config';

  /// Lê a config de um ministério. Retorna `null` se ainda não existe row
  /// (caller pode usar `MinistryNotificationConfig.defaultFor(id)`).
  Future<MinistryNotificationConfig?> getByMinistry(String ministryId) async {
    final row = await _supabase
        .from(_table)
        .select()
        .eq('ministry_id', ministryId)
        .maybeSingle();
    if (row == null) return null;
    return MinistryNotificationConfig.fromJson(Map<String, dynamic>.from(row));
  }

  /// Upsert do registro completo. Retorna a versão persistida.
  Future<MinistryNotificationConfig> upsert(
    MinistryNotificationConfig config,
  ) async {
    final res = await _supabase
        .from(_table)
        .upsert(config.toUpsertJson(), onConflict: 'ministry_id')
        .select()
        .single();
    return MinistryNotificationConfig.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String ministryId) async {
    await _supabase.from(_table).delete().eq('ministry_id', ministryId);
  }
}
