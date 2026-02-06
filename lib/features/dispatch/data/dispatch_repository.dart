import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../presentation/screens/dispatch_config_screen.dart';

class DispatchRepository {
  final SupabaseClient _supabase;
  DispatchRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  Future<List<Map<String, dynamic>>> _selectRulesRaw() async {
    final res = await _supabase
        .from('dispatch_rule')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<DispatchRule>> getAllRules() async {
    final rows = await _selectRulesRaw();
    return rows.map((json) {
      final recipients = List<String>.from(json['recipients'] ?? const []);
      final cfg = Map<String, dynamic>.from(json['config'] ?? const {});
      final typeStr = (json['type'] ?? '').toString();
      final type = DispatchRuleType.fromValue(typeStr);
      final createdAtStr = json['created_at']?.toString();
      final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      return DispatchRule(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        type: type,
        active: (json['active'] ?? true) as bool,
        recipients: recipients,
        config: cfg,
        templateId: (json['template_id']?.toString()),
        createdAt: createdAt,
      );
    }).toList();
  }

  Future<DispatchRule> createRule({
    required String title,
    required DispatchRuleType type,
    required bool active,
    required List<String> recipients,
    Map<String, dynamic>? config,
    String? templateId,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }
    final payload = {
      'title': title,
      'type': type.value,
      'active': active,
      'recipients': recipients,
      'config': config ?? <String, dynamic>{},
      'template_id': templateId,
      'created_by': userId,
      'tenant_id': SupabaseConstants.currentTenantId,
    };
    final res = await _supabase
        .from('dispatch_rule')
        .insert(payload)
        .select()
        .single();
    final recipientsOut = List<String>.from(res['recipients'] ?? const []);
    final cfgOut = Map<String, dynamic>.from(res['config'] ?? const {});
    final createdAtStr = res['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
    return DispatchRule(
      id: (res['id'] ?? '').toString(),
      title: (res['title'] ?? '').toString(),
      type: DispatchRuleType.fromValue((res['type'] ?? '').toString()),
      active: (res['active'] ?? true) as bool,
      recipients: recipientsOut,
      config: cfgOut,
      templateId: (res['template_id']?.toString()),
      createdAt: createdAt,
    );
  }

  Future<DispatchRule> updateRule({
    required String id,
    String? title,
    DispatchRuleType? type,
    bool? active,
    List<String>? recipients,
    Map<String, dynamic>? config,
    String? templateId,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (type != null) updates['type'] = type.value;
    if (active != null) updates['active'] = active;
    if (recipients != null) updates['recipients'] = recipients;
    if (config != null) updates['config'] = config;
    if (templateId != null) updates['template_id'] = templateId;
    final res = await _supabase
        .from('dispatch_rule')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    final recipientsOut = List<String>.from(res['recipients'] ?? const []);
    final cfgOut = Map<String, dynamic>.from(res['config'] ?? const {});
    final createdAtStr = res['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
    return DispatchRule(
      id: (res['id'] ?? '').toString(),
      title: (res['title'] ?? '').toString(),
      type: DispatchRuleType.fromValue((res['type'] ?? '').toString()),
      active: (res['active'] ?? true) as bool,
      recipients: recipientsOut,
      config: cfgOut,
      templateId: (res['template_id']?.toString()),
      createdAt: createdAt,
    );
  }

  Future<void> deleteRule(String id) async {
    await _supabase.from('dispatch_rule').delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool active) async {
    await _supabase.from('dispatch_rule').update({'active': active}).eq('id', id);
  }
}
