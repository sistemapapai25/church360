import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

class AutoScheduleConfig {
  final String id;
  final String dispatchRuleId;
  final String title;
  final bool active;
  final String sendTime; // HH:mm
  final String timezone;
  final DateTime? nextRun;
  final DateTime? lastRun;

  const AutoScheduleConfig({
    required this.id,
    required this.dispatchRuleId,
    required this.title,
    required this.active,
    required this.sendTime,
    required this.timezone,
    this.nextRun,
    this.lastRun,
  });

  static AutoScheduleConfig fromJson(Map<String, dynamic> json) {
    final nextRunStr = json['next_run']?.toString();
    final lastRunStr = json['last_run']?.toString();
    return AutoScheduleConfig(
      id: (json['id'] ?? '').toString(),
      dispatchRuleId: (json['dispatch_rule_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      active: (json['active'] ?? true) as bool,
      sendTime: (json['send_time'] ?? '08:00').toString(),
      timezone: (json['timezone'] ?? 'America/Sao_Paulo').toString(),
      nextRun: nextRunStr != null ? DateTime.parse(nextRunStr) : null,
      lastRun: lastRunStr != null ? DateTime.parse(lastRunStr) : null,
    );
  }
}

class AutoSchedulerRepository {
  final SupabaseClient _supabase;

  AutoSchedulerRepository(this._supabase);

  Future<AutoScheduleConfig?> getByRuleId(String ruleId) async {
    final res = await _supabase
        .from('whatsapp_relatorios_automaticos')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('dispatch_rule_id', ruleId)
        .maybeSingle();
    if (res == null) return null;
    return AutoScheduleConfig.fromJson(Map<String, dynamic>.from(res));
  }

  Stream<AutoScheduleConfig?> watchByRuleId(String ruleId) {
    return _supabase
        .from('whatsapp_relatorios_automaticos')
        .stream(primaryKey: ['id'])
        .eq('dispatch_rule_id', ruleId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return AutoScheduleConfig.fromJson(Map<String, dynamic>.from(rows.first));
        });
  }

  Future<List<AutoScheduleConfig>> listAll() async {
    final res = await _supabase
        .from('whatsapp_relatorios_automaticos')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => AutoScheduleConfig.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Stream<List<AutoScheduleConfig>> watchAll() {
    return _supabase
        .from('whatsapp_relatorios_automaticos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map((e) => AutoScheduleConfig.fromJson(Map<String, dynamic>.from(e))).toList());
  }

  Future<AutoScheduleConfig> upsertForRule({
    required String ruleId,
    required String title,
    required bool active,
    required String sendTime,
    String timezone = 'America/Sao_Paulo',
  }) async {
    // Busca existente
    final existing = await _supabase
        .from('whatsapp_relatorios_automaticos')
        .select('id')
        .eq('dispatch_rule_id', ruleId)
        .maybeSingle();
    if (existing == null) {
      final res = await _supabase
          .from('whatsapp_relatorios_automaticos')
          .insert({
            'dispatch_rule_id': ruleId,
            'title': title,
            'active': active,
            'send_time': sendTime,
            'timezone': timezone,
            'next_run': null, // trigger calcula automaticamente
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();
      return AutoScheduleConfig.fromJson(Map<String, dynamic>.from(res));
    } else {
      final res = await _supabase
          .from('whatsapp_relatorios_automaticos')
          .update({
            'title': title,
            'active': active,
            'send_time': sendTime,
            'timezone': timezone,
          })
          .eq('dispatch_rule_id', ruleId)
          .select()
          .single();
      return AutoScheduleConfig.fromJson(Map<String, dynamic>.from(res));
    }
  }

  Future<void> toggleActive(String configId, bool active) async {
    await _supabase
        .from('whatsapp_relatorios_automaticos')
        .update({'active': active})
        .eq('id', configId);
  }

  Future<void> deleteSchedule(String configId) async {
    await _supabase
        .from('whatsapp_relatorios_automaticos')
        .delete()
        .eq('id', configId);
  }
}
