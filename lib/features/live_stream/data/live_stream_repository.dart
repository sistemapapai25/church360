import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/current_culto.dart';
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
    payload['tenant_id'] =
        payload['tenant_id'] ?? SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('live_stream')
        .upsert(payload, onConflict: 'tenant_id')
        .select()
        .single();

    return LiveStreamConfig.fromJson(response);
  }

  /// "Tem culto agora?" (RPC `current_culto`, 006500).
  Future<CurrentCulto> currentCulto() async =>
      CurrentCulto.fromJson(await _supabase.rpc('current_culto'));

  /// JPG por slide do PPTX, quando o worker do ONLYOFFICE já converteu
  /// (`slides_render`, 010600). Nulo = ainda não (ou falhou).
  Future<List<String>?> slideImages(String url) async {
    final row = await _supabase
        .from('slides_render')
        .select('images')
        .eq('source_url', url.trim())
        .eq('status', 'done')
        .maybeSingle();
    final images = (row?['images'] as List?)?.cast<String>();
    return (images?.isEmpty ?? true) ? null : images;
  }

  /// "Encerrar modo culto agora" (RPC `culto_mode_off`, `live_stream.manage`):
  /// desliga a chave e tira a Home do modo culto até o próximo culto da Agenda.
  Future<void> cultoModeOff() => _supabase.rpc('culto_mode_off');

  /// Slides pela tela do Culto ao vivo (RPC `culto_set_slides`, 007400,
  /// `live_stream.manage`): guarda na chave e, se há culto na Agenda hoje,
  /// vincula a ele. Devolve o culto vinculado (`event_id`, `title`,
  /// `start_hhmm`) ou `event_id` nulo. [url] nulo tira os slides.
  Future<Map<String, dynamic>> cultoSetSlides(String? url) async {
    final r = await _supabase.rpc('culto_set_slides', params: {'p_url': url});
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  // ---- PreacherLAB (N4 / PRE-129; migration 009900, edge preacherlab-sermoes) ----

  /// E-mail do dono da conta no PreacherLAB (RLS: `live_stream.manage`).
  Future<String?> preacherlabEmail() async {
    final r = await _supabase
        .from('preacherlab_conta')
        .select('email')
        .maybeSingle();
    return r?['email'] as String?;
  }

  Future<void> setPreacherlabEmail(String email) => _supabase
      .from('preacherlab_conta')
      .upsert({
        'tenant_id': SupabaseConstants.currentTenantId,
        'email': email.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'tenant_id');

  /// Sermões com .pptx pronto. Lança [FunctionException] com `status` 409
  /// (e-mail não configurado) ou 404 (e-mail não é dono no PreacherLAB).
  Future<List<Map<String, dynamic>>> preacherlabSermoes() async {
    final r = await _supabase.functions.invoke(
      'preacherlab-sermoes',
      body: {'acao': 'listar'},
    );
    final list = (r.data as Map)['sermoes'] as List? ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// O .pptx do sermão [id], já em dia com o editor do PreacherLAB.
  Future<Uint8List> preacherlabPptx(String id) async {
    final r = await _supabase.functions.invoke(
      'preacherlab-sermoes',
      body: {'acao': 'pptx', 'id': id},
    );
    return r.data as Uint8List;
  }

  Future<int> notifyLiveStreamActive({
    String? title,
    String? body,
    String? route,
  }) async {
    final response = await _supabase.rpc(
      'notify_live_stream_active',
      params: {'p_title': title, 'p_body': body, 'p_route': route},
    );
    if (response is int) return response;
    return 0;
  }
}
