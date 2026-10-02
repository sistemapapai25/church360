import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../domain/ministry_stock.dart';
import '../providers/ministry_stock_providers.dart';
import 'ministry_stock_sheets.dart';

const _kAll = '\u0000todos';
const _kLow = '\u0000baixo';
const _kArchived = '\u0000arquivados';

/// Lado Estoque da aba Financeiro (canvas telas 1 e 2).
///
/// Quem gerencia (líder, `ministry_stock.manage` + vínculo, ou
/// `ministries.edit`) vê entrada/saída e "Novo item"; o integrante vê a
/// lista e registra só saída (D3/D4).
class MinistryStockView extends ConsumerStatefulWidget {
  final String ministryId;
  final bool canManage;

  /// Item a abrir assim que a lista aparece (link da notificação).
  final String? openItemId;

  const MinistryStockView({
    super.key,
    required this.ministryId,
    required this.canManage,
    this.openItemId,
  });

  @override
  ConsumerState<MinistryStockView> createState() => _MinistryStockViewState();
}

class _MinistryStockViewState extends ConsumerState<MinistryStockView> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = _kAll;

  @override
  void initState() {
    super.initState();
    final id = widget.openItemId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(id);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String itemId) => showStockItemSheet(
    context: context,
    ministryId: widget.ministryId,
    itemId: itemId,
    canManage: widget.canManage,
  );

  bool _matches(StockItem i) {
    if (_filter == _kArchived) {
      if (!i.archived) return false;
    } else {
      if (i.archived) return false;
      if (_filter == _kLow && !i.isLow) return false;
      if (_filter != _kAll && _filter != _kLow && i.category != _filter) {
        return false;
      }
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      i.name,
      i.category ?? '',
      i.location ?? '',
    ].any((c) => c.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(ministryStockItemsProvider(widget.ministryId));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Não deu para carregar o estoque',
                style: CommunityDesign.titleStyle(context),
              ),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center),
              TextButton(
                onPressed: () =>
                    invalidateMinistryStock(ref, widget.ministryId),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        final active = items.where((i) => !i.archived).toList();
        final lowCount = active.where((i) => i.isLow).length;
        final categories =
            {
              for (final i in active)
                if (i.category != null) i.category!,
            }.toList()..sort(
              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
            );
        final hasArchived = widget.canManage && items.any((i) => i.archived);
        final visible = items.where(_matches).toList();

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                invalidateMinistryStock(ref, widget.ministryId);
                await ref.read(
                  ministryStockItemsProvider(widget.ministryId).future,
                );
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (lowCount > 0) ...[
                    _LowBanner(count: lowCount),
                    const SizedBox(height: 12),
                  ],
                  AppFilterBar(
                    searchController: _search,
                    searchHint: 'Buscar item...',
                    onSearchChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (key, label) in [
                          (_kAll, 'Todos'),
                          (_kLow, 'Baixo estoque'),
                          for (final c in categories) (c, c),
                          if (hasArchived) (_kArchived, 'Arquivados'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _filter == key,
                              onSelected: (_) => setState(() => _filter = key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    _Empty(
                      widget.canManage
                          ? 'Nenhum item no estoque ainda. Comece por '
                                '"Novo item".'
                          : 'Nenhum item no estoque ainda.',
                    )
                  else if (visible.isEmpty)
                    const _Empty('Nenhum item bate com esse filtro.'),
                  for (final i in visible)
                    _StockItemCard(
                      item: i,
                      canManage: widget.canManage,
                      onTap: () => _open(i.id),
                    ),
                ],
              ),
            ),
            if (widget.canManage)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => showStockItemFormSheet(
                    context: context,
                    ministryId: widget.ministryId,
                  ),
                  icon: const Icon(AppIcons.add),
                  label: const Text('Novo item'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LowBanner extends StatelessWidget {
  final int count;

  const _LowBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.warningAmber, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: count == 1 ? '1 item' : '$count itens',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: count == 1
                        ? ' precisa de reposição'
                        : ' precisam de reposição',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: CommunityDesign.metaStyle(context),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  final StockItem item;
  final bool canManage;
  final VoidCallback onTap;

  const _StockItemCard({
    required this.item,
    required this.canManage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = stockMuted(context);
    final low = item.isLow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.category != null)
                            StockBadge(
                              label: item.category!,
                              color: AppTheme.primary,
                            ),
                          if (low)
                            const StockBadge(
                              label: 'Estoque baixo',
                              color: AppTheme.errorColor,
                            ),
                          if (item.archived)
                            StockBadge(label: 'Arquivado', color: muted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatStockQuantity(item.quantity),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: low ? AppTheme.errorColor : null,
                            ),
                          ),
                          TextSpan(
                            text: ' ${item.unit}',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                    if (item.minQuantity != null)
                      Text(
                        'mínimo ${formatStockQuantity(item.minQuantity!)}',
                        style: CommunityDesign.metaStyle(context),
                      ),
                  ],
                ),
              ],
            ),
            if (!item.archived) ...[
              const SizedBox(height: 10),
              if (canManage)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showStockMoveSheet(
                          context: context,
                          item: item,
                          kind: StockMoveKind.saida,
                        ),
                        child: const Text('− Saída'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showStockMoveSheet(
                          context: context,
                          item: item,
                          kind: StockMoveKind.entrada,
                        ),
                        child: const Text('+ Entrada'),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton(
                  onPressed: () => showStockMoveSheet(
                    context: context,
                    item: item,
                    kind: StockMoveKind.saida,
                  ),
                  child: const Text('− Registrar saída'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
