import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/custom_report.dart';
import '../../domain/models/report_filter_state.dart';
import '../providers/custom_report_data_provider.dart';
import '../providers/custom_report_providers.dart';
import 'custom_report_chart_renderer.dart';

/// B4 (roadmap Home/culto/Dashboard, 14/10/2026): o card `custom_report_<id>`
/// da Dashboard mostra o gráfico do relatório, com o mesmo provider e o mesmo
/// renderizador da tela `/custom-reports/:id/view` (filtros salvos inclusos).
///
/// O [customReportDataProvider] já aplica [reportSourceAllowedProvider]:
/// quem tem `reports.view` mas não pode ler a fonte (ex.: financeiro sem
/// `financial.view_reports`) recebe [ReportAccessDenied] e vê só o título.
/// O dado fica em cache pela sessão (o provider não é autoDispose); o
/// pull-to-refresh da Dashboard invalida.
class CustomReportDashboardCard extends ConsumerWidget {
  const CustomReportDashboardCard({super.key, required this.reportId});

  final String reportId;

  /// Altura fixa do gráfico: no PC a moldura do card rola, no celular a
  /// página; um gráfico sem altura não cabe em nenhum dos dois.
  static const double chartHeight = 220;

  /// Grupos mostrados no card; o relatório completo abre ao tocar.
  static const int maxRows = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(customReportByIdProvider(reportId));
    final theme = Theme.of(context);

    return reportAsync.when(
      data: (report) {
        if (report == null) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.push('/custom-reports/$reportId/view'),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (report.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      report.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  _ChartSection(report: report),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _ChartSection extends ConsumerStatefulWidget {
  const _ChartSection({required this.report});

  final CustomReport report;

  @override
  ConsumerState<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends ConsumerState<_ChartSection> {
  /// Filtros salvos no relatório, montados uma vez: a chave do provider é
  /// um record com este objeto e `ReportFilterState` não tem `==`; um objeto
  /// novo a cada build criaria um provider novo a cada frame.
  late ReportFilterState _filterState = _fromReport(widget.report);

  static ReportFilterState _fromReport(CustomReport r) =>
      ReportFilterState.fromJson(r.dataSource, r.config.savedFilters?['main']);

  @override
  void didUpdateWidget(covariant _ChartSection old) {
    super.didUpdateWidget(old);
    if (old.report != widget.report ||
        old.report.updatedAt != widget.report.updatedAt) {
      _filterState = _fromReport(widget.report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final dataAsync = ref.watch(
      customReportDataProvider((report: report, filterState: _filterState)),
    );

    return dataAsync.when(
      data: (data) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          height: CustomReportDashboardCard.chartHeight,
          child: CustomReportChartRenderer(
            visualizationType: report.visualizationType,
            data: data.take(CustomReportDashboardCard.maxRows).toList(),
          ),
        ),
      ),
      loading: () => const SizedBox(
        height: CustomReportDashboardCard.chartHeight,
        child: Center(child: CircularProgressIndicator()),
      ),
      // Sem acesso à fonte: só o título (decisão do roadmap, B4).
      error: (error, _) => error is ReportAccessDenied
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Não foi possível carregar os dados',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
    );
  }
}
