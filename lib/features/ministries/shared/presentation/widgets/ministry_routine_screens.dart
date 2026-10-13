import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_routine.dart';
import '../providers/ministry_routine_providers.dart';
import 'ministry_requests_tab.dart';
import 'ministry_routine_tab.dart';

const _declaration =
    'Conferi todas as etapas acima descritas e atesto que as atribuições e '
    'rotinas operacionais deste culto foram cumpridas pela equipe escalada.';

Future<void> openRoutineRun(
  BuildContext context, {
  required String ministryId,
  required String runId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        MinistryRoutineRunScreen(ministryId: ministryId, runId: runId),
  ),
);

/// Escolhe alguém da Equipe (ou ninguém). Devolve `(escolheu, id)`.
/// [scheduled] (id -> função) sobe para o topo como "Escalados neste dia".
Future<(bool, String?)> _pickTeamMember(
  BuildContext context,
  List<MinistryMember> team,
  String title, {
  Map<String, String?> scheduled = const {},
}) async {
  final onDuty = [
    for (final m in team)
      if (scheduled.containsKey(m.memberId)) m,
  ];
  final rest = [
    for (final m in team)
      if (!scheduled.containsKey(m.memberId)) m,
  ];
  Widget tile(BuildContext ctx, MinistryMember m, String subtitle) => ListTile(
    leading: const Icon(AppIcons.person),
    title: Text(m.memberName),
    subtitle: Text(subtitle),
    onTap: () => Navigator.of(ctx).pop((true, m.memberId)),
  );

  final r = await showModalBottomSheet<(bool, String?)>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, style: CommunityDesign.titleStyle(ctx)),
            ),
            ListTile(
              leading: const Icon(AppIcons.personOff),
              title: const Text('Ninguém'),
              onTap: () => Navigator.of(ctx).pop((true, null)),
            ),
            if (onDuty.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Escalados neste dia',
                  style: CommunityDesign.metaStyle(ctx),
                ),
              ),
              for (final m in onDuty)
                tile(ctx, m, scheduled[m.memberId] ?? 'Escalado'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Equipe', style: CommunityDesign.metaStyle(ctx)),
              ),
            ],
            for (final m in rest) tile(ctx, m, m.role.label),
          ],
        ),
      ),
    ),
  );
  return r ?? (false, null);
}

/// A rotina de um culto: três etapas, líder do dia, necessidades e a
/// confirmação com a frase da Ficha 3.
class MinistryRoutineRunScreen extends ConsumerStatefulWidget {
  final String ministryId;
  final String runId;

  const MinistryRoutineRunScreen({
    super.key,
    required this.ministryId,
    required this.runId,
  });

  @override
  ConsumerState<MinistryRoutineRunScreen> createState() =>
      _MinistryRoutineRunScreenState();
}

class _MinistryRoutineRunScreenState
    extends ConsumerState<MinistryRoutineRunScreen> {
  final _notes = TextEditingController();
  bool _notesLoaded = false;
  bool _busy = false;

  MinistryRoutineRepository get _repo =>
      ref.read(ministryRoutineRepositoryProvider);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } on MinistryRoutineException catch (e) {
      if (mounted) showRoutineError(context, e);
    } finally {
      invalidateMinistryRoutine(ref, widget.ministryId, runId: widget.runId);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCheck(
    RoutineCheck c, {
    bool? done,
    String? value,
    (bool, String?) responsible = (false, null),
  }) => _run(
    () => _repo.setCheck(
      checkId: c.id,
      done: done ?? c.done,
      valueText: value ?? c.valueText,
      responsibleUserId: responsible.$1 ? responsible.$2 : c.responsibleUserId,
    ),
  );

  Future<void> _editValue(RoutineCheck c) async {
    final ctrl = TextEditingController(text: c.valueText ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Anotação'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) await _setCheck(c, value: v);
  }

  Future<void> _confirm(RoutineRun run) async {
    if (run.leaderOfDay == null) {
      showRoutineError(context, 'Escolha o líder do dia antes de confirmar.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar rotina'),
        content: const Text('"$_declaration"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repo.confirm(run.id), done: 'Rotina confirmada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final runAsync = ref.watch(ministryRoutineRunProvider(widget.runId));
    final caps = ref
        .watch(ministryRoutineCapsProvider(widget.ministryId))
        .valueOrNull;
    final team =
        ref.watch(ministryMembersProvider(widget.ministryId)).valueOrNull ??
        const <MinistryMember>[];
    final names = {for (final m in team) m.memberId: m.memberName};
    final scheduled =
        ref.watch(ministryRoutineScheduledProvider(widget.runId)).valueOrNull ??
        const <String, String?>{};
    final onDutyNames = [
      for (final id in scheduled.keys)
        if (names[id] != null) names[id]!,
    ];
    final meta = CommunityDesign.metaStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          runAsync.valueOrNull == null
              ? 'Rotina'
              : 'Rotina · ${routineServiceLabel(runAsync.valueOrNull!)}',
        ),
      ),
      body: runAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
        data: (run) {
          if (!_notesLoaded) {
            _notes.text = run.needsNotes ?? '';
            _notesLoaded = true;
          }
          final editable = (caps?.canMark ?? false) && !run.confirmed && !_busy;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (run.confirmed)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.verified,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Confirmada em ${DateFormat("dd/MM 'às' HH:mm").format(run.confirmedAt!)}. '
                          'Para mudar, o líder reabre.',
                        ),
                      ),
                      if (caps?.canManage ?? false)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => _repo.reopen(run.id),
                                  done: 'Rotina reaberta.',
                                ),
                          child: const Text('Reabrir'),
                        ),
                    ],
                  ),
                ),
              Text(
                '${run.doneCount} de ${run.checks.length} itens feitos',
                style: meta,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.personFilled),
                title: const Text('Líder do dia'),
                subtitle: Text(
                  names[run.leaderOfDay] ??
                      (onDutyNames.isEmpty
                          ? 'Ninguém escolhido'
                          : 'Ninguém escolhido · escalados: '
                                '${onDutyNames.join(', ')}'),
                ),
                trailing: editable ? const Icon(AppIcons.edit) : null,
                onTap: editable
                    ? () async {
                        final (picked, id) = await _pickTeamMember(
                          context,
                          team,
                          'Líder do dia',
                          scheduled: scheduled,
                        );
                        if (picked) {
                          await _run(
                            () => _repo.setRun(
                              runId: run.id,
                              leaderOfDay: id,
                              needsNotes: _notes.text,
                            ),
                          );
                        }
                      }
                    : null,
              ),
              for (final stage in RoutineStage.values) ...[
                const SizedBox(height: 12),
                Text(
                  stage.label,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                for (final c in run.checks.where((c) => c.stage == stage))
                  _CheckRow(
                    check: c,
                    responsibleName: names[c.responsibleUserId],
                    editable: editable,
                    onToggle: (v) => _setCheck(c, done: v),
                    onValue: () => _editValue(c),
                    onResponsible: () async {
                      final r = await _pickTeamMember(
                        context,
                        team,
                        'Responsável',
                      );
                      if (r.$1) await _setCheck(c, responsible: r);
                    },
                  ),
              ],
              if (caps?.offeringOn ?? false) ...[
                const SizedBox(height: 16),
                _OfferingSection(
                  run: run,
                  team: team,
                  editable: editable && !(run.offering?.received ?? false),
                  onSave: (o) => _run(
                    () => _repo.setOffering(
                      runId: run.id,
                      envelopes: o.envelopes,
                      cashAmount: o.cashAmount,
                      deliveredBy1: o.deliveredBy1,
                      deliveredBy2: o.deliveredBy2,
                      receivedBy: o.receivedBy,
                      notes: o.notes,
                    ),
                    done: 'Entrega das ofertas salva.',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Necessidades e manutenção',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                enabled: editable,
                minLines: 2,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText:
                      'Material de limpeza, insumo ou equipamento que precisa '
                      'de reposição ou conserto',
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  // Pedido vale mesmo com a rotina confirmada.
                  if ((caps?.canMark ?? false) && (caps?.requestsOn ?? false))
                    TextButton.icon(
                      key: const ValueKey('routine-open-request'),
                      onPressed: () => showRequestFormSheet(
                        context,
                        ministryId: widget.ministryId,
                        worshipServiceId: run.worshipServiceId,
                        initialDetails: _notes.text.trim().isEmpty
                            ? null
                            : _notes.text.trim(),
                      ),
                      icon: const Icon(AppIcons.add, size: 18),
                      label: const Text('Abrir pedido'),
                    ),
                  if (editable)
                    TextButton(
                      onPressed: () => _run(
                        () => _repo.setRun(
                          runId: run.id,
                          leaderOfDay: run.leaderOfDay,
                          needsNotes: _notes.text,
                        ),
                        done: 'Necessidades salvas.',
                      ),
                      child: const Text('Salvar necessidades'),
                    ),
                ],
              ),
              if (editable) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('routine-confirm'),
                  onPressed: () => _confirm(run),
                  icon: const Icon(AppIcons.verified),
                  label: const Text('Confirmar rotina'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Só o líder do dia ou o líder do ministério confirma. '
                  'Depois de confirmada, a rotina fica travada.',
                  style: meta,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Entrega das ofertas à Tesouraria (F5): envelopes, espécie, os dois da
/// Equipe que entregaram e quem da Tesouraria recebeu. Quem recebeu confirma
/// no próprio celular (aviso no sino, tela /ofertas/:id); depois disso trava.
class _OfferingSection extends ConsumerWidget {
  final RoutineRun run;
  final List<MinistryMember> team;
  final bool editable;
  final Future<void> Function(OfferingDelivery) onSave;

  const _OfferingSection({
    required this.run,
    required this.team,
    required this.editable,
    required this.onSave,
  });

  Future<void> _edit(
    BuildContext context,
    Map<String, String> receivers,
  ) async {
    final o = run.offering;
    final env = TextEditingController(text: o?.envelopes?.toString() ?? '');
    final cash = TextEditingController(
      text: o?.cashAmount == null
          ? ''
          : o!.cashAmount!.toStringAsFixed(2).replaceAll('.', ','),
    );
    final notes = TextEditingController(text: o?.notes ?? '');
    var d1 = o?.deliveredBy1;
    var d2 = o?.deliveredBy2;
    var rec = o?.receivedBy;
    final teamNames = {for (final m in team) m.memberId: m.memberName};

    Widget people(
      String label,
      String? value,
      Map<String, String> options,
      ValueChanged<String?> onChanged,
    ) => DropdownButtonFormField<String?>(
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Ninguém')),
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: onChanged,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrega das ofertas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: env,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Envelopes recolhidos',
                ),
              ),
              TextField(
                controller: cash,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: r'Valor em espécie (R$)',
                  hintText: '0,00',
                ),
              ),
              people('Entregou (1)', d1, teamNames, (v) => d1 = v),
              people('Entregou (2)', d2, teamNames, (v) => d2 = v),
              people('Recebeu (Tesouraria)', rec, receivers, (v) => rec = v),
              TextField(
                controller: notes,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final result = OfferingDelivery(
      id: o?.id ?? '',
      envelopes: int.tryParse(env.text.trim()),
      cashAmount: parseReais(cash.text),
      deliveredBy1: d1,
      deliveredBy2: d2,
      receivedBy: rec,
      notes: notes.text,
    );
    env.dispose();
    cash.dispose();
    notes.dispose();
    if (ok == true) await onSave(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = run.offering;
    final receivers =
        ref.watch(offeringReceiversProvider).valueOrNull ??
        const <String, String>{};
    final names = {for (final m in team) m.memberId: m.memberName};
    final meta = CommunityDesign.metaStyle(context);
    final delivered = [
      for (final id in [o?.deliveredBy1, o?.deliveredBy2])
        if (id != null) names[id] ?? 'alguém da equipe',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Entrega das ofertas à Tesouraria',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (editable)
              TextButton(
                key: const ValueKey('routine-offering-edit'),
                onPressed: () => _edit(context, receivers),
                child: Text(o == null ? 'Preencher' : 'Editar'),
              ),
          ],
        ),
        if (o == null)
          Text('Ainda não preenchida.', style: meta)
        else ...[
          Text(
            '${o.envelopes ?? '—'} envelopes · ${formatReais(o.cashAmount)} '
            'em espécie',
          ),
          Text(
            'Entregou: ${delivered.isEmpty ? '—' : delivered.join(' e ')}',
            style: meta,
          ),
          Text(
            'Recebeu: ${o.receivedBy == null ? '—' : receivers[o.receivedBy] ?? 'Tesouraria'}',
            style: meta,
          ),
          if (o.notes != null) Text(o.notes!, style: meta),
          const SizedBox(height: 4),
          Text(
            o.received
                ? 'Recebimento confirmado em '
                      '${DateFormat("dd/MM 'às' HH:mm").format(o.receivedConfirmedAt!)}.'
                : (o.receivedBy == null
                      ? 'Escolha quem recebeu: a pessoa confirma pelo app.'
                      : 'Aguardando quem recebeu confirmar pelo app.'),
            style: meta.copyWith(
              color: o.received ? AppTheme.successColor : AppTheme.warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final RoutineCheck check;
  final String? responsibleName;
  final bool editable;
  final ValueChanged<bool> onToggle;
  final VoidCallback onValue;
  final VoidCallback onResponsible;

  const _CheckRow({
    required this.check,
    this.responsibleName,
    required this.editable,
    required this.onToggle,
    required this.onValue,
    required this.onResponsible,
  });

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: check.done,
            onChanged: editable ? (v) => onToggle(v ?? false) : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(check.title),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: editable ? onResponsible : null,
                      icon: const Icon(AppIcons.person, size: 16),
                      label: Text(
                        responsibleName ?? 'Responsável',
                        style: meta,
                      ),
                    ),
                    if (check.asksValue || check.valueText != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: editable ? onValue : null,
                        icon: const Icon(AppIcons.editNote, size: 16),
                        label: Text(check.valueText ?? 'Anotar', style: meta),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Configurar os itens da rotina (líder ou `ministries.edit`): por etapa,
/// acrescentar, editar, subir/descer e apagar. Apagar não mexe nas rotinas já
/// feitas: cada culto guarda a cópia do item.
class MinistryRoutineConfigScreen extends ConsumerWidget {
  final String ministryId;

  const MinistryRoutineConfigScreen({super.key, required this.ministryId});

  Future<void> _do(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(MinistryRoutineRepository) action,
  ) async {
    try {
      await action(ref.read(ministryRoutineRepositoryProvider));
    } on MinistryRoutineException catch (e) {
      if (context.mounted) showRoutineError(context, e);
    }
    invalidateMinistryRoutine(ref, ministryId);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    RoutineItem? item,
    required RoutineStage stage,
  }) async {
    final ctrl = TextEditingController(text: item?.title ?? '');
    var asks = item?.asksValue ?? false;
    var st = item?.stage ?? stage;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(item == null ? 'Novo item' : 'Editar item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(labelText: 'O que fazer'),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RoutineStage>(
                segments: [
                  for (final s in RoutineStage.values)
                    ButtonSegment(
                      value: s,
                      label: Text(s.label.split(' ').first),
                    ),
                ],
                selected: {st},
                onSelectionChanged: (v) => setState(() => st = v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: asks,
                onChanged: (v) => setState(() => asks = v),
                title: const Text('Pede anotação'),
                subtitle: const Text('Ex.: a contagem do culto'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    final title = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || title.isEmpty || !context.mounted) return;
    await _do(
      context,
      ref,
      (r) => r.saveItem(
        ministryId: ministryId,
        itemId: item?.id,
        stage: st,
        title: title,
        asksValue: asks,
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RoutineItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar item?'),
        content: Text(
          '"${item.title}" sai das próximas rotinas. As rotinas já feitas '
          'continuam com ele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _do(context, ref, (r) => r.deleteItem(item.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(ministryRoutineItemsProvider(ministryId));
    final meta = CommunityDesign.metaStyle(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Itens da rotina')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            OutlinedButton(
              key: const ValueKey('routine-config-template'),
              onPressed: () => _do(context, ref, (r) async {
                final n = await r.useTemplate(ministryId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        n == 0
                            ? 'Todos os itens do modelo já estão na rotina.'
                            : '$n itens do modelo foram acrescentados.',
                      ),
                    ),
                  );
                }
              }),
              child: const Text('Usar modelo do Diaconato'),
            ),
            const SizedBox(height: 4),
            Text(
              'Acrescenta os itens da Ficha de Checklist Diário que faltam. '
              'Depois é só apagar o que não serve.',
              style: meta,
            ),
            for (final stage in RoutineStage.values) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stage.label,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Novo item em ${stage.label}',
                    icon: const Icon(AppIcons.addCircle),
                    onPressed: () => _edit(context, ref, stage: stage),
                  ),
                ],
              ),
              ..._stageRows(context, ref, [
                for (final i in items)
                  if (i.stage == stage) i,
              ], stage),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _stageRows(
    BuildContext context,
    WidgetRef ref,
    List<RoutineItem> list,
    RoutineStage stage,
  ) {
    if (list.isEmpty) {
      return [
        Text(
          'Nenhum item nesta etapa.',
          style: CommunityDesign.metaStyle(context),
        ),
      ];
    }
    Future<void> move(int from, int to) {
      final ids = [for (final i in list) i.id];
      ids.insert(to, ids.removeAt(from));
      return _do(context, ref, (r) => r.reorder(ministryId, stage, ids));
    }

    return [
      for (final (idx, item) in list.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.title),
          subtitle: item.asksValue ? const Text('Pede anotação') : null,
          onTap: () => _edit(context, ref, item: item, stage: stage),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Subir',
                icon: const Icon(AppIcons.arrowUp, size: 18),
                onPressed: idx == 0 ? null : () => move(idx, idx - 1),
              ),
              IconButton(
                tooltip: 'Descer',
                icon: const Icon(AppIcons.arrowDown, size: 18),
                onPressed: idx == list.length - 1
                    ? null
                    : () => move(idx, idx + 1),
              ),
              IconButton(
                tooltip: 'Apagar',
                icon: const Icon(AppIcons.delete, size: 18),
                onPressed: () => _delete(context, ref, item),
              ),
            ],
          ),
        ),
    ];
  }
}
