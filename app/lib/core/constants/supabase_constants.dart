import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Constantes do Supabase
/// Credenciais para conexão com o backend
class SupabaseConstants {
  // URL do projeto Supabase
  static const String supabaseUrl = 'https://heswheljavpcyspuicsi.supabase.co';
  
  // Anon Key (chave pública - seguro para expor no app)
  static const String supabaseAnonKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhlc3doZWxqYXZwY3lzcHVpY3NpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3NDc4NDMsImV4cCI6MjA2NTMyMzg0M30.JcGUOFynclGhrLRuZbiGMXsNviMLLBSLZ4l89HgDvNg';
  
  // ⚠️ NUNCA exponha o service_role key no app!
  // Ele deve ser usado apenas em scripts backend
  static const String defaultTenantId = 'd5a1cbee-99f4-4c12-8bd8-55c8c22c2645';
  static String currentTenantId = defaultTenantId;

  static const String tenantPrefsKey = 'active_tenant_id';

  static Map<String, String> get tenantHeaders => {
        'x-tenant-id': currentTenantId,
      };

  static Future<void> loadPersistedTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString(tenantPrefsKey) ?? '').trim();
    if (saved.isNotEmpty) currentTenantId = saved;
  }

  static Future<void> setTenantId(
    String tenantId, {
    SupabaseClient? client,
    bool persist = true,
  }) async {
    final next = tenantId.trim();
    if (next.isEmpty) return;
    currentTenantId = next;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tenantPrefsKey, next);
    }
    if (client != null) applyTenantHeadersToClient(client);
  }

  static void applyTenantHeadersToClient(SupabaseClient client) {
    client.rest.headers['x-tenant-id'] = currentTenantId;
    client.functions.headers['x-tenant-id'] = currentTenantId;
    client.storage.headers['x-tenant-id'] = currentTenantId;
  }

  static Future<String?> resolveBestTenantId(SupabaseClient client) async {
    final user = client.auth.currentUser ?? client.auth.currentSession?.user;
    if (user == null) return null;

    final preferred = currentTenantId.trim();
    final jwtTenant = (user.userMetadata?['tenant_id'] ?? user.appMetadata['tenant_id'])
        ?.toString()
        .trim();

    List<String> memberships = const [];
    try {
      final rows = await client
          .from('user_tenant_membership')
          .select('tenant_id, is_active')
          .eq('user_id', user.id)
          .eq('is_active', true);
      memberships = (rows as List)
          .map((e) => (e as Map)['tenant_id']?.toString().trim())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {}

    if (memberships.isNotEmpty) {
      if (preferred.isNotEmpty && memberships.contains(preferred)) return preferred;
      if (jwtTenant != null && jwtTenant.isNotEmpty && memberships.contains(jwtTenant)) return jwtTenant;
      return memberships.first;
    }

    try {
      final rows = await client
          .from('user_access_level')
          .select('tenant_id, access_level_number')
          .eq('user_id', user.id)
          .not('tenant_id', 'is', null)
          .order('access_level_number', ascending: false);
      final candidates = (rows as List)
          .map((e) => (e as Map)['tenant_id']?.toString().trim())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (candidates.isNotEmpty) {
        if (preferred.isNotEmpty && candidates.contains(preferred)) return preferred;
        if (jwtTenant != null && jwtTenant.isNotEmpty && candidates.contains(jwtTenant)) return jwtTenant;
        return candidates.first;
      }
    } catch (_) {}

    try {
      final row = await client
          .from('user_account')
          .select('tenant_id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      final tid = row?['tenant_id']?.toString().trim();
      if (tid != null && tid.isNotEmpty) return tid;
    } catch (_) {}

    try {
      final row = await client
          .from('user_account')
          .select('tenant_id')
          .eq('id', user.id)
          .maybeSingle();
      final tid = row?['tenant_id']?.toString().trim();
      if (tid != null && tid.isNotEmpty) return tid;
    } catch (_) {}

    if (jwtTenant != null && jwtTenant.isNotEmpty) return jwtTenant;
    if (preferred.isNotEmpty) return preferred;
    return null;
  }

  static Future<void> syncTenantFromServer(
    SupabaseClient client, {
    bool persist = true,
    bool syncJwt = true,
  }) async {
    final next = await resolveBestTenantId(client);
    if (next != null && next.isNotEmpty) {
      await setTenantId(next, client: client, persist: persist);
    } else {
      applyTenantHeadersToClient(client);
    }

    if (!syncJwt) return;
    try {
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'tenant_id': currentTenantId,
          },
        ),
      );
      await client.auth.refreshSession();
    } catch (_) {}
  }
}
