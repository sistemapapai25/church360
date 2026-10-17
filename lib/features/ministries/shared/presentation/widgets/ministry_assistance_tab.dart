import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/layout/readable_width.dart';
import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../members/domain/models/member_directory_entry.dart';
import '../../../../members/presentation/providers/members_provider.dart';
import '../../data/ministry_assistance_repository.dart';
import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_assistance.dart';
import '../providers/ministry_stock_providers.dart';
import 'ministry_routine_tab.dart';

final ministryAssistanceRepositoryProvider =
    Provider<MinistryAssistanceRepository>(
      (ref) => MinistryAssistanceRepository(Supabase.instance.client),
    );

final ministryAssistCapsProvider = FutureProvider.family<(bool, bool), String>(
  (ref, ministryId) =>
      ref.watch(ministryAssistanceRepositoryProvider).caps(ministryId),
);

final assistedFamiliesProvider =
    FutureProvider.family<List<AssistedFamily>, String>(
      (ref, ministryId) => ref
          .watch(ministryAssistanceRepositoryProvider)
          .getFamilies(ministryId),
    );

final familyAssistancesProvider =
    FutureProvider.family<List<Assistance>, String>(
      (ref, familyId) => ref
          .watch(ministryAssistanceRepositoryProvider)
          .getAssistances(familyId),
    );

/// Aba Assistência (ação social, F6). Dado sensível: só quem recebeu
/// `ministry_assist.view` (vê) ou `ministry_assist.manage` (cadastra e
/// registra atendimento). Ser líder do ministério não basta. Cada gravação
/// vai para o registro LGPD.
class MinistryAssistanceTab extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryAssistanceTab({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryAssistanceTab> createState() =>
      _MinistryAssistanceTabState();
}

class _MinistryAssistanceTabState extends ConsumerState<MinistryAssistanceTab> {
  bool _onlyActive = true;

  @override
  Widget build(BuildContext context) {
    final id = widget.ministryId;
    final caps = ref.watch(ministryAssistCapsProvider(id));
    final meta = CommunityDesign.metaStyle(context);

    return caps.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
      data: (c) {
        final (canView, canManage) = c;
        if (!canView) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'A Assistência guarda dados sensíveis das famílias. Só vê '
                'quem recebeu a permissão "Ver famílias assistidas" ou '
                '"Gerenciar famílias assistidas".',
                textAlign: TextAlign.center,
                style: meta,
              ),
            ),
          );
        }
        final async = ref.watch(assistedFamiliesProvider(id));
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => ref.refresh(assistedFamiliesProvider(id).future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('$e', textAlign: TextAlign.center)),
                data: (all) {
                  final list = [
                    for (final f in all)
                      if (!_onlyActive || f.status == FamilyStatus.ativa) f,
                  ];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: Text(
                              'Ativas (${all.where((f) => f.status == FamilyStatus.ativa).length})',
                            ),
                            selected: _onlyActive,
                            onSelected: (_) =>
                                setState(() => _onlyActive = true),
                          ),
                          ChoiceChip(
                            label: Text('Todas (${all.length})'),
                            selected: !_onlyActive,
                            onSelected: (_) =>
                                setState(() => _onlyActive = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Nenhuma família aqui.',
                            textAlign: TextAlign.center,
                            style: meta,
                          ),
                        ),
                      for (final f in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _FamilyScreen(
                                  ministryId: id,
                                  familyId: f.id,
                                  canManage: canManage,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  style: CommunityDesign.titleStyle(context)
                                      .copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    f.status.label,
                                    if (f.householdSize != null)
                                      '${f.householdSize} na casa',
                                    if (f.need != null) f.need!,
                                  ].join(' · '),
                                  style: meta,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (canManage)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  key: const ValueKey('assist-new-family'),
                  heroTag: null,
                  onPressed: () => _editFamily(context, ref, ministryId: id),
                  icon: const Icon(AppIcons.add),
                  label: const Text('Nova família'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cadastrar ou editar a família.
Future<void> _editFamily(
  BuildContext context,
  WidgetRef ref, {
  required String ministryId,
  AssistedFamily? family,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _FamilyForm(ministryId: ministryId, family: family),
);

class _FamilyForm extends ConsumerStatefulWidget {
  final String ministryId;
  final AssistedFamily? family;

  const _FamilyForm({required this.ministryId, this.family});

  @override
  ConsumerState<_FamilyForm> createState() => _FamilyFormState();
}

class _FamilyFormState extends ConsumerState<_FamilyForm> {
  late final _name = TextEditingController(text: widget.family?.name);
  late final _phone = TextEditingController(text: widget.family?.phone);
  late final _address = TextEditingController(text: widget.family?.address);
  late final _size = TextEditingController(
    text: widget.family?.householdSize?.toString(),
  );
  late final _need = TextEditingController(text: widget.family?.need);
  late final _notes = TextEditingController(text: widget.family?.notes);
  late String? _memberId = widget.family?.memberId;
  late FamilyStatus _status = widget.family?.status ?? FamilyStatus.ativa;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _size, _need, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showRoutineError(context, 'Informe o nome.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ministryAssistanceRepositoryProvider)
          .saveFamily(
            ministryId: widget.ministryId,
            familyId: widget.family?.id,
            memberId: _memberId,
            name: _name.text.trim(),
            phone: _phone.text,
            address: _address.text,
            householdSize: int.tryParse(_size.text.trim()),
            need: _need.text,
            status: _status,
            notes: _notes.text,
          );
      ref.invalidate(assistedFamiliesProvider(widget.ministryId));
      if (mounted) Navigator.of(context).pop();
    } on MinistryRoutineException catch (e) {
      if (mounted) showRoutineError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory =
        ref.watch(memberDirectoryProvider).valueOrNull ?? const [];
    String nameOf(MemberDirectoryEntry e) =>
        (e.nickname?.trim().isNotEmpty ?? false)
        ? e.nickname!
        : e.fullName ?? '';
    final linked = [
      for (final e in directory)
        if (e.id == _memberId) nameOf(e),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.family == null ? 'Nova família' : 'Editar família',
              style: CommunityDesign.titleStyle(context),
            ),
            const SizedBox(height: 12),
            if (_memberId != null)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Membro'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(linked.isEmpty ? 'Membro' : linked.first),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _memberId = null),
                      child: const Text('Desvincular'),
                    ),
                  ],
                ),
              )
            else
              Autocomplete<MemberDirectoryEntry>(
                displayStringForOption: nameOf,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.length < 3) return const [];
                  return directory
                      .where((e) => nameOf(e).toLowerCase().contains(q))
                      .take(8);
                },
                onSelected: (e) => setState(() {
                  _memberId = e.id;
                  if (_name.text.trim().isEmpty) _name.text = nameOf(e);
                }),
                fieldViewBuilder: (context, ctrl, focus, _) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'É membro da igreja? Digite o nome (opcional)',
                    hintText: 'Digite 3 letras do nome',
                    prefixIcon: Icon(AppIcons.search),
                  ),
                ),
              ),
            TextField(
              controller: _name,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome da família ou responsável *',
              ),
            ),
            TextField(
              controller: _phone,
              maxLength: 40,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            TextField(
              controller: _address,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            TextField(
              controller: _size,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pessoas na casa'),
            ),
            TextField(
              controller: _need,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Necessidade',
                hintText: 'Ex.: alimento, remédio, emprego',
              ),
            ),
            const SizedBox(height: 4),
            SegmentedButton<FamilyStatus>(
              segments: [
                for (final s in FamilyStatus.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_status},
              onSelectionChanged: (v) => setState(() => _status = v.first),
            ),
            TextField(
              controller: _notes,
              maxLength: 4000,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('assist-family-save'),
              onPressed: _busy ? null : _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A família: dados, atendimentos e (para quem gerencia) registrar, editar e
/// apagar.
class _FamilyScreen extends ConsumerWidget {
  final String ministryId;
  final String familyId;
  final bool canManage;

  const _FamilyScreen({
    required this.ministryId,
    required this.familyId,
    required this.canManage,
  });

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AssistedFamily f,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar família?'),
        content: Text(
          '"${f.name}" e os atendimentos saem do app. As saídas que já foram '
          'para o Estoque continuam lá.',
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
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(ministryAssistanceRepositoryProvider).deleteFamily(f.id);
      ref.invalidate(assistedFamiliesProvider(ministryId));
      if (context.mounted) Navigator.of(context).pop();
    } on MinistryRoutineException catch (e) {
      if (context.mounted) showRoutineError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(assistedFamiliesProvider(ministryId));
    final f = families.valueOrNull?.where((x) => x.id == familyId).firstOrNull;
    final assistances = ref.watch(familyAssistancesProvider(familyId));
    final meta = CommunityDesign.metaStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(f?.name ?? 'Família'),
        actions: [
          if (canManage && f != null) ...[
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(AppIcons.edit),
              onPressed: () =>
                  _editFamily(context, ref, ministryId: ministryId, family: f),
            ),
            IconButton(
              tooltip: 'Apagar',
              icon: const Icon(AppIcons.delete),
              onPressed: () => _delete(context, ref, f),
            ),
          ],
        ],
      ),
      floatingActionButton: canManage && f != null
          ? FloatingActionButton.extended(
              key: const ValueKey('assist-record'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    _AssistanceForm(ministryId: ministryId, familyId: f.id),
              ),
              icon: const Icon(AppIcons.add),
              label: const Text('Registrar atendimento'),
            )
          : null,
      body: ReadableWidth(child: f == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final line in [
                  'Situação: ${f.status.label}',
                  if (f.householdSize != null)
                    'Pessoas na casa: ${f.householdSize}',
                  if (f.phone != null) 'Telefone: ${f.phone}',
                  if (f.address != null) 'Endereço: ${f.address}',
                  if (f.memberId != null) 'Membro da igreja',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line, style: meta),
                  ),
                if (f.need != null) ...[
                  const SizedBox(height: 8),
                  Text('Necessidade: ${f.need}'),
                ],
                if (f.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(f.notes!),
                ],
                const SizedBox(height: 20),
                Text(
                  'Atendimentos',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...assistances.when(
                  loading: () => [
                    const Center(child: CircularProgressIndicator()),
                  ],
                  error: (e, _) => [Text('$e')],
                  data: (list) => list.isEmpty
                      ? [Text('Nenhum atendimento ainda.', style: meta)]
                      : [
                          for (final a in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                a.kind == AssistanceKind.cesta
                                    ? AppIcons.inbox
                                    : AppIcons.person,
                                color: AppTheme.primary,
                              ),
                              title: Text(
                                '${a.kind.label} · '
                                '${DateFormat('dd/MM/yyyy').format(a.happenedOn)}',
                              ),
                              subtitle: Text(
                                [
                                  if (a.stockItemName != null)
                                    '${a.stockItemName}'
                                        '${a.quantity == null ? '' : ' × ${a.quantity!.toStringAsFixed(a.quantity! % 1 == 0 ? 0 : 2)}'}',
                                  if (a.notes != null) a.notes!,
                                ].join(' · '),
                              ),
                            ),
                        ],
                ),
              ],
            )),
    );
  }
}

class _AssistanceForm extends ConsumerStatefulWidget {
  final String ministryId;
  final String familyId;

  const _AssistanceForm({required this.ministryId, required this.familyId});

  @override
  ConsumerState<_AssistanceForm> createState() => _AssistanceFormState();
}

class _AssistanceFormState extends ConsumerState<_AssistanceForm> {
  AssistanceKind _kind = AssistanceKind.cesta;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  final _qty = TextEditingController(text: '1');
  String? _stockItemId;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
    if (_stockItemId != null && (qty == null || qty <= 0)) {
      showRoutineError(context, 'Informe a quantidade que saiu do estoque.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ministryAssistanceRepositoryProvider)
          .record(
            familyId: widget.familyId,
            kind: _kind,
            happenedOn: _date,
            notes: _notes.text,
            stockItemId: _stockItemId,
            quantity: _stockItemId == null ? null : qty,
          );
      ref.invalidate(familyAssistancesProvider(widget.familyId));
      ref.invalidate(assistedFamiliesProvider(widget.ministryId));
      ref.invalidate(ministryStockItemsProvider(widget.ministryId));
      if (mounted) Navigator.of(context).pop();
    } on MinistryRoutineException catch (e) {
      if (mounted) showRoutineError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = _kind == AssistanceKind.cesta
        ? (ref
                  .watch(ministryStockItemsProvider(widget.ministryId))
                  .valueOrNull
                  ?.where((i) => i.archivedAt == null)
                  .toList() ??
              const [])
        : const [];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar atendimento',
              style: CommunityDesign.titleStyle(context),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AssistanceKind>(
              segments: [
                for (final k in AssistanceKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                if (_kind != AssistanceKind.cesta) _stockItemId = null;
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.calendar),
              title: Text(DateFormat('dd/MM/yyyy').format(_date)),
              subtitle: const Text('Data do atendimento'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            if (stock.isNotEmpty) ...[
              DropdownButton<String?>(
                isExpanded: true,
                value: _stockItemId,
                hint: const Text('Saiu do estoque? (opcional)'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Não dar baixa no estoque'),
                  ),
                  for (final i in stock)
                    DropdownMenuItem(
                      value: i.id,
                      child: Text(
                        '${i.name} (${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2)} ${i.unit})',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _stockItemId = v),
              ),
              if (_stockItemId != null)
                TextField(
                  controller: _qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
            ],
            TextField(
              controller: _notes,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Observação'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('assist-record-save'),
              onPressed: _busy ? null : _save,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
