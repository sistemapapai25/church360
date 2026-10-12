import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../diaconato/presentation/widgets/worship_service_picker_sheet.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_routine.dart';
import '../providers/ministry_routine_providers.dart';
import 'ministry_routine_screens.dart';

/// Aba Rotina: o checklist pré, durante e pós-culto (Ficha 3 do Diaconato),
/// que qualquer ministério pode ligar na engrenagem.
///
/// A Equipe abre a rotina de um culto e marca; o líder (ou `ministries.edit`)
/// configura os itens; o líder do dia (ou o líder) confirma. Embaixo, o
/// relatório: os itens que mais ficam sem fazer nas rotinas confirmadas.
class MinistryRoutineTab extends ConsumerWidget {
  final String ministryId;

  const MinistryRoutineTab({super.key, required this.ministryId});

  Future<void> _openForService(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => WorshipServicePickerSheet(
        subtitle: 'Para abrir a rotina deste culto.',
        onSelected: (s) async {
          try {
            final runId = await ref
                .read(ministryRoutineRepositoryProvider)
                .open(ministryId, s.id);
            if (!context.mounted) return;
            await openRoutineRun(context, ministryId: ministryId, runId: runId);
          } on MinistryRoutineException catch (e) {
            if (context.mounted) showRoutineError(context, e);
          }
          invalidateMinistryRoutine(ref, ministryId);
        },
      ),
    );
  }

  Future<void> _useTemplate(BuildContext context, WidgetRef ref) async {
    try {
      final n = await ref
          .read(ministryRoutineRepositoryProvider)
          .useTemplate(ministryId);
      invalidateMinistryRoutine(ref, ministryId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n itens do modelo foram acrescentados.')),
        );
      }
    } on MinistryRoutineException catch (e) {
      if (context.mounted) showRoutineError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsAsync = ref.watch(ministryRoutineCapsProvider(ministryId));
    final runsAsync = ref.watch(ministryRoutineRunsProvider(ministryId));
    final itemsAsync = ref.watch(ministryRoutineItemsProvider(ministryId));
    final team = {
      for (final m
          in ref.watch(ministryMembersProvider(ministryId)).valueOrNull ??
              const [])
        m.memberId: m.memberName,
    };
    final meta = CommunityDesign.metaStyle(context);

    final error = capsAsync.error ?? runsAsync.error ?? itemsAsync.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Não deu para carregar a rotina', style: meta),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              TextButton(
                onPressed: () {
                  ref.invalidate(ministryRoutineCapsProvider(ministryId));
                  invalidateMinistryRoutine(ref, ministryId);
                },
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    final caps = capsAsync.valueOrNull;
    final runs = runsAsync.valueOrNull;
    final items = itemsAsync.valueOrNull;
    if (caps == null || runs == null || items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!caps.canView) {
      return Center(
        child: Text('Só a equipe do ministério vê a rotina.', style: meta),
      );
    }

    final missed = mostMissedRoutineItems(runs);

    return RefreshIndicator(
      onRefresh: () async {
        invalidateMinistryRoutine(ref, ministryId);
        await ref.read(ministryRoutineRunsProvider(ministryId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'itens'} '
                  'na rotina',
                  style: meta,
                ),
              ),
              if (caps.canManage)
                TextButton.icon(
                  key: const ValueKey('routine-config'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MinistryRoutineConfigScreen(ministryId: ministryId),
                    ),
                  ),
                  icon: const Icon(AppIcons.tune, size: 18),
                  label: const Text('Configurar itens'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    caps.canManage
                        ? 'A rotina ainda não tem itens. Monte a sua em '
                              '"Configurar itens" ou comece pelo modelo do '
                              'Diaconato (pré, durante e pós-culto).'
                        : 'O líder ainda não montou a rotina deste ministério.',
                    style: meta,
                  ),
                  if (caps.canManage) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const ValueKey('routine-use-template'),
                      onPressed: () => _useTemplate(context, ref),
                      child: const Text('Usar modelo do Diaconato'),
                    ),
                  ],
                ],
              ),
            )
          else if (caps.canMark)
            FilledButton.icon(
              key: const ValueKey('routine-open-service'),
              onPressed: () => _openForService(context, ref),
              icon: const Icon(AppIcons.checklist),
              label: const Text('Rotina de um culto'),
            ),
          const SizedBox(height: 20),
          Text(
            'Rotinas recentes',
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (runs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Nenhuma rotina aberta ainda.', style: meta),
            ),
          for (final r in runs)
            _RunCard(
              run: r,
              leaderName: team[r.leaderOfDay],
              onTap: () async {
                await openRoutineRun(
                  context,
                  ministryId: ministryId,
                  runId: r.id,
                );
                invalidateMinistryRoutine(ref, ministryId);
              },
            ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'O que mais fica sem fazer',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Nas rotinas confirmadas acima.', style: meta),
            const SizedBox(height: 8),
            for (final (title, n, total) in missed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title)),
                    const SizedBox(width: 8),
                    Text('$n de $total cultos', style: meta),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final RoutineRun run;
  final String? leaderName;
  final VoidCallback onTap;

  const _RunCard({required this.run, this.leaderName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = run.checks.length;
    final pct = total == 0 ? 0 : (run.doneCount * 100 / total).round();
    final color = run.confirmed ? AppTheme.successColor : AppTheme.warningColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routineServiceLabel(run),
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${run.doneCount} de $total feitos ($pct%)',
                      if (leaderName != null) 'Líder do dia: $leaderName',
                    ].join(' · '),
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                run.confirmed ? 'Confirmada' : 'Aberta',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Dom, 12 de out · 19:00".
String routineServiceLabel(RoutineRun run) {
  final d = run.serviceDate;
  if (d == null) return 'Culto';
  final s = DateFormat("EEE, d 'de' MMM", 'pt_BR').format(d);
  final time = (run.serviceTime ?? '');
  final label = s[0].toUpperCase() + s.substring(1);
  return time.length >= 5 ? '$label · ${time.substring(0, 5)}' : label;
}

void showRoutineError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
}
