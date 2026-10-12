import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_routine.dart';
import '../providers/ministry_routine_providers.dart';
import '../providers/ministry_stock_providers.dart';
import 'ministry_routine_tab.dart';

const _kOpen = 'abertos';
const _kDone = 'fechados';
const _kAll = 'todos';

/// Aba Pedidos: manutenção e reposição do ministério (F4). Quem é da Equipe
/// abre; só o líder (ou `ministries.edit`) muda a situação. Pedido de
/// reposição pode apontar um item do Estoque, mas não mexe no saldo.
class MinistryRequestsTab extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryRequestsTab({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryRequestsTab> createState() =>
      _MinistryRequestsTabState();
}

class _MinistryRequestsTabState extends ConsumerState<MinistryRequestsTab> {
  String _filter = _kOpen;

  @override
  Widget build(BuildContext context) {
    final id = widget.ministryId;
    final caps = ref.watch(ministryRoutineCapsProvider(id));
    final async = ref.watch(ministryRequestsProvider(id));
    final team = {
      for (final m
          in ref.watch(ministryMembersProvider(id)).valueOrNull ?? const [])
        m.memberId: m.memberName,
    };
    final meta = CommunityDesign.metaStyle(context);

    final error = caps.error ?? async.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Não deu para carregar os pedidos', style: meta),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              TextButton(
                onPressed: () {
                  ref.invalidate(ministryRoutineCapsProvider(id));
                  ref.invalidate(ministryRequestsProvider(id));
                },
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    final c = caps.valueOrNull;
    final all = async.valueOrNull;
    if (c == null || all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!c.canView) {
      return Center(
        child: Text('Só a equipe do ministério vê os pedidos.', style: meta),
      );
    }

    final openCount = all.where((r) => r.status.isOpen).length;
    final visible = [
      for (final r in all)
        if (_filter == _kAll || (_filter == _kOpen) == r.status.isOpen) r,
    ];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(ministryRequestsProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final (key, label) in [
                    (_kOpen, 'Abertos ($openCount)'),
                    (_kDone, 'Fechados'),
                    (_kAll, 'Todos'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == key,
                      onSelected: (_) => setState(() => _filter = key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    _filter == _kOpen
                        ? 'Nenhum pedido aberto.'
                        : 'Nenhum pedido aqui.',
                    textAlign: TextAlign.center,
                    style: meta,
                  ),
                ),
              for (final r in visible)
                _RequestCard(
                  request: r,
                  openedByName: team[r.openedBy],
                  onTap: () => _showRequest(
                    context,
                    ref,
                    ministryId: id,
                    request: r,
                    canManage: c.canManage,
                    openedByName: team[r.openedBy],
                  ),
                ),
            ],
          ),
        ),
        if (c.canMark)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              key: const ValueKey('request-new'),
              heroTag: null,
              onPressed: () => showRequestFormSheet(context, ministryId: id),
              icon: const Icon(AppIcons.add),
              label: const Text('Novo pedido'),
            ),
          ),
      ],
    );
  }
}

Color _statusColor(RequestStatus s) => switch (s) {
  RequestStatus.aberto => AppTheme.warningColor,
  RequestStatus.andamento => AppTheme.primary,
  RequestStatus.resolvido => AppTheme.successColor,
  RequestStatus.cancelado => AppTheme.mutedForeground,
};

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  final MinistryRequest request;
  final String? openedByName;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    this.openedByName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.title,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Badge(r.status.label, _statusColor(r.status)),
                _Badge(r.kind.label, AppTheme.secondary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (r.location != null) r.location!,
                DateFormat('dd/MM').format(r.openedAt),
                if (openedByName != null) openedByName!,
              ].join(' · '),
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRequest(
  BuildContext context,
  WidgetRef ref, {
  required String ministryId,
  required MinistryRequest request,
  required bool canManage,
  String? openedByName,
}) async {
  final r = request;
  final meta = CommunityDesign.metaStyle(context);
  final next = await showModalBottomSheet<RequestStatus>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.title, style: CommunityDesign.titleStyle(ctx)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _Badge(r.status.label, _statusColor(r.status)),
                _Badge(r.kind.label, AppTheme.secondary),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in [
              if (r.location != null) 'Onde: ${r.location}',
              if (r.stockItemName != null)
                'Item do estoque: ${r.stockItemName}',
              if (r.serviceDate != null)
                'Culto de ${DateFormat('dd/MM/yyyy').format(r.serviceDate!)}',
              'Aberto em ${DateFormat("dd/MM 'às' HH:mm").format(r.openedAt)}'
                  '${openedByName != null ? ' por $openedByName' : ''}',
              if (r.statusNote != null) 'Observação do líder: ${r.statusNote}',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: meta),
              ),
            if (r.details != null) ...[
              const SizedBox(height: 8),
              Text(r.details!),
            ],
            if (canManage) ...[
              const SizedBox(height: 16),
              Text('Mudar situação', style: meta),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in RequestStatus.values)
                    if (s != r.status)
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(s),
                        child: Text(s.label),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (next == null || !context.mounted) return;

  String? note;
  if (next == RequestStatus.resolvido || next == RequestStatus.cancelado) {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(next.label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
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
    note = ctrl.text;
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
  }

  try {
    await ref
        .read(ministryRoutineRepositoryProvider)
        .setRequestStatus(r.id, next, note: note);
  } on MinistryRoutineException catch (e) {
    if (context.mounted) showRoutineError(context, e);
  }
  ref.invalidate(ministryRequestsProvider(ministryId));
}

/// Formulário de pedido novo. Da Rotina, vem com o culto e o texto das
/// necessidades.
Future<void> showRequestFormSheet(
  BuildContext context, {
  required String ministryId,
  String? worshipServiceId,
  String? initialDetails,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RequestForm(
    ministryId: ministryId,
    worshipServiceId: worshipServiceId,
    initialDetails: initialDetails,
  ),
);

class _RequestForm extends ConsumerStatefulWidget {
  final String ministryId;
  final String? worshipServiceId;
  final String? initialDetails;

  const _RequestForm({
    required this.ministryId,
    this.worshipServiceId,
    this.initialDetails,
  });

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  late final _details = TextEditingController(text: widget.initialDetails);
  RequestKind _kind = RequestKind.conserto;
  String? _stockItemId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showRoutineError(context, 'Diga o que precisa.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ministryRoutineRepositoryProvider)
          .openRequest(
            ministryId: widget.ministryId,
            title: _title.text.trim(),
            kind: _kind,
            location: _location.text,
            details: _details.text,
            worshipServiceId: widget.worshipServiceId,
            stockItemId: _kind == RequestKind.reposicao ? _stockItemId : null,
          );
      ref.invalidate(ministryRequestsProvider(widget.ministryId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido aberto. O líder foi avisado.')),
      );
    } on MinistryRoutineException catch (e) {
      if (mounted) showRoutineError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = _kind == RequestKind.reposicao
        ? (ref
                  .watch(ministryStockItemsProvider(widget.ministryId))
                  .valueOrNull
                  ?.where((i) => !i.archived)
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
            Text('Novo pedido', style: CommunityDesign.titleStyle(context)),
            if (widget.worshipServiceId != null)
              Text(
                'Ligado ao culto desta rotina.',
                style: CommunityDesign.metaStyle(context),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'O que precisa',
                hintText: 'Ex.: bebedouro pingando',
              ),
            ),
            SegmentedButton<RequestKind>(
              segments: [
                for (final k in RequestKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            if (stock.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButton<String?>(
                isExpanded: true,
                value: _stockItemId,
                hint: const Text('Item do estoque (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhum')),
                  for (final i in stock)
                    DropdownMenuItem(value: i.id, child: Text(i.name)),
                ],
                onChanged: (v) => setState(() => _stockItemId = v),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Onde (opcional)',
                hintText: 'Ex.: cozinha, banheiro feminino',
              ),
            ),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('request-save'),
              onPressed: _busy ? null : _save,
              child: const Text('Abrir pedido'),
            ),
          ],
        ),
      ),
    );
  }
}
