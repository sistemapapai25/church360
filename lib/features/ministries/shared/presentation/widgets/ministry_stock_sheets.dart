import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../domain/ministry_stock.dart';
import '../providers/ministry_stock_providers.dart';

/// Folhas do estoque do ministério (canvas telas 3 a 6): o item com o
/// histórico, os quatro movimentos, a correção e o cadastro.
///
/// Todas gravam por RPC e invalidam na mão (sem realtime). A decisão de
/// quem pode o quê é do banco; `canManage` só esconde o que a RPC recusaria.

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

/// Casca comum: alça, título, subtítulo e o conteúdo rolando por cima do
/// teclado.
class _SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;

  const _SheetFrame({
    required this.title,
    this.subtitle,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.dialogRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedForeground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: CommunityDesign.metaStyle(context)),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Selo em pílula (categoria, "Estoque baixo", "Em dia", área da auditoria).
class StockBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StockBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Color stockMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.darkMutedForeground
    : AppTheme.mutedForeground;

/// Quadro de números lado a lado (Mínimo/Categoria/Local,
/// Esperado/Contado/Diferença).
class _Kpis extends StatelessWidget {
  final List<(String, String, Color?)> cells;

  const _Kpis(this.cells);

  @override
  Widget build(BuildContext context) {
    final muted = stockMuted(context);
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (cells[i].$3 ?? muted).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cells[i].$1,
                    style: TextStyle(fontSize: 11.5, color: cells[i].$3 ?? muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cells[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cells[i].$3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------------------------------------------------------------------------
// Item e histórico (tela 3)
// ---------------------------------------------------------------------------

Future<void> showStockItemSheet({
  required BuildContext context,
  required String ministryId,
  required String itemId,
  required bool canManage,
}) {
  return _showSheet<void>(
    context,
    _StockItemSheet(
      ministryId: ministryId,
      itemId: itemId,
      canManage: canManage,
    ),
  );
}

class _StockItemSheet extends ConsumerWidget {
  final String ministryId;
  final String itemId;
  final bool canManage;

  const _StockItemSheet({
    required this.ministryId,
    required this.itemId,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ministryStockItemsProvider(ministryId));
    final item = items.valueOrNull
        ?.where((i) => i.id == itemId)
        .firstOrNull;

    if (item == null) {
      return _SheetFrame(
        title: 'Item',
        children: [
          if (items.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              'Este item não existe mais ou você não tem acesso a ele.',
              style: CommunityDesign.metaStyle(context),
            ),
        ],
      );
    }

    final muted = stockMuted(context);
    final low = item.isLow;
    final history = ref.watch(ministryStockHistoryProvider(itemId));
    final myId = ref.read(ministryStockRepositoryProvider).currentUserId;
    final active = !item.archived;

    Future<void> move(StockMoveKind kind) =>
        showStockMoveSheet(context: context, item: item, kind: kind);

    return _SheetFrame(
      title: item.name,
      subtitle: item.archived ? 'Arquivado' : null,
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Ações do item',
              icon: const Icon(AppIcons.more),
              onSelected: (v) async {
                if (v == 'editar') {
                  await showStockItemFormSheet(
                    context: context,
                    ministryId: ministryId,
                    item: item,
                  );
                } else {
                  await _archive(context, ref, item);
                }
              },
              itemBuilder: (_) => [
                if (active)
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                  value: 'arquivar',
                  child: Text(item.archived ? 'Desarquivar' : 'Arquivar'),
                ),
              ],
            )
          : null,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatStockQuantity(item.quantity),
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 40, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(item.unit, style: TextStyle(fontSize: 16, color: muted)),
                  const Spacer(),
                  if (item.minQuantity != null)
                    StockBadge(
                      label: low ? 'Estoque baixo' : 'Em dia',
                      color: low ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Kpis([
                (
                  'Mínimo',
                  item.minQuantity == null
                      ? '—'
                      : formatStockQuantity(item.minQuantity!),
                  null,
                ),
                ('Categoria', item.category ?? '—', null),
                ('Local', item.location ?? '—', null),
              ]),
              if (item.notes != null) ...[
                const SizedBox(height: 10),
                Text(item.notes!, style: CommunityDesign.metaStyle(context)),
              ],
              if (active) ...[
                const SizedBox(height: 12),
                if (canManage) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => move(StockMoveKind.saida),
                          child: const Text('− Saída'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => move(StockMoveKind.entrada),
                          child: const Text('+ Entrada'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => move(StockMoveKind.conferencia),
                          child: const Text('Conferir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => move(StockMoveKind.ajuste),
                          child: const Text('Ajuste'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  OutlinedButton(
                    onPressed: () => move(StockMoveKind.saida),
                    child: const Text('− Registrar saída'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'MOVIMENTAÇÕES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: CommunityDesign.metaStyle(context)),
          data: (moves) {
            if (moves.isEmpty) {
              return Text(
                'Nenhuma movimentação ainda.',
                style: CommunityDesign.metaStyle(context),
              );
            }
            final byId = {for (final m in moves) m.id: m};
            return GlassCard(
              child: Column(
                children: [
                  for (var i = 0; i < moves.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _MovementRow(
                      movement: moves[i],
                      unit: item.unit,
                      reversed: byId[moves[i].reversesId],
                      onRevert:
                          active &&
                              moves[i].kind != StockMoveKind.correcao &&
                              !moves[i].reverted &&
                              (canManage || moves[i].createdBy == myId)
                          ? () => _revert(context, ref, item, moves[i])
                          : null,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    StockItem item,
  ) async {
    try {
      await ref
          .read(ministryStockRepositoryProvider)
          .archiveItem(item.id, !item.archived);
      invalidateMinistryStock(ref, ministryId, itemId: item.id);
      if (context.mounted) {
        _snack(
          context,
          item.archived ? 'Item desarquivado.' : 'Item arquivado.',
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }

  Future<void> _revert(
    BuildContext context,
    WidgetRef ref,
    StockItem item,
    StockMovement m,
  ) async {
    final motivo = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corrigir movimento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vai entrar um movimento inverso de '
              '${formatStockDelta(-m.delta)} ${item.unit}. '
              'O original continua no histórico, riscado.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivo,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final t = motivo.text.trim();
              if (t.isNotEmpty) Navigator.of(dialogContext).pop(t);
            },
            child: const Text('Corrigir'),
          ),
        ],
      ),
    );
    motivo.dispose();
    if (note == null) return;

    try {
      await ref
          .read(ministryStockRepositoryProvider)
          .revert(movementId: m.id, note: note);
      invalidateMinistryStock(ref, ministryId, itemId: item.id);
      if (context.mounted) _snack(context, 'Movimento corrigido.');
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }
}

class _MovementRow extends StatelessWidget {
  final StockMovement movement;
  final String unit;

  /// O movimento que esta correção desfaz, se estiver no histórico.
  final StockMovement? reversed;
  final VoidCallback? onRevert;

  const _MovementRow({
    required this.movement,
    required this.unit,
    this.reversed,
    this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final muted = stockMuted(context);
    final when = DateFormat('dd/MM, HH:mm');
    final color = m.kind == StockMoveKind.conferencia || m.delta == 0
        ? muted
        : (m.delta > 0 ? AppTheme.successColor : AppTheme.errorColor);

    final title = switch (m.kind) {
      StockMoveKind.conferencia =>
        'Conferência · esperado ${formatStockQuantity(m.expected)}, '
            'contado ${formatStockQuantity(m.quantityAfter)}',
      _ => [m.kind.label, if (m.note != null) m.note!].join(' · '),
    };
    final meta = [
      when.format(m.createdAt),
      m.who ?? 'alguém',
      if (m.kind == StockMoveKind.conferencia && m.note != null) m.note!,
      if (reversed != null)
        'desfaz a ${reversed!.kind.label.toLowerCase()} de '
            '${when.format(reversed!.createdAt)}',
      if (m.reverted) 'corrigida',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              formatStockDelta(m.delta),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                decoration: m.reverted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
          if (onRevert != null)
            TextButton(onPressed: onRevert, child: const Text('Corrigir')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Movimentos (telas 5 e 6)
// ---------------------------------------------------------------------------

Future<void> showStockMoveSheet({
  required BuildContext context,
  required StockItem item,
  required StockMoveKind kind,
}) {
  return _showSheet<void>(context, _StockMoveSheet(item: item, kind: kind));
}

class _StockMoveSheet extends ConsumerStatefulWidget {
  final StockItem item;
  final StockMoveKind kind;

  const _StockMoveSheet({required this.item, required this.kind});

  @override
  ConsumerState<_StockMoveSheet> createState() => _StockMoveSheetState();
}

class _StockMoveSheetState extends ConsumerState<_StockMoveSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _serverError;

  StockItem get item => widget.item;
  bool get _isAjuste => widget.kind == StockMoveKind.ajuste;
  bool get _isConferencia => widget.kind == StockMoveKind.conferencia;

  @override
  void initState() {
    super.initState();
    if (_isConferencia) _qty.text = formatStockQuantity(item.quantity);
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _value => parseStockQuantity(_qty.text);

  /// Erro mostrado embaixo do campo, antes de ir ao banco. O banco confere
  /// de novo (CHECK e RPC); aqui é só para o botão não prometer.
  String? get _localError {
    final v = _value;
    if (_qty.text.trim().isEmpty) return null;
    if (v == null) return 'Número inválido.';
    if (item.unit == 'un' && v != v.truncateToDouble()) {
      return 'Item em unidades aceita só número inteiro.';
    }
    if (_isAjuste) {
      if (v == 0) return 'O ajuste precisa ser diferente de zero.';
      if (item.quantity + v < 0) {
        return 'Estoque disponível: ${formatStockQuantity(item.quantity)} '
            '${item.unit}.';
      }
      return null;
    }
    if (_isConferencia) {
      return v < 0 ? 'A quantidade contada não pode ser negativa.' : null;
    }
    if (v <= 0) return 'A quantidade precisa ser maior que zero.';
    if (widget.kind == StockMoveKind.saida && v > item.quantity) {
      return 'Estoque disponível: ${formatStockQuantity(item.quantity)} '
          '${item.unit}. Ajuste a quantidade.';
    }
    return null;
  }

  bool get _canSubmit =>
      !_saving &&
      _value != null &&
      _localError == null &&
      (!_isAjuste || _note.text.trim().isNotEmpty);

  void _step(int dir) {
    final v = (_value ?? 0) + dir;
    final floor = _isAjuste ? double.negativeInfinity : 0.0;
    setState(() {
      _qty.text = formatStockQuantity(v < floor ? floor : v);
      _serverError = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final note = _note.text.trim();
      await ref
          .read(ministryStockRepositoryProvider)
          .move(
            itemId: item.id,
            kind: widget.kind,
            quantity: _value!,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      invalidateMinistryStock(ref, item.ministryId, itemId: item.id);
      Navigator.of(context).pop();
      _snack(context, '${widget.kind.label} registrada.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      StockMoveKind.saida => 'Registrar saída',
      StockMoveKind.entrada => 'Registrar entrada',
      StockMoveKind.ajuste => 'Ajuste de estoque',
      _ => 'Conferir estoque',
    };
    final subtitle = _isConferencia
        ? 'Conte o que existe de verdade e informe aqui.'
        : '${item.name} · disponível: '
              '${formatStockQuantity(item.quantity)} ${item.unit}';
    final label = switch (widget.kind) {
      StockMoveKind.ajuste => 'Quanto somar ou tirar (use − para tirar)',
      StockMoveKind.conferencia => 'Quantidade contada',
      _ => 'Quantidade',
    };
    final error = _localError ?? _serverError;
    final v = _value;

    return _SheetFrame(
      title: title,
      subtitle: subtitle,
      children: [
        Text(label, style: CommunityDesign.metaStyle(context)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Menos',
              onPressed: () => _step(-1),
              icon: const Icon(AppIcons.remove),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _qty,
                autofocus: !_isConferencia,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: _isAjuste,
                ),
                decoration: InputDecoration(suffixText: item.unit),
                onChanged: (_) => setState(() => _serverError = null),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Mais',
              onPressed: () => _step(1),
              icon: const Icon(AppIcons.add),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12.5),
          ),
        ],
        if (_isConferencia && v != null && v >= 0) ...[
          const SizedBox(height: 12),
          _Kpis([
            ('Esperado', formatStockQuantity(item.quantity), null),
            ('Contado', formatStockQuantity(v), null),
            (
              'Diferença',
              formatStockDelta(v - item.quantity),
              v == item.quantity
                  ? null
                  : (v < item.quantity
                        ? AppTheme.errorColor
                        : AppTheme.successColor),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: switch (widget.kind) {
              StockMoveKind.ajuste => 'Observação *',
              StockMoveKind.conferencia => 'Observação (opcional)',
              _ => 'Motivo (opcional)',
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: Text(
                  _isConferencia && v != null
                      ? 'Confirmar ${formatStockQuantity(v)} ${item.unit}'
                      : 'Registrar',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Novo / editar item (tela 4)
// ---------------------------------------------------------------------------

Future<void> showStockItemFormSheet({
  required BuildContext context,
  required String ministryId,
  StockItem? item,
}) {
  return _showSheet<void>(
    context,
    _StockItemForm(ministryId: ministryId, item: item),
  );
}

class _StockItemForm extends ConsumerStatefulWidget {
  final String ministryId;
  final StockItem? item;

  const _StockItemForm({required this.ministryId, this.item});

  @override
  ConsumerState<_StockItemForm> createState() => _StockItemFormState();
}

class _StockItemFormState extends ConsumerState<_StockItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _category = TextEditingController(text: widget.item?.category);
  late final _qty = TextEditingController();
  late final _min = TextEditingController(
    text: widget.item?.minQuantity == null
        ? ''
        : formatStockQuantity(widget.item!.minQuantity!),
  );
  late final _location = TextEditingController(text: widget.item?.location);
  late final _notes = TextEditingController(text: widget.item?.notes);
  late String _unit = widget.item?.unit ?? 'un';
  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void dispose() {
    for (final c in [_name, _category, _qty, _min, _location, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _qtyValidator(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    final v = parseStockQuantity(t);
    if (v == null) return 'Número inválido';
    if (v < 0) return 'Não pode ser negativo';
    if (_unit == 'un' && v != v.truncateToDouble()) return 'Só número inteiro';
    return null;
  }

  String? _trimOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(ministryStockRepositoryProvider)
          .saveItem(
            ministryId: widget.ministryId,
            itemId: widget.item?.id,
            name: _name.text.trim(),
            unit: _unit,
            category: _trimOrNull(_category),
            location: _trimOrNull(_location),
            notes: _trimOrNull(_notes),
            minQuantity: parseStockQuantity(_min.text),
            initialQuantity: parseStockQuantity(_qty.text) ?? 0,
          );
      if (!mounted) return;
      invalidateMinistryStock(
        ref,
        widget.ministryId,
        itemId: widget.item?.id,
      );
      Navigator.of(context).pop();
      _snack(context, _editing ? 'Item atualizado.' : 'Item cadastrado.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(ministryStockItemsProvider(widget.ministryId)).valueOrNull ??
        const [];
    final categories =
        {
          for (final i in items)
            if (i.category != null) i.category!,
        }.toList()..sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );

    return _SheetFrame(
      title: _editing ? 'Editar item' : 'Novo item',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: !_editing,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  counterText: '',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                onChanged: (_) => setState(() {}),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category.text.trim() == c,
                        onSelected: (_) =>
                            setState(() => _category.text = c),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sugestões vêm das categorias já usadas no ministério.',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
              const SizedBox(height: 14),
              Text('Unidade', style: CommunityDesign.metaStyle(context)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final u in kStockUnits)
                    ChoiceChip(
                      label: Text(u),
                      selected: _unit == u,
                      onSelected: (_) => setState(() => _unit = u),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_editing) ...[
                    Expanded(
                      child: TextFormField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantidade inicial',
                          hintText: '0',
                        ),
                        validator: (v) => _qtyValidator(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: TextFormField(
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Mínimo (opcional)',
                      ),
                      validator: (v) => _qtyValidator(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _editing
                    ? 'A quantidade não muda aqui: use entrada, saída, ajuste '
                          'ou conferência. Ao chegar no mínimo, os líderes '
                          'recebem aviso no app e no WhatsApp.'
                    : 'Ao chegar no mínimo, os líderes recebem aviso no app '
                          'e no WhatsApp.',
                style: CommunityDesign.metaStyle(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Local (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Salvar item'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
