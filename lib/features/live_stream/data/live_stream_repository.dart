import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/live_stream.dart';

/// Repository para gerenciar culto ao vivo
class LiveStreamRepository {
  final SupabaseClient _supabase;

  LiveStreamRepository(this._supabase);

  Future<LiveStreamConfig?> getLiveStreamConfig() async {
    final response = await _supabase
        .from('live_stream')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('updated_at', ascending: false)
        .limit(1);

    if (response.isNotEmpty) {
      return LiveStreamConfig.fromJson(response.first);
    }
    return null;
  }

  Future<LiveStreamConfig?> getActiveLiveStream() async {
    final response = await _supabase
        .from('live_stream')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true)
        .order('updated_at', ascending: false)
        .limit(1);

    if (response.isNotEmpty) {
      return LiveStreamConfig.fromJson(response.first);
    }
    return null;
  }

  Future<LiveStreamConfig> upsertLiveStreamConfig(
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['tenant_id'] = payload['tenant_id'] ?? SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('live_stream')
        .upsert(payload, onConflict: 'tenant_id')
        .select()
        .single();

    return LiveStreamConfig.fromJson(response);
  }

  Future<int> notifyLiveStreamActive({
    String? title,
    String? body,
    String? route,
  }) async {
    final response = await _supabase.rpc(
      'notify_live_stream_active',
      params: {
        'p_title': title,
        'p_body': body,
        'p_route': route,
      },
    );
    if (response is int) return response;
    return 0;
  }
}
