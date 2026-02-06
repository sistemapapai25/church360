import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../schedule/domain/schedule_pdf_renderer.dart';

import '../../data/dispatch_repository.dart';
import '../screens/dispatch_config_screen.dart';
import 'package:intl/intl.dart';
import '../../../events/domain/models/event.dart';

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref) {
  return DispatchRepository(Supabase.instance.client);
});

final allDispatchRulesProvider = FutureProvider<List<DispatchRule>>((ref) async {
  final repo = ref.watch(dispatchRepositoryProvider);
  return repo.getAllRules();
});

final dispatchActionsProvider = Provider<DispatchActions>((ref) {
  return DispatchActions(ref);
});

class DispatchActions {
  final Ref _ref;
  DispatchActions(this._ref);

  DispatchRepository get _repo => _ref.read(dispatchRepositoryProvider);

  Future<void> createRule(DispatchRule rule) async {
    await _repo.createRule(
      title: rule.title,
      type: rule.type,
      active: rule.active,
      recipients: rule.recipients,
      config: rule.config,
      templateId: rule.templateId,
    );
    _ref.invalidate(allDispatchRulesProvider);
  }

  Future<void> updateRule(String id, DispatchRule rule) async {
    await _repo.updateRule(
      id: id,
      title: rule.title,
      type: rule.type,
      active: rule.active,
      recipients: rule.recipients,
      config: rule.config,
      templateId: rule.templateId,
    );
    _ref.invalidate(allDispatchRulesProvider);
  }

  Future<void> toggleActive(String id, bool active) async {
    await _repo.toggleActive(id, active);
    _ref.invalidate(allDispatchRulesProvider);
  }

  Future<void> deleteRule(String id) async {
    await _repo.deleteRule(id);
    _ref.invalidate(allDispatchRulesProvider);
  }
}

final dispatchSchedulerProvider = Provider<DispatchSchedulerRepository>((ref) {
  return DispatchSchedulerRepository(Supabase.instance.client);
});

final dispatchSchedulerActionsProvider = Provider<DispatchSchedulerActions>((ref) {
  return DispatchSchedulerActions(ref);
});

class DispatchSchedulerActions {
  final Ref _ref;
  DispatchSchedulerActions(this._ref);
  DispatchSchedulerRepository get _repo => _ref.read(dispatchSchedulerProvider);

  Future<int> scheduleForRule(DispatchRule rule) async {
    final count = await _repo.scheduleForRule(rule);
    _ref.invalidate(recentDispatchJobsProvider);
    _ref.invalidate(dispatchJobsByStatusProvider(null));
    return count;
  }

  Future<List<String>> diagnose(DispatchRule rule) async {
    return _repo.diagnoseRule(rule);
  }
}

class MessageTemplate {
  final String id;
  final String name;
  final String content;
  final List<String> variables;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    required this.variables,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });
}

class MessageTemplateRepository {
  final SupabaseClient _supabase;
  MessageTemplateRepository(this._supabase);

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

  Future<List<MessageTemplate>> getAll() async {
    final res = await _supabase
        .from('message_template')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);
    return (res as List).map((e) {
      final m = e as Map<String, dynamic>;
      final vars = List<String>.from(m['variables'] ?? const []);
      final createdStr = m['created_at']?.toString();
      final updatedStr = m['updated_at']?.toString();
      return MessageTemplate(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        content: (m['content'] ?? '').toString(),
        variables: vars,
        isActive: (m['is_active'] ?? true) as bool,
        createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
        updatedAt: updatedStr != null ? DateTime.parse(updatedStr) : null,
      );
    }).toList();
  }

  Future<MessageTemplate?> getById(String id) async {
    final res = await _supabase
        .from('message_template')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    final vars = List<String>.from(res['variables'] ?? const []);
    final createdStr = res['created_at']?.toString();
    final updatedStr = res['updated_at']?.toString();
    return MessageTemplate(
      id: (res['id'] ?? '').toString(),
      name: (res['name'] ?? '').toString(),
      content: (res['content'] ?? '').toString(),
      variables: vars,
      isActive: (res['is_active'] ?? true) as bool,
      createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.parse(updatedStr) : null,
    );
  }

  Future<MessageTemplate> create({
    required String name,
    required String content,
    required List<String> variables,
    required bool isActive,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');
    final res = await _supabase
        .from('message_template')
        .insert({
          'name': name,
          'content': content,
          'variables': variables,
          'is_active': isActive,
          'created_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();
    final vars = List<String>.from(res['variables'] ?? const []);
    final createdStr = res['created_at']?.toString();
    final updatedStr = res['updated_at']?.toString();
    return MessageTemplate(
      id: (res['id'] ?? '').toString(),
      name: (res['name'] ?? '').toString(),
      content: (res['content'] ?? '').toString(),
      variables: vars,
      isActive: (res['is_active'] ?? true) as bool,
      createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.parse(updatedStr) : null,
    );
  }

  Future<MessageTemplate> update({
    required String id,
    String? name,
    String? content,
    List<String>? variables,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (content != null) updates['content'] = content;
    if (variables != null) updates['variables'] = variables;
    if (isActive != null) updates['is_active'] = isActive;
    final res = await _supabase
        .from('message_template')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    final vars = List<String>.from(res['variables'] ?? const []);
    final createdStr = res['created_at']?.toString();
    final updatedStr = res['updated_at']?.toString();
    return MessageTemplate(
      id: (res['id'] ?? '').toString(),
      name: (res['name'] ?? '').toString(),
      content: (res['content'] ?? '').toString(),
      variables: vars,
      isActive: (res['is_active'] ?? true) as bool,
      createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.parse(updatedStr) : null,
    );
  }

  Future<void> delete(String id) async {
    await _supabase.from('message_template').delete().eq('id', id);
  }
}

class RenderContext {
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic> payload;
  RenderContext({this.targetType, this.targetId, required this.payload});
}

typedef Resolver = Future<String?> Function(RenderContext ctx);

class VariableRegistry {
  final SupabaseClient _supabase;
  VariableRegistry(this._supabase);

  Map<String, Resolver> get resolvers => {
        'member_full_name': _memberFullName,
        'member_nickname': _memberNickname,
        'event_date': _eventDate,
        'birthday_date': _birthdayDate,
        'event_name': _eventName,
        'ministry_name': _ministryName,
        'member_phone': _memberPhone,
        'church_address': _churchAddress,
        'schedule_link': _scheduleLink,
        'event_time': _eventTime,
        'payment_date': _paymentDate,
        'due_date': _dueDate,
        'church_name': _churchName,
        'event_location_address': _eventLocation,
        'event_link': _eventLink,
      };

  Future<String?> _memberFullName(RenderContext ctx) async {
    final uid = (ctx.payload['recipient_user_id'] ?? '').toString();
    if (uid.isEmpty) return null;
    try {
      final res = await _supabase
          .from('user_account')
          .select('first_name,last_name')
          .eq('id', uid)
          .maybeSingle();
      if (res == null) return null;
      final first = (res['first_name'] ?? '').toString();
      final last = (res['last_name'] ?? '').toString();
      final name = [first, last].where((e) => e.isNotEmpty).join(' ');
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _memberNickname(RenderContext ctx) async {
    final uid = (ctx.payload['recipient_user_id'] ?? '').toString();
    if (uid.isEmpty) return null;
    try {
      final res = await _supabase
          .from('user_account')
          .select('nickname')
          .eq('id', uid)
          .maybeSingle();
      return res?['nickname']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<Event?> _getEvent(String id) async {
    try {
      final raw = await _supabase
          .from('event')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      if (raw == null) return null;
      return Event.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _eventDate(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    final ev = await _getEvent(id);
    if (ev == null) return null;
    return DateFormat('dd/MM/yyyy').format(ev.startDate);
  }

  Future<String?> _eventTime(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    final ev = await _getEvent(id);
    if (ev == null) return null;
    return DateFormat('HH:mm').format(ev.startDate);
  }

  Future<String?> _eventName(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    final ev = await _getEvent(id);
    return ev?.name;
  }

  Future<String?> _eventLocation(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    final ev = await _getEvent(id);
    return ev?.location;
  }

  Future<String?> _ministryName(RenderContext ctx) async {
    final payloadMinistryId = ctx.payload['ministry_id']?.toString();
    final cfgMinistryId = (ctx.payload['config'] is Map)
        ? (ctx.payload['config']['group_ministry_id']?.toString())
        : null;
    final targetType = ctx.targetType?.toString() ?? '';
    final targetId = ctx.targetId?.toString() ?? '';
    String? ministryId = payloadMinistryId;
    if ((ministryId == null || ministryId.isEmpty) && targetType == 'ministry' && targetId.isNotEmpty) {
      ministryId = targetId;
    }
    if (ministryId != null && ministryId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('ministry')
            .select('name')
            .eq('id', ministryId)
            .maybeSingle();
        return res?['name']?.toString();
      } catch (_) {
        return null;
      }
    }
    final eventId = ctx.payload['event_id']?.toString() ??
        (targetType == 'event' ? targetId : null);
    if (eventId == null || eventId.isEmpty) {
      final fallbackId = cfgMinistryId;
      if (fallbackId == null || fallbackId.isEmpty) return null;
      try {
        final res = await _supabase
            .from('ministry')
            .select('name')
            .eq('id', fallbackId)
            .maybeSingle();
        return res?['name']?.toString();
      } catch (_) {
        return null;
      }
    }
    try {
      final row = await _supabase
          .from('ministry_schedule')
          .select('ministry_id, ministry!fk_ministry_schedule_ministry (name)')
          .eq('event_id', eventId)
          .order('ministry_id')
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final m = row['ministry'];
      if (m is Map && m['name'] != null) {
        return m['name'].toString();
      }
      final mid = row['ministry_id']?.toString();
      if (mid == null || mid.isEmpty) return null;
      final res = await _supabase
          .from('ministry')
          .select('name')
          .eq('id', mid)
          .maybeSingle();
      return res?['name']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _memberPhone(RenderContext ctx) async {
    final phone = ctx.payload['recipient_phone']?.toString();
    if (phone != null && phone.isNotEmpty) return phone;
    final uid = (ctx.payload['recipient_user_id'] ?? '').toString();
    if (uid.isEmpty) return null;
    try {
      final res = await _supabase
          .from('user_account')
          .select('phone')
          .eq('id', uid)
          .maybeSingle();
      return res?['phone']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _churchAddress(RenderContext ctx) async {
    try {
      final res = await _supabase.from('church_info').select('address').limit(1).maybeSingle();
      return res?['address']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _churchName(RenderContext ctx) async {
    try {
      final res = await _supabase.from('church_info').select('name').limit(1).maybeSingle();
      return res?['name']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _birthdayDate(RenderContext ctx) async {
    final uid = (ctx.payload['recipient_user_id'] ?? '').toString();
    if (uid.isEmpty) return null;
    try {
      final res = await _supabase
          .from('user_account')
          .select('birthdate')
          .eq('id', uid)
          .maybeSingle();
      final v = res?['birthdate']?.toString();
      if (v == null || v.isEmpty) return null;
      final d = v.contains('T') ? v.split('T').first : v;
      final parts = d.split('-');
      if (parts.length < 3) return null;
      final dd = parts[2].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      return '$dd/$mm';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _scheduleLink(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    try {
      final bytes = await renderEventSchedulePdf(_supabase, id);
      if (bytes == null) return null;
      final fileName = 'event_${id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      try {
        await _supabase.storage.from('schedule-pdf').uploadBinary(fileName, bytes);
      } catch (_) {
        return null;
      }
      final publicUrl = _supabase.storage.from('schedule-pdf').getPublicUrl(fileName);
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _eventLink(RenderContext ctx) async {
    final id = ctx.targetId ?? (ctx.payload['event_id']?.toString());
    if (id == null || id.isEmpty) return null;
    try {
      final links = await _supabase
          .from('support_material_link')
          .select('material_id')
          .eq('link_type', 'event')
          .eq('linked_entity_id', id);
      final list = (links as List).map((e) => (e['material_id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (list.isEmpty) return null;
      final modules = await _supabase
          .from('support_material_module')
          .select('video_url,file_url')
          .inFilter('material_id', list)
          .order('order_index');
      for (final m in modules as List) {
        final v = m['video_url']?.toString();
        if (v != null && v.isNotEmpty) return v;
        final f = m['file_url']?.toString();
        if (f != null && f.isNotEmpty) return f;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _paymentDate(RenderContext ctx) async {
    final v = ctx.payload['payment_date']?.toString();
    if (v == null || v.isEmpty) return null;
    final dt = DateTime.tryParse(v);
    return dt != null ? DateFormat('dd/MM/yyyy').format(dt) : v;
  }

  Future<String?> _dueDate(RenderContext ctx) async {
    final v = ctx.payload['due_date']?.toString();
    if (v == null || v.isEmpty) return null;
    final dt = DateTime.tryParse(v);
    return dt != null ? DateFormat('dd/MM/yyyy').format(dt) : v;
  }
}

final variableRegistryProvider = Provider<VariableRegistry>((ref) {
  return VariableRegistry(Supabase.instance.client);
});

class TemplateEngine {
  final VariableRegistry registry;
  TemplateEngine(this.registry);

  Future<String> render(String template, RenderContext ctx) async {
    final regex = RegExp(r'\{([a-zA-Z0-9_]+)(\|[^}]*)?\}');
    final matches = regex.allMatches(template).toList();
    var output = template;
    for (final m in matches) {
      final full = m.group(0) ?? '';
      final name = m.group(1) ?? '';
      final modifier = m.group(2) ?? '';
      final resolver = registry.resolvers[name];
      String value = await (resolver != null ? resolver(ctx) : Future.value(null)) ?? '';
      value = _applyModifier(value, modifier);
      output = output.replaceAll(full, value);
    }
    return output;
  }

  String _applyModifier(String value, String modifier) {
    if (modifier.isEmpty) return value;
    if (modifier.startsWith('|date:')) {
      final fmt = modifier.replaceFirst('|date:', '');
      try {
        final dt = DateTime.tryParse(value) ?? DateTime.now();
        return DateFormat(fmt).format(dt);
      } catch (_) {
        return value;
      }
    }
    if (modifier.startsWith('|number:')) {
      final fmt = modifier.replaceFirst('|number:', '');
      try {
        final nf = NumberFormat(fmt);
        final n = num.tryParse(value) ?? 0;
        return nf.format(n);
      } catch (_) {
        return value;
      }
    }
    if (modifier.startsWith('|default:') && value.isEmpty) {
      return modifier.replaceFirst('|default:', '');
    }
    return value;
  }
}

final templateEngineProvider = Provider<TemplateEngine>((ref) {
  final registry = ref.read(variableRegistryProvider);
  return TemplateEngine(registry);
});

final messageTemplateRepositoryProvider = Provider<MessageTemplateRepository>((ref) {
  return MessageTemplateRepository(Supabase.instance.client);
});

final allMessageTemplatesProvider = FutureProvider<List<MessageTemplate>>((ref) async {
  final repo = ref.watch(messageTemplateRepositoryProvider);
  return repo.getAll();
});

final messageTemplateActionsProvider = Provider<MessageTemplateActions>((ref) {
  return MessageTemplateActions(ref);
});

class MessageTemplateActions {
  final Ref _ref;
  MessageTemplateActions(this._ref);

  MessageTemplateRepository get _repo => _ref.read(messageTemplateRepositoryProvider);

  Future<void> create(String name, String content, {bool isActive = true}) async {
    final vars = _extractVariables(content);
    await _repo.create(name: name, content: content, variables: vars, isActive: isActive);
    _ref.invalidate(allMessageTemplatesProvider);
  }

  Future<void> update(String id, {String? name, String? content, bool? isActive}) async {
    List<String>? vars;
    if (content != null) vars = _extractVariables(content);
    await _repo.update(id: id, name: name, content: content, variables: vars, isActive: isActive);
    _ref.invalidate(allMessageTemplatesProvider);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _ref.invalidate(allMessageTemplatesProvider);
  }

  List<String> _extractVariables(String content) {
    final regex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    final matches = regex.allMatches(content);
    final set = <String>{};
    for (final m in matches) {
      set.add(m.group(1) ?? '');
    }
    set.removeWhere((e) => e.isEmpty);
    return set.toList()..sort();
  }
}

enum DispatchStatus {
  pending('pending', 'Pendente'),
  processing('processing', 'Processando'),
  sent('sent', 'Enviado'),
  delivered('delivered', 'Entregue'),
  failed('failed', 'Falhou'),
  cancelled('cancelled', 'Cancelado');

  final String value;
  final String label;
  const DispatchStatus(this.value, this.label);

  static DispatchStatus fromValue(String value) {
    return DispatchStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DispatchStatus.pending,
    );
  }
}

class DispatchJob {
  final String id;
  final String? ruleId;
  final String? templateId;
  final String? targetType;
  final String? targetId;
  final String? recipientPhone;
  final Map<String, dynamic> payload;
  final List<String> attachments;
  final DispatchStatus status;
  final bool requiresAck;
  final bool ackReceived;
  final DateTime? ackReceivedAt;
  final DateTime scheduledAt;
  final DateTime? processedAt;
  final int retries;
  final String? lastError;
  final String? uazapiMessageId;
  final DateTime createdAt;

  const DispatchJob({
    required this.id,
    this.ruleId,
    this.templateId,
    this.targetType,
    this.targetId,
    this.recipientPhone,
    required this.payload,
    required this.attachments,
    required this.status,
    required this.requiresAck,
    required this.ackReceived,
    this.ackReceivedAt,
    required this.scheduledAt,
    this.processedAt,
    required this.retries,
    this.lastError,
    this.uazapiMessageId,
    required this.createdAt,
  });
}

class DispatchLog {
  final String id;
  final String jobId;
  final String action;
  final DispatchStatus? status;
  final String? detail;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const DispatchLog({
    required this.id,
    required this.jobId,
    required this.action,
    this.status,
    this.detail,
    required this.payload,
    required this.createdAt,
  });
}

class DispatchMonitoringRepository {
  final SupabaseClient _supabase;
  DispatchMonitoringRepository(this._supabase);

  Future<List<DispatchJob>> getJobs({DispatchStatus? status, int limit = 100}) async {
    final table = _supabase.from('dispatch_job');
    var q = table.select('*');
    if (status != null) {
      q = q.eq('status', status.value);
    }
    final res = await q.order('created_at', ascending: false).limit(limit);
    return (res as List).map((e) {
      final m = e as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(m['payload'] ?? const {});
      final attachments = List<String>.from(m['attachments'] ?? const []);
      final createdStr = m['created_at']?.toString();
      final scheduledStr = m['scheduled_at']?.toString();
      final processedStr = m['processed_at']?.toString();
      final ackStr = m['ack_received_at']?.toString();
      return DispatchJob(
        id: (m['id'] ?? '').toString(),
        ruleId: m['rule_id']?.toString(),
        templateId: m['template_id']?.toString(),
        targetType: m['target_type']?.toString(),
        targetId: m['target_id']?.toString(),
        recipientPhone: m['recipient_phone']?.toString(),
        payload: payload,
        attachments: attachments,
        status: DispatchStatus.fromValue((m['status'] ?? 'pending').toString()),
        requiresAck: (m['requires_ack'] ?? false) as bool,
        ackReceived: (m['ack_received'] ?? false) as bool,
        ackReceivedAt: ackStr != null ? DateTime.parse(ackStr) : null,
        scheduledAt: scheduledStr != null ? DateTime.parse(scheduledStr) : DateTime.now(),
        processedAt: processedStr != null ? DateTime.parse(processedStr) : null,
        retries: (m['retries'] ?? 0) as int,
        lastError: m['last_error']?.toString(),
        uazapiMessageId: m['uazapi_message_id']?.toString(),
        createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
      );
    }).toList();
  }

  Future<List<DispatchLog>> getLogs(String jobId) async {
    final res = await _supabase
        .from('dispatch_log')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('job_id', jobId)
        .order('created_at', ascending: false);
    return (res as List).map((e) {
      final m = e as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(m['payload'] ?? const {});
      final createdStr = m['created_at']?.toString();
      return DispatchLog(
        id: (m['id'] ?? '').toString(),
        jobId: (m['job_id'] ?? '').toString(),
        action: (m['action'] ?? '').toString(),
        status: m['status'] != null ? DispatchStatus.fromValue((m['status']).toString()) : null,
        detail: m['detail']?.toString(),
        payload: payload,
        createdAt: createdStr != null ? DateTime.parse(createdStr) : DateTime.now(),
      );
    }).toList();
  }

  Future<void> retryJob(String id) async {
    final current = await _supabase.from('dispatch_job').select('retries').eq('id', id).maybeSingle();
    final retries = ((current?['retries']) ?? 0) as int;
    await _supabase
        .from('dispatch_job')
        .update({
          'status': 'pending',
          'retries': retries + 1,
          'last_error': null,
          'processed_at': null,
          'scheduled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> cancelJob(String id) async {
    await _supabase.from('dispatch_job').update({'status': 'cancelled'}).eq('id', id);
  }

  Future<void> deleteJob(String id) async {
    await _supabase.from('dispatch_job').delete().eq('id', id);
  }
}

final monitoringRepositoryProvider = Provider<DispatchMonitoringRepository>((ref) {
  return DispatchMonitoringRepository(Supabase.instance.client);
});

final recentDispatchJobsProvider = FutureProvider<List<DispatchJob>>((ref) async {
  final repo = ref.watch(monitoringRepositoryProvider);
  return repo.getJobs(limit: 100);
});

final dispatchJobsByStatusProvider = FutureProvider.family<List<DispatchJob>, DispatchStatus?>((ref, status) async {
  final repo = ref.watch(monitoringRepositoryProvider);
  return repo.getJobs(status: status, limit: 100);
});

final jobLogsProvider = FutureProvider.family<List<DispatchLog>, String>((ref, jobId) async {
  final repo = ref.watch(monitoringRepositoryProvider);
  return repo.getLogs(jobId);
});

final monitoringActionsProvider = Provider<MonitoringActions>((ref) {
  return MonitoringActions(ref);
});

class MonitoringActions {
  final Ref _ref;
  MonitoringActions(this._ref);
  DispatchMonitoringRepository get _repo => _ref.read(monitoringRepositoryProvider);

  Future<void> retry(String id) async {
    await _repo.retryJob(id);
    _ref.invalidate(recentDispatchJobsProvider);
  }

  Future<void> cancel(String id) async {
    await _repo.cancelJob(id);
    _ref.invalidate(recentDispatchJobsProvider);
  }

  Future<void> delete(String id) async {
    await _repo.deleteJob(id);
    _ref.invalidate(recentDispatchJobsProvider);
  }
}

class DispatchSchedulerRepository {
  final SupabaseClient _supabase;
  DispatchSchedulerRepository(this._supabase);

  Future<int> scheduleForRule(DispatchRule rule) async {
    final cfg = Map<String, dynamic>.from(rule.config);
    final scope = (cfg['target_scope'] ?? 'all').toString();
    final targetIds = List<String>.from(cfg['target_ids'] ?? const []);
    final eventTypes = List<String>.from(cfg['event_types'] ?? const []);
    final recipientMode = (cfg['recipient_mode'] ?? 'multi').toString();
    final singlePhone = (cfg['single_phone'] ?? '').toString();
    var groupPhone = (cfg['group_phone'] ?? '').toString();
    final groupMinistryId = (cfg['group_ministry_id'] ?? '').toString();
    final manualNumbers = List<String>.from(cfg['manual_numbers'] ?? const []);
    final recipients = <({String userId, String? phone})>[];
    final notifyLeader = (() {
      final v = cfg['notify_leader'];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    })();

    if ((rule.templateId ?? '').isEmpty) {
      throw Exception('Template não vinculado à regra');
    }

    if (rule.type == DispatchRuleType.birthday) {
      List<dynamic> users;
      try {
        users = await _supabase
            .from('user_account')
            .select('id,phone,birthdate,status,assigned_mentor_id')
            .not('birthdate', 'is', null);
      } catch (e) {
        throw Exception('Erro ao buscar aniversariantes: $e');
      }
      final now = DateTime.now();
      final todays = <({String userId, String? phone})>[];
      final mentorByUser = <String, String>{};
      final leaderIds = <String>{};
      for (final u in users) {
        final id = (u['id'] ?? '').toString();
        final phone = u['phone']?.toString();
        final bdStr = u['birthdate']?.toString();
        if (bdStr == null || bdStr.isEmpty) continue;
        final d = bdStr.contains('T') ? bdStr.split('T').first : bdStr;
        final parts = d.split('-');
        if (parts.length < 3) continue;
        final mm = int.tryParse(parts[1]);
        final dd = int.tryParse(parts[2]);
        if (mm == null || dd == null) continue;
        if (mm == now.month && dd == now.day) {
          todays.add((userId: id, phone: phone));
          if (notifyLeader) {
            final mentorId = (u['assigned_mentor_id'] ?? '').toString();
            if (mentorId.isNotEmpty) {
              mentorByUser[id] = mentorId;
              leaderIds.add(mentorId);
            }
          }
        }
      }
      if (todays.isEmpty) return 0;
      var recipientsList = List<({String userId, String? phone})>.from(todays);
      if (notifyLeader && leaderIds.isNotEmpty) {
        List<dynamic> accounts = const [];
        try {
          accounts = await _supabase
              .from('user_account')
              .select('id,phone')
              .inFilter('id', leaderIds.toList());
        } catch (_) {}
        final byId = <String, String?>{};
        for (final a in accounts) {
          final lid = (a['id'] ?? '').toString();
          final lphone = a['phone']?.toString();
          byId[lid] = lphone;
        }
        for (final entry in mentorByUser.entries) {
          final userId = entry.key;
          final leaderId = entry.value;
          final phone = (byId[leaderId] ?? '').toString();
          if (phone.trim().isNotEmpty) {
            recipientsList.add((userId: userId, phone: phone));
          }
        }
      }
      final unique = <({String userId, String? phone})>[];
      final seen = <String>{};
      for (final r in recipientsList) {
        final k = '${r.userId}::${(r.phone ?? '').trim()}';
        if (k.endsWith('::')) continue;
        if (seen.add(k)) unique.add(r);
      }
      await _createJobsForRecipients(rule, 'birthday', null, unique);
      return unique.length;
    }

    if (scope == 'event_type' && eventTypes.isEmpty) {
      throw Exception('Selecione pelo menos um tipo de evento');
    }

    if (scope == 'event_type') {
      List<dynamic> res;
      try {
        res = await _supabase
            .from('event')
            .select('id,start_date')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .inFilter('event_type', eventTypes);
      } catch (e) {
        throw Exception('Erro ao buscar eventos por tipo: $e');
      }
      final rows = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final evIds = rows.map((e) => (e['id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (evIds.isEmpty && rule.type == DispatchRuleType.pdf) {
        throw Exception('Nenhum evento encontrado para os tipos selecionados');
      }
      final missingDates = rows.where((e) => ((e['start_date'] ?? '').toString()).isEmpty).toList();
      if (missingDates.isNotEmpty) {
        throw Exception('Eventos sem data/hora definidos');
      }
      recipients.addAll(await _recipientsFromEventIds(evIds));

      // Suporte a PDF: permitir gerar jobs mesmo sem inscritos, usando modo de destinatário
      if (recipients.isEmpty && rule.type == DispatchRuleType.pdf) {
        final built = <({String userId, String? phone})>[];
        if (recipientMode == 'single' && singlePhone.isNotEmpty) {
          built.add((userId: '', phone: singlePhone));
        } else if (recipientMode == 'group') {
          if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
            try {
              final m = await _supabase
                  .from('ministry')
                  .select('whatsapp_group_number')
                  .eq('id', groupMinistryId)
                  .eq('tenant_id', SupabaseConstants.currentTenantId)
                  .maybeSingle();
              final v = m?['whatsapp_group_number']?.toString() ?? '';
              groupPhone = v;
            } catch (_) {}
          }
          if (groupPhone.isEmpty) {
            throw Exception('Número do grupo não encontrado para o ministério selecionado');
          }
          built.add((userId: '', phone: groupPhone));
        } else if (recipientMode == 'multi' && manualNumbers.isNotEmpty) {
          built.addAll(manualNumbers.map((p) => (userId: '', phone: p)));
        }
        var total = 0;
        for (final ev in evIds) {
          await _createJobsForRecipients(rule, 'event', ev, built);
          total += built.length;
        }
        return total;
      }

      var totalRecipients = 0;
      for (final ev in evIds) {
        await _createJobsForRecipients(rule, 'event', ev, recipients);
        totalRecipients += recipients.length;
      }
      return totalRecipients;
    }

    if (scope == 'event') {
      List<dynamic> evRows;
      try {
        evRows = await _supabase
            .from('event')
            .select('id,start_date')
            .inFilter('id', targetIds);
      } catch (e) {
        throw Exception('Erro ao buscar eventos selecionados: $e');
      }
      final evList = evRows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final missingDatesEv = evList.where((e) => ((e['start_date'] ?? '').toString()).isEmpty).toList();
      if (missingDatesEv.isNotEmpty) {
        throw Exception('Eventos selecionados sem data/hora');
      }
      final items = await _recipientsFromEventIds(targetIds);
      recipients.addAll(items);
      if (recipients.isEmpty) {
        final built = <({String userId, String? phone})>[];
        if (recipientMode == 'single' && singlePhone.isNotEmpty) {
          built.add((userId: '', phone: singlePhone));
        } else if (recipientMode == 'group') {
          if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
            try {
              final m = await _supabase
                  .from('ministry')
                  .select('whatsapp_group_number')
                  .eq('id', groupMinistryId)
                  .maybeSingle();
              final v = m?['whatsapp_group_number']?.toString() ?? '';
              groupPhone = v;
            } catch (_) {}
          }
          if (groupPhone.isNotEmpty) {
            built.add((userId: '', phone: groupPhone));
          }
        } else if (recipientMode == 'multi' && manualNumbers.isNotEmpty) {
          built.addAll(manualNumbers.map((p) => (userId: '', phone: p)));
        }
        var total = 0;
        for (final id in targetIds) {
          await _createJobsForRecipients(rule, 'event', id, built);
          total += built.length;
        }
        return total;
      }
      var total = 0;
      for (final id in targetIds) {
        await _createJobsForRecipients(rule, 'event', id, items);
        total += items.length;
      }
      return total;
    }

    if (scope == 'ministry') {
      final items = await _recipientsFromMinistryIds(targetIds);
      if (items.isEmpty && recipientMode != 'group') {
        throw Exception('Nenhum membro com telefone no(s) ministério(s) selecionado(s)');
      }
      recipients.addAll(items);
      var total = 0;
      for (final id in targetIds) {
        await _createJobsForRecipients(rule, 'ministry', id, items);
        total += items.length;
      }
      return total;
    }

    if (scope == 'communion_group') {
      final items = await _recipientsFromGroupIds(targetIds);
      recipients.addAll(items);
      var total = 0;
      for (final id in targetIds) {
        await _createJobsForRecipients(rule, 'group', id, items);
        total += items.length;
      }
      return total;
    }

    if (scope == 'study_group') {
      final items = await _recipientsFromStudyGroupIds(targetIds);
      recipients.addAll(items);
      var total = 0;
      for (final id in targetIds) {
        await _createJobsForRecipients(rule, 'study_group', id, items);
        total += items.length;
      }
      return total;
    }

    if (scope == 'course') {
      final items = await _recipientsFromCourseIds(targetIds);
      recipients.addAll(items);
      var total = 0;
      for (final id in targetIds) {
        await _createJobsForRecipients(rule, 'course', id, items);
        total += items.length;
      }
      return total;
    }

    if (recipientMode == 'single' && singlePhone.isNotEmpty) {
      await _createJobsForRecipients(rule, 'manual', null, [(userId: '', phone: singlePhone)]);
      return 1;
    }
    if (recipientMode == 'group') {
      if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
        try {
          final m = await _supabase
              .from('ministry')
              .select('whatsapp_group_number')
              .eq('id', groupMinistryId)
              .maybeSingle();
          final v = m?['whatsapp_group_number']?.toString() ?? '';
          groupPhone = v;
        } catch (_) {}
      }
      if (groupPhone.isNotEmpty) {
        await _createJobsForRecipients(rule, 'group_number', null, [(userId: '', phone: groupPhone)]);
        return 1;
      }
      throw Exception('Número do grupo não encontrado');
    }
    if (recipientMode == 'multi' && manualNumbers.isNotEmpty) {
      final list = manualNumbers.map((p) => (userId: '', phone: p)).toList();
      await _createJobsForRecipients(rule, 'manual_list', null, list);
      return list.length;
    }
    return 0;
  }

  Future<void> _createJobsForRecipients(
    DispatchRule rule,
    String targetType,
    String? targetId,
    List<({String userId, String? phone})> recipients,
  ) async {
    final sanitized = <({String userId, String? phone})>[];
    for (final r in recipients) {
      final raw = (r.phone ?? '').trim();
      if (raw.isEmpty) continue;
      final phone = raw.contains('@g.us') ? raw : raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.isEmpty) continue;
      sanitized.add((userId: r.userId, phone: phone));
    }
    final validRecipients = sanitized;
    if (validRecipients.isEmpty) return;
    List<String> attachments = [];
    if (targetType == 'event' && targetId != null && targetId.isNotEmpty) {
      final url = await _ensureEventSchedulePdfAttachment(targetId);
      if (url != null && url.isNotEmpty) {
        attachments = [url];
      }
    }
    final rows = <Map<String, dynamic>>[];
    for (final r in validRecipients) {
      rows.add({
        'rule_id': rule.id,
        'template_id': rule.templateId,
        'target_type': targetType,
        'target_id': targetId,
        'recipient_phone': r.phone,
        'payload': {
          'rule_type': rule.type.value,
          'config': rule.config,
          'recipient_user_id': r.userId,
          'recipient_phone': r.phone,
          'event_id': targetType == 'event' ? targetId : null,
        },
        'attachments': attachments,
        'status': 'pending',
        'requires_ack': false,
        'ack_received': false,
        'scheduled_at': DateTime.now().toIso8601String(),
        'retries': 0,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    }
    try {
      await _supabase.from('dispatch_job').insert(rows);
    } catch (e) {
      throw Exception('Erro ao inserir jobs: $e');
    }
  }

  Future<String?> _ensureEventSchedulePdfAttachment(String eventId) async {
    try {
      final raw = await _supabase
          .from('ministry_schedule')
          .select('''
            event!fk_ministry_schedule_event (name,start_date),
            ministry!fk_ministry_schedule_ministry (name),
            user_account!fk_ministry_schedule_user (first_name,last_name,nickname),
            ministry_function:function_id (name,code)
          ''')
          .eq('event_id', eventId);
      final res = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (res.isEmpty) {
        return null;
      }
      final bytes = await renderEventSchedulePdf(_supabase, eventId);
      final fileName = 'event_${eventId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      try {
        if (bytes == null) return null;
        await _supabase.storage.from('schedule-pdf').uploadBinary(fileName, bytes);
      } catch (_) {
        return null;
      }
      final publicUrl = _supabase.storage.from('schedule-pdf').getPublicUrl(fileName);
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<List<({String userId, String? phone})>> _recipientsFromEventIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return const [];
    List<dynamic> regs;
    try {
      regs = await _supabase
          .from('event_registration')
          .select('user_id')
          .inFilter('event_id', eventIds);
    } catch (e) {
      throw Exception('Erro ao buscar inscritos do evento: $e');
    }
    final ids = regs
        .map((row) => (row['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    List<dynamic> accounts;
    try {
      accounts = await _supabase
          .from('user_account')
          .select('id,phone')
          .inFilter('id', ids)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      throw Exception('Erro ao buscar telefones dos inscritos: $e');
    }
    final byId = <String, String?>{};
    for (final a in accounts) {
      final id = (a['id'] ?? '').toString();
      final phone = a['phone']?.toString();
      byId[id] = phone;
    }
    return ids.map((uid) => (userId: uid, phone: byId[uid])).toList();
  }

  Future<List<({String userId, String? phone})>> _recipientsFromMinistryIds(List<String> ministryIds) async {
    if (ministryIds.isEmpty) return const [];
    final List<dynamic> rows = await _supabase
        .from('ministry_member')
        .select('user_id')
        .inFilter('ministry_id', ministryIds);
    final ids = rows
        .map((row) => (row['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final List<dynamic> accounts = await _supabase
        .from('user_account')
        .select('id,phone')
        .inFilter('id', ids)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    final byId = <String, String?>{};
    for (final a in accounts) {
      final id = (a['id'] ?? '').toString();
      final phone = a['phone']?.toString();
      byId[id] = phone;
    }
    return ids.map((uid) => (userId: uid, phone: byId[uid])).toList();
  }

  Future<List<({String userId, String? phone})>> _recipientsFromGroupIds(List<String> groupIds) async {
    if (groupIds.isEmpty) return const [];
    final List<dynamic> rows = await _supabase
        .from('group_member')
        .select('user_id')
        .inFilter('group_id', groupIds);
    final ids = rows
        .map((row) => (row['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final List<dynamic> accounts = await _supabase
        .from('user_account')
        .select('id,phone')
        .inFilter('id', ids)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
    final byId = <String, String?>{};
    for (final a in accounts) {
      final id = (a['id'] ?? '').toString();
      final phone = a['phone']?.toString();
      byId[id] = phone;
    }
    return ids.map((uid) => (userId: uid, phone: byId[uid])).toList();
  }

  Future<List<({String userId, String? phone})>> _recipientsFromStudyGroupIds(List<String> studyGroupIds) async {
    if (studyGroupIds.isEmpty) return const [];
    final List<dynamic> rows = await _supabase
        .from('study_participants')
        .select('user_id')
        .inFilter('study_group_id', studyGroupIds)
        .eq('is_active', true);
    final ids = rows
        .map((row) => (row['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final List<dynamic> accounts = await _supabase
        .from('user_account')
        .select('id,phone')
        .inFilter('id', ids);
    final byId = <String, String?>{};
    for (final a in accounts) {
      final id = (a['id'] ?? '').toString();
      final phone = a['phone']?.toString();
      byId[id] = phone;
    }
    return ids.map((uid) => (userId: uid, phone: byId[uid])).toList();
  }

  Future<List<({String userId, String? phone})>> _recipientsFromCourseIds(List<String> courseIds) async {
    if (courseIds.isEmpty) return const [];
    final List<dynamic> rows = await _supabase
        .from('course_enrollment')
        .select('user_id')
        .inFilter('course_id', courseIds);
    final ids = rows
        .map((row) => (row['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final List<dynamic> accounts = await _supabase
        .from('user_account')
        .select('id,phone')
        .inFilter('id', ids);
    final byId = <String, String?>{};
    for (final a in accounts) {
      final id = (a['id'] ?? '').toString();
      final phone = a['phone']?.toString();
      byId[id] = phone;
    }
    return ids.map((uid) => (userId: uid, phone: byId[uid])).toList();
  }

  Future<List<String>> diagnoseRule(DispatchRule rule) async {
    final cfg = Map<String, dynamic>.from(rule.config);
    final scope = (cfg['target_scope'] ?? 'all').toString();
    final targetIds = List<String>.from(cfg['target_ids'] ?? const []);
    final eventTypes = List<String>.from(cfg['event_types'] ?? const []);
    final recipientMode = (cfg['recipient_mode'] ?? 'multi').toString();
    final singlePhone = (cfg['single_phone'] ?? '').toString();
    var groupPhone = (cfg['group_phone'] ?? '').toString();
    final groupMinistryId = (cfg['group_ministry_id'] ?? '').toString();
    final manualNumbers = List<String>.from(cfg['manual_numbers'] ?? const []);
    final reasons = <String>[];

    if ((rule.templateId ?? '').isEmpty) {
      reasons.add('Template não vinculado à regra');
    }

    if (rule.type == DispatchRuleType.birthday) {
      List<dynamic> users = [];
      try {
        users = await _supabase
            .from('user_account')
            .select('id,phone,birthdate')
            .not('birthdate', 'is', null);
      } catch (_) {}
      final now = DateTime.now();
      int totalToday = 0;
      int missingPhone = 0;
      for (final u in users) {
        final bdStr = u['birthdate']?.toString();
        if (bdStr == null || bdStr.isEmpty) continue;
        final d = bdStr.contains('T') ? bdStr.split('T').first : bdStr;
        final parts = d.split('-');
        if (parts.length < 3) continue;
        final mm = int.tryParse(parts[1]);
        final dd = int.tryParse(parts[2]);
        if (mm == null || dd == null) continue;
        if (mm == now.month && dd == now.day) {
          totalToday++;
          final phone = (u['phone'] ?? '').toString().trim();
          if (phone.isEmpty) missingPhone++;
        }
      }
      if (totalToday == 0) {
        reasons.add('Nenhum aniversariante hoje');
      } else if (missingPhone > 0) {
        reasons.add('Aniversariantes sem telefone: $missingPhone');
      }
      return reasons;
    }

    if (scope == 'event_type') {
      if (eventTypes.isEmpty) {
        reasons.add('Selecione pelo menos um tipo de evento');
        return reasons;
      }
      final res = await _supabase
          .from('event')
          .select('id')
          .inFilter('event_type', eventTypes);
      final evIds = (res as List).map((e) => (e['id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (evIds.isEmpty) {
        reasons.add('Nenhum evento encontrado para os tipos selecionados');
        return reasons;
      }
      final rec = await _recipientsFromEventIds(evIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (rule.type == DispatchRuleType.pdf && valid.isEmpty) {
        if (recipientMode == 'single') {
          if (singlePhone.isEmpty) reasons.add('Destino único não preenchido');
        } else if (recipientMode == 'group') {
          if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
            try {
              final m = await _supabase
                  .from('ministry')
                  .select('whatsapp_group_number')
                  .eq('id', groupMinistryId)
                  .maybeSingle();
              final v = m?['whatsapp_group_number']?.toString() ?? '';
              groupPhone = v;
            } catch (_) {}
          }
          if (groupPhone.isEmpty) reasons.add('Número do grupo não encontrado para o ministério selecionado');
        } else if (recipientMode == 'multi') {
          if (manualNumbers.isEmpty) reasons.add('Lista de números manual não preenchida');
        }
        if (missingCount > 0) reasons.add('Inscritos sem telefone: $missingCount');
      }
      return reasons;
    }

    if (scope == 'event') {
      final rec = await _recipientsFromEventIds(targetIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (valid.isEmpty) {
        if (recipientMode == 'single') {
          if (singlePhone.isEmpty) reasons.add('Destino único não preenchido');
        } else if (recipientMode == 'group') {
          if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
            try {
              final m = await _supabase
                  .from('ministry')
                  .select('whatsapp_group_number')
                  .eq('id', groupMinistryId)
                  .maybeSingle();
              final v = m?['whatsapp_group_number']?.toString() ?? '';
              groupPhone = v;
            } catch (_) {}
          }
          if (groupPhone.isEmpty) reasons.add('Número do grupo não encontrado para o ministério selecionado');
        } else if (recipientMode == 'multi') {
          if (manualNumbers.isEmpty) reasons.add('Lista de números manual não preenchida');
        } else {
          reasons.add('Nenhum inscrito com telefone nos eventos selecionados');
        }
        if (missingCount > 0) reasons.add('Inscritos sem telefone: $missingCount');
      }
      return reasons;
    }

    if (scope == 'ministry') {
      final rec = await _recipientsFromMinistryIds(targetIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (valid.isEmpty && recipientMode != 'group') {
        reasons.add('Nenhum membro com telefone no(s) ministério(s) selecionado(s)');
        if (missingCount > 0) reasons.add('Membros sem telefone: $missingCount');
      }
      if (recipientMode == 'group') {
        if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
          try {
            final m = await _supabase
                .from('ministry')
                .select('whatsapp_group_number')
                .eq('id', groupMinistryId)
                .maybeSingle();
            final v = m?['whatsapp_group_number']?.toString() ?? '';
            groupPhone = v;
          } catch (_) {}
        }
        if (groupPhone.isEmpty) reasons.add('Número do grupo não encontrado para o ministério selecionado');
      }
      return reasons;
    }

    if (scope == 'communion_group') {
      final rec = await _recipientsFromGroupIds(targetIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      if (valid.isEmpty) reasons.add('Nenhum membro com telefone nos grupos de comunhão selecionados');
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (missingCount > 0) reasons.add('Membros sem telefone: $missingCount');
      return reasons;
    }

    if (scope == 'study_group') {
      final rec = await _recipientsFromStudyGroupIds(targetIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      if (valid.isEmpty) reasons.add('Nenhum participante com telefone nos grupos de estudo selecionados');
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (missingCount > 0) reasons.add('Participantes sem telefone: $missingCount');
      return reasons;
    }

    if (scope == 'course') {
      final rec = await _recipientsFromCourseIds(targetIds);
      final valid = rec.where((r) => (r.phone ?? '').trim().isNotEmpty).toList();
      if (valid.isEmpty) reasons.add('Nenhum aluno com telefone nos cursos selecionados');
      final missingCount = rec.where((r) => (r.phone ?? '').trim().isEmpty).length;
      if (missingCount > 0) reasons.add('Alunos sem telefone: $missingCount');
      return reasons;
    }

    if (recipientMode == 'single') {
      if (singlePhone.isEmpty) reasons.add('Destino único não preenchido');
    } else if (recipientMode == 'group') {
      if (groupPhone.isEmpty && groupMinistryId.isNotEmpty) {
        try {
          final m = await _supabase
              .from('ministry')
              .select('whatsapp_group_number')
              .eq('id', groupMinistryId)
              .maybeSingle();
          final v = m?['whatsapp_group_number']?.toString() ?? '';
          groupPhone = v;
        } catch (_) {}
      }
      if (groupPhone.isEmpty) reasons.add('Número do grupo não encontrado');
    } else if (recipientMode == 'multi') {
      if (manualNumbers.isEmpty) reasons.add('Lista de números manual não preenchida');
    }
    return reasons;
  }
}
