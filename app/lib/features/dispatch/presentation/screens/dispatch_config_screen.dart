import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dispatch_providers.dart';
import '../providers/auto_scheduler_providers.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../support_materials/domain/models/support_material_link.dart';
import '../../../support_materials/presentation/widgets/entity_selector_dialog.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';

enum DispatchRuleType {
  birthday('birthday', 'Aniversários'),
  event('event', 'Evento'),
  schedule('schedule', 'Escala'),
  pdf('pdf', 'PDF');

  final String value;
  final String label;
  const DispatchRuleType(this.value, this.label);

  static DispatchRuleType fromValue(String value) {
    return DispatchRuleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DispatchRuleType.event,
    );
  }
}

class DispatchRule {
  final String id;
  final String title;
  final DispatchRuleType type;
  final bool active;
  final List<String> recipients;
  final Map<String, dynamic> config;
  final String? templateId;
  final DateTime createdAt;

  const DispatchRule({
    required this.id,
    required this.title,
    required this.type,
    required this.active,
    required this.recipients,
    required this.config,
    this.templateId,
    required this.createdAt,
  });

  DispatchRule copyWith({
    String? id,
    String? title,
    DispatchRuleType? type,
    bool? active,
    List<String>? recipients,
    Map<String, dynamic>? config,
    String? templateId,
    DateTime? createdAt,
  }) {
    return DispatchRule(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      active: active ?? this.active,
      recipients: recipients ?? this.recipients,
      config: config ?? this.config,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum DispatchTargetScope {
  all('all', 'Geral'),
  eventType('event_type', 'Tipos de Evento'),
  event('event', 'Eventos específicos'),
  ministry('ministry', 'Ministérios'),
  communionGroup('communion_group', 'Grupos de comunhão'),
  studyGroup('study_group', 'Grupos de estudo'),
  course('course', 'Cursos');

  final String value;
  final String label;
  const DispatchTargetScope(this.value, this.label);

  static DispatchTargetScope fromValue(String value) {
    return DispatchTargetScope.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DispatchTargetScope.all,
    );
  }
}

enum DispatchRecipientMode {
  birthday('birthday', 'Aniversariante'),
  single('single', 'Destinatário único'),
  group('group', 'Enviar para número do grupo'),
  multi('multi', 'Lista manual de números');

  final String value;
  final String label;
  const DispatchRecipientMode(this.value, this.label);

  static DispatchRecipientMode fromValue(String value) {
    return DispatchRecipientMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DispatchRecipientMode.multi,
    );
  }
}
 

class DispatchConfigScreen extends ConsumerStatefulWidget {
  const DispatchConfigScreen({super.key});

  @override
  ConsumerState<DispatchConfigScreen> createState() => _DispatchConfigScreenState();
}

class _DispatchConfigScreenState extends ConsumerState<DispatchConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração de Disparos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Central para configurar e gerenciar disparos automáticos via WhatsApp (Uazapi).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Tile(
                  icon: Icons.rule,
                  title: 'Regras de Disparo',
                  subtitle: 'Criar, editar e ativar regras (aniversários, eventos, PDFs).',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const _DispatchRulesSheet(),
                    );
                  },
                ),
                _Tile(
                  icon: Icons.monitor_heart,
                  title: 'Monitoramento',
                  subtitle: 'Fila, entregas, respostas e erros da Uazapi.',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const _MonitoringSheet(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Escopos planejados', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Eventos, Escalas, Aniversários, Grupos de comunhão/estudo, Materiais de apoio, Agenda, Testemunhos, Pedidos de oração, Devocionais, Financeiro, Cursos, Notícias e Planos de leitura.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatchRulesSheet extends ConsumerStatefulWidget {
  const _DispatchRulesSheet();

  @override
  ConsumerState<_DispatchRulesSheet> createState() => _DispatchRulesSheetState();
}

class _DispatchRulesSheetState extends ConsumerState<_DispatchRulesSheet> {
  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(allDispatchRulesProvider);
    final actions = ref.read(dispatchActionsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Regras de Disparo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova Regra',
              onPressed: () async {
                final created = await showDialog<DispatchRule?>(
                  context: context,
                  builder: (context) => _EditRuleDialog(),
                );
                if (created != null) {
                  await actions.createRule(created);
                }
              },
            ),
          ],
        ),
        body: rulesAsync.when(
          data: (rules) => ListView.builder(
            controller: controller,
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final r = rules[index];
              return ListTile(
                leading: Icon(_iconForType(r.type)),
                title: Text(r.title),
                subtitle: Text(_subtitleForRule(r)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.schedule_send),
                      tooltip: 'Gerar Jobs',
                      onPressed: () async {
                        try {
                          final scheduler = ref.read(dispatchSchedulerActionsProvider);
                          final n = await scheduler.scheduleForRule(r);
                          if (!context.mounted) return;
                          if (n > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gerado(s) $n job(s)')),
                            );
                          } else {
                            final reasons = await scheduler.diagnose(r);
                            if (!context.mounted) return;
                            if (reasons.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gerado(s) 0 job(s)')),
                              );
                            } else {
                              await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Diagnóstico (0 jobs)'),
                                  content: SizedBox(
                                    width: 400,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: reasons.map((e) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text('• $e'),
                                      )).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')),
                                  ],
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          final scheduler = ref.read(dispatchSchedulerActionsProvider);
                          final reasons = await scheduler.diagnose(r);
                          if (!context.mounted) return;
                          final scope = (r.config['target_scope'] ?? 'all').toString();
                          final msg = _formatError(e);
                          await showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Falha ao gerar jobs'),
                              content: SizedBox(
                                width: 480,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Erro: $msg'),
                                    const SizedBox(height: 12),
                                    Text('Escopo: $scope'),
                                    if (reasons.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text('Diagnóstico:'),
                                      const SizedBox(height: 8),
                                      ...reasons.map((e) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text('• $e'),
                                      )),
                                    ],
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.alarm),
                      tooltip: 'Agendar envio diário',
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (context) => _EditAutoScheduleDialog(rule: r),
                        );
                      },
                    ),
                    Switch(
                      value: r.active,
                      onChanged: (v) => actions.toggleActive(r.id, v),
                    ),
                  ],
                ),
                onTap: () async {
                  final updated = await showDialog<DispatchRule?>(
                    context: context,
                    builder: (context) => _EditRuleDialog(initial: r),
                  );
                  if (updated != null) {
                    await actions.updateRule(r.id, updated);
                  }
                },
                onLongPress: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remover regra'),
                      content: const Text('Deseja remover esta regra?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await actions.deleteRule(r.id);
                  }
                },
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar regras: $e')),
        ),
      ),
    );
  }

  IconData _iconForType(DispatchRuleType type) {
    switch (type) {
      case DispatchRuleType.birthday:
        return Icons.cake;
      case DispatchRuleType.event:
        return Icons.event;
      case DispatchRuleType.schedule:
        return Icons.calendar_month;
      case DispatchRuleType.pdf:
        return Icons.picture_as_pdf;
    }
  }

  String _subtitleForRule(DispatchRule r) {
    final base = r.type.label;
    final cfg = r.config;
    final scopeStr = (cfg['target_scope'] ?? 'all').toString();
    final scope = DispatchTargetScope.fromValue(scopeStr);
    if (scope == DispatchTargetScope.eventType) {
      final types = List<String>.from(cfg['event_types'] ?? const []);
      final count = types.length;
      if (count == 0) return base;
      return '$base · Tipos de evento: $count';
    }
    if (scope == DispatchTargetScope.all) {
      return base;
    }
    final ids = List<String>.from(cfg['target_ids'] ?? const []);
    final count = ids.length;
    return '$base · ${scope.label}: $count selecionado(s)';
  }
}

 

class _EditAutoScheduleDialog extends ConsumerStatefulWidget {
  final DispatchRule rule;
  const _EditAutoScheduleDialog({required this.rule});

  @override
  ConsumerState<_EditAutoScheduleDialog> createState() => _EditAutoScheduleDialogState();
}

class _EditAutoScheduleDialogState extends ConsumerState<_EditAutoScheduleDialog> {
  final _timeController = TextEditingController(text: '08:00');
  String _timezone = 'America/Sao_Paulo';
  bool _active = true;

  @override
  void initState() {
    super.initState();
    ref.read(autoSchedulerRepositoryProvider).getByRuleId(widget.rule.id).then((cfg) {
      if (!mounted || cfg == null) return;
      setState(() {
        _timeController.text = cfg.sendTime;
        _timezone = cfg.timezone;
        _active = cfg.active;
      });
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: Text('Agendamento: ${widget.rule.title}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Horário (HH:mm)',
                border: OutlineInputBorder(),
                helperText: 'Ex.: 08:00',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              items: const [
                DropdownMenuItem(value: 'America/Sao_Paulo', child: Text('America/Sao_Paulo')),
                DropdownMenuItem(value: 'America/Bahia', child: Text('America/Bahia')),
                DropdownMenuItem(value: 'America/Manaus', child: Text('America/Manaus')),
              ],
              onChanged: (v) => setState(() => _timezone = v ?? 'America/Sao_Paulo'),
              decoration: const InputDecoration(
                labelText: 'Timezone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Ativo'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final sendTime = _timeController.text.trim();
            if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(sendTime)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Horário inválido. Use HH:mm.')),
              );
              return;
            }
            await ref.read(autoSchedulerActionsProvider).upsertForRule(
                  rule: widget.rule,
                  active: _active,
                  sendTime: sendTime,
                  timezone: _timezone,
                );
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _EditRuleDialog extends ConsumerStatefulWidget {
  final DispatchRule? initial;
  const _EditRuleDialog({this.initial});

  @override
  ConsumerState<_EditRuleDialog> createState() => _EditRuleDialogState();
}

class _EditRuleDialogState extends ConsumerState<_EditRuleDialog> {
  final _titleController = TextEditingController();
  DispatchRuleType _type = DispatchRuleType.event;
  final _recipientsController = TextEditingController();
  bool _active = true;
  String? _templateId;
  final _templateNameController = TextEditingController();
  final _templateContentController = TextEditingController();
  bool _templateActive = true;
  String _templatePreview = '';
  DispatchTargetScope _scope = DispatchTargetScope.all;
  DispatchRecipientMode _recipientMode = DispatchRecipientMode.multi;
  bool _notifyLeader = false;
  final _singlePhoneController = TextEditingController();
  final _groupPhoneController = TextEditingController();
  final Map<String, String> _selectedEntities = {};
  final List<String> _selectedEventTypes = [];
  Future<List<String>>? _eventTypesFuture;
  final _singleQueryController = TextEditingController();
  String _singleQuery = '';
  Map<String, String> _singleSelected = {};
  final _multiQueryController = TextEditingController();
  String _multiQuery = '';
  final Map<String, ({String name, String? phone})> _multiSelected = {};
  String? _selectedMinistryId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _type = initial.type;
      _recipientsController.text = initial.recipients.join(', ');
      _active = initial.active;
      _templateId = initial.templateId;
      final cfg = initial.config;
      final scopeStr = (cfg['target_scope'] ?? 'all').toString();
      _scope = DispatchTargetScope.fromValue(scopeStr);
      final ids = List<String>.from(cfg['target_ids'] ?? const []);
      final names = Map<String, String>.from(cfg['target_names'] ?? const {});
      _selectedEntities
        ..clear()
        ..addAll(names.isNotEmpty ? names : {for (final id in ids) id: id});
      final evTypes = List<String>.from(cfg['event_types'] ?? const []);
      _selectedEventTypes
        ..clear()
        ..addAll(evTypes);
      final rmStr = (cfg['recipient_mode'] ?? 'multi').toString();
      _recipientMode = DispatchRecipientMode.fromValue(rmStr);
      _singlePhoneController.text = (cfg['single_phone'] ?? '').toString();
      _groupPhoneController.text = (cfg['group_phone'] ?? '').toString();
      _selectedMinistryId = (cfg['group_ministry_id'] ?? '').toString().isEmpty
          ? null
          : (cfg['group_ministry_id'] ?? '').toString();
      final nl = cfg['notify_leader'];
      _notifyLeader = nl is bool ? nl : (nl is String ? nl.toLowerCase() == 'true' : false);
      if ((_type == DispatchRuleType.birthday) && _recipientMode == DispatchRecipientMode.multi) {
        _recipientMode = DispatchRecipientMode.birthday;
      }

      final recipientIds = List<String>.from(cfg['recipient_ids'] ?? const []);
      final recipientNames = Map<String, String>.from(cfg['recipient_names'] ?? const {});
      final recipientPhones = Map<String, String>.from(cfg['recipient_phones'] ?? const {});
      if (_recipientMode == DispatchRecipientMode.single && recipientIds.isNotEmpty) {
        final id = recipientIds.first;
        final name = recipientNames[id] ?? id;
        _singleSelected = {id: name};
        if ((cfg['single_phone'] ?? '').toString().isNotEmpty) {
          _singlePhoneController.text = (cfg['single_phone'] ?? '').toString();
        }
      }
      if (_recipientMode == DispatchRecipientMode.multi && recipientIds.isNotEmpty) {
        _multiSelected
          ..clear()
          ..addAll({
            for (final id in recipientIds)
              id: (name: recipientNames[id] ?? id, phone: recipientPhones[id]),
          });
      }
    }
    _singleQueryController.text = _singleQuery;
    _multiQueryController.text = _multiQuery;
    _eventTypesFuture = _loadEventTypes();
    final tid = _templateId;
    if (tid != null && tid.isNotEmpty) {
      ref.read(messageTemplateRepositoryProvider).getById(tid).then((t) {
        if (!mounted || t == null) return;
        setState(() {
          _templateNameController.text = t.name;
          _templateContentController.text = t.content;
          _templateActive = t.isActive;
        });
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _recipientsController.dispose();
    _singlePhoneController.dispose();
    _groupPhoneController.dispose();
    _templateNameController.dispose();
    _templateContentController.dispose();
    _singleQueryController.dispose();
    _multiQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: Text(widget.initial == null ? 'Nova Regra' : 'Editar Regra'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DispatchRuleType>(
              initialValue: _type,
              items: [
                for (final t in DispatchRuleType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? DispatchRuleType.event),
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DispatchTargetScope>(
              initialValue: _scope,
              items: [
                for (final s in DispatchTargetScope.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _scope = v ?? DispatchTargetScope.all),
              decoration: const InputDecoration(
                labelText: 'Escopo do alvo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _buildScopeSelector(context),
            const SizedBox(height: 12),
            DropdownButtonFormField<DispatchRecipientMode>(
              initialValue: _recipientMode,
              items: (() {
                final base = [
                  DispatchRecipientMode.single,
                  DispatchRecipientMode.group,
                  DispatchRecipientMode.multi,
                ];
                final list = _type == DispatchRuleType.birthday
                    ? [DispatchRecipientMode.birthday, ...base]
                    : base;
                return [
                  for (final m in list) DropdownMenuItem(value: m, child: Text(m.label)),
                ];
              })(),
              onChanged: (v) => setState(() => _recipientMode = v ?? DispatchRecipientMode.multi),
              decoration: const InputDecoration(
                labelText: 'Modo de destinatário',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_type == DispatchRuleType.birthday)
              SwitchListTile(
                value: _notifyLeader,
                onChanged: (v) => setState(() => _notifyLeader = v),
                title: const Text('Enviar também para líder/mentor'),
                subtitle: const Text('Se habilitado, o líder/mentor recebe a mesma mensagem.'),
              ),
            const SizedBox(height: 12),
            if (_recipientMode == DispatchRecipientMode.single)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _singleQueryController,
                    decoration: InputDecoration(
                      labelText: 'Buscar membro (mín. 3 letras)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _singleQuery.trim().isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _singleQueryController.clear();
                                  _singleQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _singleQuery = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  if (_singleSelected.isNotEmpty)
                    InputChip(
                      label: Text(_singleSelected.values.first),
                      onDeleted: () => setState(() {
                        _singleSelected.clear();
                        _singlePhoneController.clear();
                      }),
                    ),
                  if (_singleQuery.length >= 3)
                    _MemberSearchList(
                      query: _singleQuery,
                      onSelect: (id, name, phone) {
                        setState(() {
                          _singleSelected = {id: name};
                          _singlePhoneController.text = (phone ?? '').trim();
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _singlePhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Número do destinatário',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            if (_recipientMode == DispatchRecipientMode.group)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMinistryId,
                    items: ref.watch(activeMinistriesProvider).maybeWhen(
                      data: (list) => [
                        for (final m in list)
                          DropdownMenuItem(value: m.id, child: Text(m.name)),
                      ],
                      orElse: () => const [],
                    ),
                    onChanged: (v) {
                      setState(() => _selectedMinistryId = v);
                      if (v != null) {
                        final mins = ref.read(activeMinistriesProvider).maybeWhen(data: (l) => l, orElse: () => const []);
                        for (final m in mins) {
                          if (m.id == v) {
                            _groupPhoneController.text = (m.whatsappGroupNumber ?? '').trim();
                            break;
                          }
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Ministério',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _groupPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Número do grupo (Uazapi)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            if (_recipientMode == DispatchRecipientMode.multi) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _multiQueryController,
                decoration: InputDecoration(
                  labelText: 'Buscar membros (mín. 3 letras)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _multiQuery.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _multiQueryController.clear();
                              _multiQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _multiQuery = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (_multiSelected.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _multiSelected.entries)
                      InputChip(
                        label: Text(entry.value.name),
                        onDeleted: () => setState(() => _multiSelected.remove(entry.key)),
                      ),
                  ],
                ),
              if (_multiQuery.length >= 3)
                _MemberSearchList(
                  query: _multiQuery,
                  onSelect: (id, name, phone) {
                    setState(() {
                      _multiSelected[id] = (name: name, phone: phone?.trim());
                    });
                  },
                ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Template', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _templateNameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Template',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _templateContentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Conteúdo (use {variáveis})',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _templateActive,
              title: const Text('Template ativo'),
              onChanged: (v) => setState(() => _templateActive = v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Variáveis disponíveis', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in _availableVars())
                  SizedBox(
                    height: 36,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            label: Text('{$v}'),
                            onPressed: () {
                              final t = _templateContentController.text;
                              final sep = t.isEmpty || t.endsWith(' ') ? '' : ' ';
                              setState(() {
                                _templateContentController.text = '$t$sep{$v}';
                              });
                            },
                          ),
                        ),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Tooltip(
                            message: _variableDescription(v),
                            waitDuration: const Duration(milliseconds: 250),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final desc = _variableDescription(v);
                                showDialog<void>(
                                  context: context,
                                  builder: (context) => Dialog(
                                    insetPadding: const EdgeInsets.all(24),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SizedBox(
                                        width: 320,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.info_outline),
                                                const SizedBox(width: 8),
                                                Text('{$v}', style: Theme.of(context).textTheme.titleSmall),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(Icons.info_outline, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pré-visualização', style: Theme.of(context).textTheme.titleSmall),
                TextButton(
                  onPressed: () async {
                    final engine = ref.read(templateEngineProvider);
                    final out = await engine.render(_templateContentController.text, RenderContext(targetType: null, targetId: null, payload: {}));
                    if (mounted) setState(() => _templatePreview = out);
                  },
                  child: const Text('Gerar preview'),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _templatePreview.isEmpty ? 'Sem preview gerado' : _templatePreview,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _active,
              title: const Text('Ativa'),
              onChanged: (v) => setState(() => _active = v),
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () async { await _save(); }, child: const Text('Salvar')),
      ],
    );
  }

  Future<List<String>> _loadEventTypes() async {
    final repo = ref.read(eventsRepositoryProvider);
    try {
      return await repo.getDistinctEventTypes();
    } catch (_) {
      return const <String>[];
    }
  }

  String _variableDescription(String v) {
    const d = {
      'member_full_name': 'Nome completo do destinatário.',
      'member_nickname': 'Apelido do destinatário.',
      'member_phone': 'Telefone do destinatário.',
      'birthday_date': 'Dia e mês do aniversário no formato dd/MM.',
      'church_name': 'Nome da igreja.',
      'church_address': 'Endereço da igreja.',
      'event_name': 'Nome do evento.',
      'event_date': 'Data do evento no formato dd/MM/yyyy.',
      'event_time': 'Hora do evento no formato HH:mm.',
      'event_location_address': 'Endereço/local do evento.',
      'event_link': 'Primeiro link de material de apoio vinculado ao evento.',
      'schedule_link': 'Link do PDF da escala do evento.',
      'ministry_name': 'Nome do ministério relacionado.',
      'payment_date': 'Data de pagamento em dd/MM/yyyy.',
      'due_date': 'Data de vencimento em dd/MM/yyyy.',
    };
    return d[v] ?? 'Variável {$v}.';
  }

  List<String> _availableVars() {
    final registry = ref.read(variableRegistryProvider);
    final all = registry.resolvers.keys.toList();
    final byType = {
      DispatchRuleType.birthday: [
        'member_full_name',
        'member_nickname',
        'birthday_date',
        'member_phone',
        'church_name',
        'church_address',
      ],
      DispatchRuleType.event: [
        'event_name',
        'event_date',
        'event_time',
        'event_location_address',
        'event_link',
        'ministry_name',
        'member_full_name',
        'member_nickname',
        'church_name',
        'church_address',
      ],
      DispatchRuleType.schedule: [
        'schedule_link',
        'event_date',
        'event_time',
        'ministry_name',
        'member_full_name',
        'church_name',
        'church_address',
      ],
      DispatchRuleType.pdf: [
        'member_full_name',
        'church_name',
        'church_address',
        'due_date',
        'payment_date',
      ],
    };
    var allowed = List<String>.from(byType[_type] ?? all);
    switch (_scope) {
      case DispatchTargetScope.eventType:
      case DispatchTargetScope.event:
        allowed = allowed.where((v) {
          return v.startsWith('event_') ||
              [
                'member_full_name',
                'member_nickname',
                'member_phone',
                'church_name',
                'church_address',
                'event_date',
                'event_time',
                'event_name',
                'event_location_address',
                'event_link',
                'ministry_name',
              ].contains(v);
        }).toList();
        break;
      case DispatchTargetScope.ministry:
        allowed = [
          ...allowed.where((v) => v == 'ministry_name'),
          ...allowed.where((v) => [
                'member_full_name',
                'member_nickname',
                'member_phone',
                'church_name',
                'church_address',
              ].contains(v)),
        ];
        break;
      case DispatchTargetScope.communionGroup:
      case DispatchTargetScope.studyGroup:
      case DispatchTargetScope.course:
        allowed = allowed.where((v) {
          return [
            'member_full_name',
            'member_nickname',
            'member_phone',
            'church_name',
            'church_address',
          ].contains(v);
        }).toList();
        break;
      case DispatchTargetScope.all:
        break;
    }
    final unique = allowed.where((v) => all.contains(v)).toSet().toList()..sort();
    return unique;
  }

  Widget _buildScopeSelector(BuildContext context) {
    switch (_scope) {
      case DispatchTargetScope.eventType:
        return FutureBuilder<List<String>>(
          future: _eventTypesFuture,
          builder: (context, snapshot) {
            final types = snapshot.data ?? const <String>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
            }
            if (types.isEmpty) {
              return const Text('Nenhum tipo de evento encontrado');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in types)
                  FilterChip(
                    label: Text(t),
                    selected: _selectedEventTypes.contains(t),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selectedEventTypes.add(t);
                      } else {
                        _selectedEventTypes.remove(t);
                      }
                    }),
                  ),
              ],
            );
          },
        );
      case DispatchTargetScope.event:
        return _entitySelectButton(context, MaterialLinkType.event);
      case DispatchTargetScope.ministry:
        return _entitySelectButton(context, MaterialLinkType.ministry);
      case DispatchTargetScope.communionGroup:
        return _entitySelectButton(context, MaterialLinkType.communionGroup);
      case DispatchTargetScope.studyGroup:
        return _entitySelectButton(context, MaterialLinkType.studyGroup);
      case DispatchTargetScope.course:
        return _entitySelectButton(context, MaterialLinkType.course);
      case DispatchTargetScope.all:
        return const Text('Escopo geral: regra aplicada sem filtro de entidade');
    }
  }

  Widget _entitySelectButton(BuildContext context, MaterialLinkType linkType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            final res = await showDialog<Map<String, dynamic>?>(
              context: context,
              builder: (context) => EntitySelectorDialog(
                linkType: linkType,
                initialSelectedIds: _selectedEntities.keys.toList(),
              ),
            );
            if (res != null) {
              final ids = List<String>.from(res['ids'] ?? const []);
              final names = Map<String, String>.from(res['names'] ?? const {});
              setState(() {
                _selectedEntities
                  ..clear()
                  ..addAll(names.isNotEmpty ? names : {for (final id in ids) id: id});
              });
            }
          },
          icon: const Icon(Icons.playlist_add),
          label: Text('Selecionar ${linkType.label}'),
        ),
        const SizedBox(height: 8),
        if (_selectedEntities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _selectedEntities.entries)
                InputChip(
                  label: Text(entry.value),
                  onDeleted: () => setState(() => _selectedEntities.remove(entry.key)),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final recipients = _multiSelected.values
        .map((e) => (e.phone ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (title.isEmpty) return;
    final cfg = Map<String, dynamic>.from(widget.initial?.config ?? const {});
    cfg['target_scope'] = _scope.value;
    cfg['event_types'] = _selectedEventTypes;
    cfg['target_ids'] = _selectedEntities.keys.toList();
    cfg['target_names'] = _selectedEntities;
    cfg['recipient_mode'] = _recipientMode.value;
    cfg['single_phone'] = _singlePhoneController.text.trim();
    cfg['group_phone'] = _groupPhoneController.text.trim();
    cfg['manual_numbers'] = recipients;
    cfg['notify_leader'] = _notifyLeader;
    if (_selectedMinistryId != null) {
      cfg['group_ministry_id'] = _selectedMinistryId;
      final mins = ref.read(activeMinistriesProvider).maybeWhen(
        data: (l) => l,
        orElse: () => const [],
      );
      for (final m in mins) {
        if (m.id == _selectedMinistryId) {
          cfg['group_ministry_name'] = m.name;
          break;
        }
      }
    }

    if (_recipientMode == DispatchRecipientMode.single && _singleSelected.isNotEmpty) {
      cfg['recipient_ids'] = _singleSelected.keys.toList();
      cfg['recipient_names'] = _singleSelected;
    }
    if (_recipientMode == DispatchRecipientMode.multi && _multiSelected.isNotEmpty) {
      cfg['recipient_ids'] = _multiSelected.keys.toList();
      cfg['recipient_names'] = {
        for (final entry in _multiSelected.entries) entry.key: entry.value.name,
      };
      cfg['recipient_phones'] = {
        for (final entry in _multiSelected.entries)
          if ((entry.value.phone ?? '').trim().isNotEmpty) entry.key: entry.value.phone!.trim(),
      };
    }

    final tn = _templateNameController.text.trim();
    final tc = _templateContentController.text.trim();
    if (tn.isNotEmpty && tc.isNotEmpty) {
      final registry = ref.read(variableRegistryProvider);
      final known = registry.resolvers.keys.toSet();
      final regex = RegExp(r'\{([a-zA-Z0-9_]+)(\|[^}]*)?\}');
      final matches = regex.allMatches(tc).toList();
      final vars = <String>{};
      for (final m in matches) {
        final name = m.group(1);
        if (name != null && known.contains(name)) vars.add(name);
      }
      final repo = ref.read(messageTemplateRepositoryProvider);
      final created = await repo.create(name: tn, content: tc, variables: vars.toList(), isActive: _templateActive);
      _templateId = created.id;
    }

    final rule = DispatchRule(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      type: _type,
      active: _active,
      recipients: recipients,
      config: cfg,
      templateId: _templateId,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );

    if (!mounted) return;
    Navigator.pop(context, rule);
  }
}

class _MemberSearchList extends ConsumerWidget {
  final String query;
  final void Function(String id, String name, String? phone) onSelect;
  const _MemberSearchList({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchMembersProvider(query));
    return resultsAsync.when(
      data: (members) {
        final filtered = members.where((m) {
          final dn = (m.nickname ?? m.fullName ?? '${m.firstName ?? ''} ${m.lastName ?? ''}').toLowerCase();
          return dn.contains(query);
        }).toList()
          ..sort((a, b) => (a.nickname ?? a.fullName ?? '${a.firstName ?? ''} ${a.lastName ?? ''}').compareTo(b.nickname ?? b.fullName ?? '${b.firstName ?? ''} ${b.lastName ?? ''}'));
        if (filtered.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 160,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];
              final name = (m.nickname ?? m.fullName ?? '${m.firstName ?? ''} ${m.lastName ?? ''}').trim();
              final phone = m.phone;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(name.isEmpty ? m.email : name),
                subtitle: Text((phone ?? '').isEmpty ? 'Sem telefone cadastrado' : phone!),
                onTap: () => onSelect(m.id, name.isEmpty ? m.email : name, phone),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _TemplatesSheet extends ConsumerStatefulWidget {
  const _TemplatesSheet();

  @override
  ConsumerState<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<_TemplatesSheet> {
  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(allMessageTemplatesProvider);
    final actions = ref.read(messageTemplateActionsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Templates de Mensagem'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Novo Template',
              onPressed: () async {
                final created = await showDialog<_EditTemplateResult?>(
                  context: context,
                  builder: (context) => const _EditTemplateDialog(),
                );
                if (created != null) {
                  await actions.create(created.name, created.content, isActive: created.isActive);
                }
              },
            ),
          ],
        ),
        body: templatesAsync.when(
          data: (list) => ListView.builder(
            controller: controller,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final t = list[index];
              final varsLabel = t.variables.isEmpty ? '' : ' · {${t.variables.join(', ')}}';
              return ListTile(
                leading: const Icon(Icons.description),
                title: Text(t.name),
                subtitle: Text('Ativo: ${t.isActive ? 'Sim' : 'Não'}$varsLabel'),
                onTap: () async {
                  final updated = await showDialog<_EditTemplateResult?>(
                    context: context,
                    builder: (context) => _EditTemplateDialog(
                      initialName: t.name,
                      initialContent: t.content,
                      initialActive: t.isActive,
                    ),
                  );
                  if (updated != null) {
                    await actions.update(t.id, name: updated.name, content: updated.content, isActive: updated.isActive);
                  }
                },
                onLongPress: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remover template'),
                      content: const Text('Deseja remover este template?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await actions.delete(t.id);
                  }
                },
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar templates: $e')),
        ),
      ),
    );
  }
}

class _EditTemplateResult {
  final String name;
  final String content;
  final bool isActive;
  const _EditTemplateResult(this.name, this.content, this.isActive);
}

class _EditTemplateDialog extends StatefulWidget {
  final String? initialName;
  final String? initialContent;
  final bool? initialActive;
  const _EditTemplateDialog({this.initialName, this.initialContent, this.initialActive});

  @override
  State<_EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<_EditTemplateDialog> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isActive = true;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _contentController.text = widget.initialContent ?? '';
    _isActive = widget.initialActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: Text(widget.initialName == null ? 'Novo Template' : 'Editar Template'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Conteúdo (use variáveis em {chaves})',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              title: const Text('Ativo'),
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final registry = ref.read(variableRegistryProvider);
              final engine = ref.read(templateEngineProvider);
              final vars = registry.resolvers.keys.toList()..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variáveis disponíveis', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in vars)
                        SizedBox(
                          height: 36,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Chip(label: Text('{$v}')),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Tooltip(
                                  message: _variableDescription(v),
                                  waitDuration: const Duration(milliseconds: 250),
                                  child: const Icon(Icons.info_outline, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pré-visualização', style: Theme.of(context).textTheme.titleSmall),
                      TextButton(
                        onPressed: () async {
                          final ctx = RenderContext(targetType: null, targetId: null, payload: {});
                          final out = await engine.render(_contentController.text, ctx);
                          if (mounted) setState(() => _preview = out);
                        },
                        child: const Text('Gerar preview'),
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _preview.isEmpty ? 'Sem preview gerado' : _preview,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();
    if (name.isEmpty || content.isEmpty) return;
    Navigator.pop(context, _EditTemplateResult(name, content, _isActive));
  }
}

String _variableDescription(String v) {
  const d = {
    'member_full_name': 'Nome completo do destinatário.',
    'member_nickname': 'Apelido do destinatário.',
    'member_phone': 'Telefone do destinatário.',
    'birthday_date': 'Dia e mês do aniversário no formato dd/MM.',
    'church_name': 'Nome da igreja.',
    'church_address': 'Endereço da igreja.',
    'event_name': 'Nome do evento.',
    'event_date': 'Data do evento no formato dd/MM/yyyy.',
    'event_time': 'Hora do evento no formato HH:mm.',
    'event_location_address': 'Endereço/local do evento.',
    'event_link': 'Primeiro link de material de apoio vinculado ao evento.',
    'schedule_link': 'Link do PDF da escala do evento.',
    'ministry_name': 'Nome do ministério relacionado.',
    'payment_date': 'Data de pagamento em dd/MM/yyyy.',
    'due_date': 'Data de vencimento em dd/MM/yyyy.',
  };
  return d[v] ?? 'Variável {$v}.';
}

 

class _MonitoringSheet extends ConsumerStatefulWidget {
  const _MonitoringSheet();

  @override
  ConsumerState<_MonitoringSheet> createState() => _MonitoringSheetState();
}

class _MonitoringSheetState extends ConsumerState<_MonitoringSheet> {
  DispatchStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(monitoringActionsProvider);
    final jobsAsync = ref.watch(dispatchJobsByStatusProvider(_filter));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Monitoramento de Disparos'),
        ),
        body: Column(
          children: [
            _StatusFilterBar(
              selected: _filter,
              onSelected: (s) => setState(() => _filter = s),
            ),
            const Divider(height: 1),
            Expanded(
              child: jobsAsync.when(
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return const Center(child: Text('Sem itens na fila'));
                  }
                  return ListView.builder(
                    controller: controller,
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final j = jobs[index];
                      return ListTile(
                        leading: Icon(_iconForStatus(j.status)),
                        title: Text(j.recipientPhone ?? 'Destinatário indefinido'),
                        subtitle: Text(_subtitleForJob(j)),
                        trailing: Wrap(spacing: 8, children: [
                          if (j.status == DispatchStatus.failed || j.status == DispatchStatus.cancelled)
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Reprocessar',
                              onPressed: () async {
                                await actions.retry(j.id);
                                ref.invalidate(dispatchJobsByStatusProvider(_filter));
                              },
                            ),
                          if (j.status == DispatchStatus.pending || j.status == DispatchStatus.processing)
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              tooltip: 'Cancelar',
                              onPressed: () async {
                                await actions.cancel(j.id);
                                ref.invalidate(dispatchJobsByStatusProvider(_filter));
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.list),
                            tooltip: 'Logs',
                            onPressed: () async {
                              showDialog(
                                context: context,
                                builder: (context) => _JobLogsDialog(jobId: j.id),
                              );
                            },
                          ),
                        ]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro ao carregar fila: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForStatus(DispatchStatus s) {
    switch (s) {
      case DispatchStatus.pending:
        return Icons.schedule;
      case DispatchStatus.processing:
        return Icons.sync;
      case DispatchStatus.sent:
        return Icons.send;
      case DispatchStatus.delivered:
        return Icons.check_circle;
      case DispatchStatus.failed:
        return Icons.error;
      case DispatchStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _subtitleForJob(DispatchJob j) {
    final status = j.status.label;
    final ttype = j.targetType ?? '-';
    final retries = j.retries;
    final when = j.processedAt?.toIso8601String() ?? j.scheduledAt.toIso8601String();
    return '$status · $ttype · tentativas: $retries · $when';
  }
}

String _formatError(Object e) {
  try {
    final d = e as dynamic;
    final msg = d.message?.toString();
    final code = d.code?.toString();
    final details = d.details?.toString();
    final hint = d.hint?.toString();
    if ((msg ?? '').isNotEmpty || (code ?? '').isNotEmpty || (details ?? '').isNotEmpty || (hint ?? '').isNotEmpty) {
      final parts = <String>[];
      if ((msg ?? '').isNotEmpty) parts.add(msg!);
      if ((code ?? '').isNotEmpty) parts.add('code: $code');
      if ((details ?? '').isNotEmpty) parts.add('details: $details');
      if ((hint ?? '').isNotEmpty) parts.add('hint: $hint');
      return parts.join(' · ');
    }
  } catch (_) {}
  return e.toString();
}

class _StatusFilterBar extends StatelessWidget {
  final DispatchStatus? selected;
  final void Function(DispatchStatus?) onSelected;
  const _StatusFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Todos', 'value': null},
      ...DispatchStatus.values.map((s) => {'label': s.label, 'value': s}),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(it['label'] as String),
                selected: it['value'] == selected,
                onSelected: (_) => onSelected(it['value'] as DispatchStatus?),
              ),
            ),
        ],
      ),
    );
  }
}

class _JobLogsDialog extends ConsumerWidget {
  final String jobId;
  const _JobLogsDialog({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(jobLogsProvider(jobId));
    return AlertDialog(
      title: const Text('Logs do Disparo'),
      content: SizedBox(
        width: 680,
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) return const Text('Sem logs para este job');
            return ListView.separated(
              shrinkWrap: true,
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final l = logs[index];
                final statusLabel = l.status?.label ?? '-';
                return ListTile(
                  leading: const Icon(Icons.article),
                  title: Text('${l.action} · $statusLabel'),
                  subtitle: Text(l.detail ?? ''),
                  trailing: Text(l.createdAt.toIso8601String()),
                );
              },
            );
          },
          loading: () => const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro ao carregar logs: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
