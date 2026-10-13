import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../shared/presentation/widgets/ministry_reports_tab.dart';
import '../../domain/models/raizes_followup.dart';
import '../providers/raizes_dashboard_provider.dart';

/// Cartões do Raízes na aba Relatórios (R9, manual §13): funil por etapa,
/// contato em até 24h, visitas por responsável e decisões por mês.
///
/// Os números vêm prontos da RPC `raizes_report`. Quem abre o Raízes sem
/// visitors.view/followup recebe 42501 e vê só o aviso, como no caixa.
class RaizesReportCards extends ConsumerWidget {
  final String ministryId;

  const RaizesReportCards({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(raizesReportProvider(ministryId)).when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const MinistryReportCard(
        icon: AppIcons.visitor,
        title: 'Acompanhamento de visitantes',
        lines: [
          MinistryReportLine(
            'Fora deste resumo',
            'sem permissão de ver o acompanhamento',
          ),
        ],
      ),
      data: (r) => _Cards(report: r),
    );
  }
}

class _Cards extends StatelessWidget {
  final RaizesReport report;

  const _Cards({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final since = DateFormat('MM/yyyy').format(r.since);
    final pct = r.contactTotal == 0
        ? '—'
        : '${(r.contactOnTime * 100 / r.contactTotal).round()}%';

    return Column(
      children: [
        MinistryReportCard(
          icon: AppIcons.filterList,
          title: 'Funil por etapa',
          lines: [
            for (final s in RaizesStage.values)
              MinistryReportLine(s.label, '${r.funnel[s] ?? 0}'),
          ],
        ),
        const SizedBox(height: 10),
        MinistryReportCard(
          icon: AppIcons.phoneInTalk,
          title: 'Contato em até 24h (desde $since)',
          lines: [
            MinistryReportLine('No prazo', pct),
            MinistryReportLine(
              'Contatados no prazo',
              '${r.contactOnTime} de ${r.contactTotal}',
            ),
            MinistryReportLine('Contatados depois', '${r.contactLate}'),
            MinistryReportLine(
              'Ainda sem contato',
              '${r.contactNone}',
              warn: r.contactNone > 0,
            ),
          ],
        ),
        const SizedBox(height: 10),
        MinistryReportCard(
          icon: AppIcons.home,
          title: 'Visitas no lar por responsável (desde $since)',
          lines: [
            if (r.visits.isEmpty)
              const MinistryReportLine('Nenhuma visita agendada', '0'),
            for (final v in r.visits)
              MinistryReportLine(
                v.name,
                '${v.completed} feitas de ${v.total}'
                '${v.open > 0 ? ' · ${v.open} em aberto' : ''}',
              ),
          ],
        ),
        const SizedBox(height: 10),
        MinistryReportCard(
          icon: AppIcons.favorite,
          title: 'Decisões por mês (desde $since)',
          lines: [
            if (r.decisionsByMonth.isEmpty)
              const MinistryReportLine('Nenhuma decisão registrada', '0'),
            for (final e in r.decisionsByMonth.entries)
              MinistryReportLine(
                '${e.key.substring(5)}/${e.key.substring(0, 4)}',
                [
                  for (final d in RaizesDecision.values)
                    if ((e.value[d] ?? 0) > 0) '${d.label} ${e.value[d]}',
                ].join(' · '),
              ),
          ],
        ),
      ],
    );
  }
}
