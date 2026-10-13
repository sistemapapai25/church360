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
      builder: (_) => _CultoPickerSheet(
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

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    String model,
  ) async {
    try {
      final n = await ref
          .read(ministryRoutineRepositoryProvider)
          .useTemplate(ministryId, model);
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
                              '"Configurar itens" ou comece por um modelo '
                              '(pré, durante e pós-culto).'
                        : 'O líder ainda não montou a rotina deste ministério.',
                    style: meta,
                  ),
                  if (caps.canManage)
                    for (final (model, label) in routineTemplates) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: ValueKey('routine-use-template-$model'),
                        onPressed: () => _useTemplate(context, ref, model),
                        child: Text(label),
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
                      '${run.validatedCount} validados',
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

/// "Culto Quarta · Qua, 15 de out · 19:30".
String routineServiceLabel(RoutineRun run) =>
    _cultoLabel(run.serviceName, run.serviceDate, run.serviceTime);

String _cultoLabel(String? name, DateTime? d, String? time) {
  final parts = <String>[
    if ((name ?? '').trim().isNotEmpty) name!.trim(),
    if (d != null)
      () {
        final s = DateFormat("EEE, d 'de' MMM", 'pt_BR').format(d);
        return s[0].toUpperCase() + s.substring(1);
      }(),
    if (time != null && time != '00:00') time,
  ];
  return parts.isEmpty ? 'Culto' : parts.join(' · ');
}

final _routineCultosProvider = FutureProvider.autoDispose<List<RoutineCulto>>(
  (ref) => ref.watch(ministryRoutineRepositoryProvider).cultos(),
);

/// Escolher o culto da Agenda (event_type `culto%`) para abrir a rotina.
class _CultoPickerSheet extends ConsumerWidget {
  final void Function(RoutineCulto culto) onSelected;

  const _CultoPickerSheet({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = CommunityDesign.metaStyle(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selecione o culto',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cultos da Agenda: próximas 2 semanas e últimos 2 meses.',
              style: meta,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ref
                  .watch(_routineCultosProvider)
                  .when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('$e', textAlign: TextAlign.center),
                    ),
                    data: (cultos) => cultos.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'Nenhum culto na Agenda neste período.',
                              style: meta,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: cultos.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = cultos[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(AppIcons.event),
                                title: Text(c.name),
                                subtitle: Text(
                                  _cultoLabel(null, c.date, c.time),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onSelected(c);
                                },
                              );
                            },
                          ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRoutineError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
}
