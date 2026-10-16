import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ministries/shared/presentation/widgets/ministry_reports_tab.dart';
import '../providers/kids_providers.dart';

/// Cartão do Infantil na aba Relatórios (K8): presença das crianças pelo
/// check-in do Balcão, nos últimos 90 dias. Só a equipe do Infantil vê
/// (a RPC kids_report recusa os outros); para eles o cartão some.
class KidsReportCard extends ConsumerWidget {
  const KidsReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(kidsReportProvider).asData?.value;
    if (report == null) return const SizedBox.shrink();

    final events = (report['by_event'] as List? ?? const []);
    final top = (report['top_children'] as List? ?? const []);
    final days = report['days'] ?? 90;

    return Column(
      children: [
        MinistryReportCard(
          icon: Icons.child_care,
          title: 'Crianças (últimos $days dias)',
          lines: [
            MinistryReportLine(
              'Cultos com check-in',
              '${report['events'] ?? 0}',
            ),
            MinistryReportLine(
              'Crianças diferentes',
              '${report['children'] ?? 0}',
            ),
            MinistryReportLine('Média por culto', '${report['average'] ?? 0}'),
            MinistryReportLine(
              'Responsáveis chamados',
              '${report['calls'] ?? 0}',
            ),
          ],
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 10),
          MinistryReportCard(
            icon: Icons.event_available_outlined,
            title: 'Presença por culto',
            lines: [
              for (final e in events.cast<Map>())
                MinistryReportLine(
                  '${_date(e['date'])} ${e['name'] ?? ''}\n'
                      '${(e['rooms'] as List? ?? const []).cast<Map>().map((r) => '${r['room']}: ${r['n']}').join(' · ')}',
                  '${e['total']}',
                ),
            ],
          ),
        ],
        if (top.isNotEmpty) ...[
          const SizedBox(height: 10),
          MinistryReportCard(
            icon: Icons.star_outline,
            title: 'Mais presentes',
            lines: [
              for (final c in top.cast<Map>())
                MinistryReportLine('${c['name']}', '${c['n']} cultos'),
            ],
          ),
        ],
      ],
    );
  }

  static String _date(Object? iso) {
    final d = iso == null ? null : DateTime.tryParse('$iso');
    // start_date é hora de parede rotulada UTC: mostrar sem converter.
    return d == null ? '' : DateFormat('dd/MM').format(d.toUtc());
  }
}
