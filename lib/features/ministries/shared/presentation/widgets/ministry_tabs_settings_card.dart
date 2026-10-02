import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../domain/ministry_type_catalog.dart';
import '../providers/ministry_type_catalog_providers.dart';

/// "Abas do ministério", dentro da engrenagem.
///
/// Dois eixos, como na tela Mais:
/// - **quais abas aparecem**: escolha do líder do ministério (ou de quem tem
///   `ministries.edit`), vale para todo mundo — RPC `set_ministry_tab`;
/// - **em que ordem**: escolha de cada pessoa, vale só para ela —
///   `user_ministry_tab_order`.
///
/// Quem não configura vê só as abas ligadas, para ordenar.
/// Grava a cada mudança, sem botão de salvar.
class MinistryTabsSettingsCard extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryTabsSettingsCard({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryTabsSettingsCard> createState() =>
      _MinistryTabsSettingsCardState();
}

class _MinistryTabsSettingsCardState
    extends ConsumerState<MinistryTabsSettingsCard> {
  /// Edição em curso. `null` = espelhando os providers.
  List<(MinistryTypeTab, bool)>? _local;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ministry = ref
        .watch(ministryByIdProvider(widget.ministryId))
        .valueOrNull;
    final order = ref.watch(myMinistryTabOrderProvider(widget.ministryId));
    final canConfigure =
        ref
            .watch(canConfigureMinistryTabsProvider(widget.ministryId))
            .valueOrNull ??
        false;

    if (ministry == null || order.isLoading) {
      return const GlassCard(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      );
    }

    final all =
        _local ??
        resolveMinistryTabs(
          available: ref
              .watch(ministryTypeCatalogSyncProvider)
              .availableTabsFor(ministry.ministryTypeCode),
          overrides: ministry.tabSettings,
          order: order.valueOrNull ?? const [],
        );
    final shown = canConfigure
        ? all
        : [
            for (final e in all)
              if (e.$2) e,
          ];
    final enabledCount = all.where((e) => e.$2).length;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Abas do ministério',
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            canConfigure
                ? 'Ligue as abas que este ministério usa — vale para todos. '
                      'Arraste para mudar a ordem; a ordem vale só para você.'
                : 'Arraste para mudar a ordem das abas. Vale só para você. '
                      'Quem escolhe as abas é o líder do ministério.',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (from, to) => _reorder(all, shown, from, to),
            children: [
              for (final (i, (tab, on)) in shown.indexed)
                ListTile(
                  key: ValueKey(tab.key),
                  contentPadding: EdgeInsets.zero,
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(AppIcons.dragHandle),
                  ),
                  title: Text(tab.label),
                  trailing: canConfigure
                      ? Switch(
                          value: on,
                          // A última aba ligada não desliga: o ministério
                          // ficaria sem tela nenhuma.
                          onChanged: _busy || (on && enabledCount == 1)
                              ? null
                              : (v) => _toggle(all, tab.key, v),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reorder(
    List<(MinistryTypeTab, bool)> all,
    List<(MinistryTypeTab, bool)> shown,
    int from,
    int to,
  ) async {
    if (to > from) to -= 1;
    final moved = [...shown];
    moved.insert(to, moved.removeAt(from));
    // As desligadas que a pessoa não vê ficam no fim, na ordem de antes.
    final keys = {for (final e in moved) e.$1.key};
    final next = [
      ...moved,
      for (final e in all)
        if (!keys.contains(e.$1.key)) e,
    ];
    await _save(
      next,
      () => ref.read(ministriesRepositoryProvider).saveMyTabOrder(
        widget.ministryId,
        [for (final e in next) e.$1.key],
      ),
      myMinistryTabOrderProvider(widget.ministryId),
    );
  }

  Future<void> _toggle(
    List<(MinistryTypeTab, bool)> all,
    String key,
    bool enabled,
  ) async {
    final next = [for (final e in all) e.$1.key == key ? (e.$1, enabled) : e];
    await _save(
      next,
      () => ref
          .read(ministriesRepositoryProvider)
          .setMinistryTab(widget.ministryId, key, enabled),
      ministryByIdProvider(widget.ministryId),
    );
  }

  Future<void> _save(
    List<(MinistryTypeTab, bool)> next,
    Future<void> Function() write,
    ProviderOrFamily toInvalidate,
  ) async {
    final previous = _local;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _local = next;
      _busy = true;
    });
    try {
      await write();
      ref.invalidate(toInvalidate);
    } catch (e) {
      if (mounted) setState(() => _local = previous);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
