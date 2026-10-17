import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/errors/app_error_handler.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// K6: "Exige ficha limpa", dentro da engrenagem. Aparece para quem tem
/// `ministries.edit` ou `members.background_check.view` (a mesma régua da
/// RPC `set_ministry_requires_clean_record`). Grava na hora.
class MinistryCleanRecordCard extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryCleanRecordCard({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryCleanRecordCard> createState() =>
      _MinistryCleanRecordCardState();
}

class _MinistryCleanRecordCardState
    extends ConsumerState<MinistryCleanRecordCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ministry = ref
        .watch(ministryByIdProvider(widget.ministryId))
        .valueOrNull;
    if (ministry == null) return const SizedBox.shrink();

    return MultiPermissionGate(
      permissions: const ['ministries.edit', 'members.background_check.view'],
      requireAll: false,
      showLoading: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Exige ficha limpa',
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
            ),
            subtitle: Text(
              'Ligado, só entra no ministério e na escala quem tem consulta de '
              'antecedentes "apto" dos últimos 6 meses. O resultado só é visto '
              'pelo pastor e por quem tem permissão.',
              style: CommunityDesign.metaStyle(context),
            ),
            value: ministry.requiresCleanRecord,
            onChanged: _busy ? null : _toggle,
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ministriesRepositoryProvider)
          .setRequiresCleanRecord(widget.ministryId, value);
      ref.invalidate(ministryByIdProvider(widget.ministryId));
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
