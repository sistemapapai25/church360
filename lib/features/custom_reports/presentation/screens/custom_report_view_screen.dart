import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/enums/report_enums.dart';
import '../../domain/models/custom_report.dart';
import '../../domain/models/report_config.dart';
import '../../domain/models/report_filter_state.dart';
import '../providers/custom_report_providers.dart';
import '../providers/custom_report_data_provider.dart';
import '../widgets/report_filter_dialog.dart';
import '../widgets/custom_report_chart_renderer.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/utils/csv_writer.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/widgets/share_link_dialog.dart';
import '../../../../core/layout/readable_width.dart';

/// Tela de visualização de um relatório customizado
class CustomReportViewScreen extends ConsumerStatefulWidget {
  final String reportId;

  const CustomReportViewScreen({
    super.key,
    required this.reportId,
  });

  @override
  ConsumerState<CustomReportViewScreen> createState() => _CustomReportViewScreenState();
}

class _CustomReportViewScreenState extends ConsumerState<CustomReportViewScreen> {
  // Estado de filtros para visualização principal
  ReportFilterState? _mainFilterState;

  // Estados de filtros para visualizações adicionais (por índice)
  final Map<int, ReportFilterState> _additionalFilterStates = {};

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(customReportByIdProvider(widget.reportId));
    final report = reportAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório Customizado'),
        actions: [
          PermissionGate(
            permission: 'reports.edit',
            showLoading: false,
            child: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: () {
                context.push('/custom-reports/${widget.reportId}/edit');
              },
            ),
          ),
          if (report != null)
            PermissionGate(
              permission: 'reports.edit',
              showLoading: false,
              child: IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Salvar filtros',
                onPressed: () => _saveFilters(report),
              ),
            ),
          if (report != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Exportar',
              onSelected: (format) => _export(report, pdf: format == 'pdf'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
                PopupMenuItem(value: 'csv', child: Text('Exportar planilha (CSV)')),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () {
              final url =
                  '${SupabaseConstants.appWebBaseUrl}custom-reports/${widget.reportId}/view';
              showShareLinkDialog(
                context,
                title: 'Compartilhar relatório',
                url: url,
                shareText: 'Relatório "${report?.name ?? ''}":\n$url',
                warning: 'Só abre para quem tem permissão de ver relatórios.',
              );
            },
          ),
        ],
      ),
      body: ReadableWidth(maxWidth: 1200, child: reportAsync.when(
        data: (report) {
          if (report == null) {
            return const Center(
              child: Text('Relatório não encontrado'),
            );
          }
          return _buildReportContent(context, report);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar relatório: $error'),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildReportContent(BuildContext context, CustomReport report) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customReportByIdProvider(widget.reportId));
        await Future.delayed(const Duration(milliseconds: 150));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do relatório
            _buildHeader(context, report),
            const SizedBox(height: 24),

            // Visualização principal
            _buildMainVisualization(context, report),
            const SizedBox(height: 24),

            // Visualizações adicionais
            if (report.config.visualizations.isNotEmpty) ...[
              Text(
                'Visualizações Adicionais',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...report.config.visualizations.asMap().entries.map((entry) {
                final index = entry.key;
                final viz = entry.value;

                // Inicializar estado de filtro se não existir
                _additionalFilterStates[index] ??= ReportFilterState.fromJson(
                    report.dataSource, report.config.savedFilters?[viz.id]);

                return Column(
                  children: [
                    _buildAdditionalVisualization(context, report, viz, index),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CustomReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assessment,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (report.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          report.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.storage, size: 16),
                  label: Text(report.dataSource.label),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                Chip(
                  avatar: const Icon(Icons.bar_chart, size: 16),
                  label: Text(report.visualizationType.label),
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
                if (report.config.visualizations.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.add_chart, size: 16),
                    label: Text('${report.config.visualizations.length} gráfico(s) adicional(is)'),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainVisualization(BuildContext context, CustomReport report) {
    // Inicializar estado de filtro se não existir
    _mainFilterState ??= ReportFilterState.fromJson(
        report.dataSource, report.config.savedFilters?['main']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visualização Principal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // PASSO 1: Botão de filtro no canto superior direito
                IconButton.filledTonal(
                  onPressed: () => _showFilterDialog(
                    context,
                    report,
                    isMain: true,
                  ),
                  icon: Badge(
                    isLabelVisible: _mainFilterState!.hasActiveFilters,
                    label: Text('${_mainFilterState!.activeFilterCount}'),
                    child: const Icon(Icons.filter_list),
                  ),
                  tooltip: 'Filtros',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Renderizar gráfico real com dados do Supabase
            SizedBox(
              height: 300,
              child: _buildChartWithData(
                  context, report, _mainFilterState, report.visualizationType),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalVisualization(
    BuildContext context,
    CustomReport report,
    ReportVisualization viz,
    int index,
  ) {
    final filterState = _additionalFilterStates[index]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    viz.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // PASSO 1: Botão de filtro no canto superior direito
                IconButton.filledTonal(
                  onPressed: () => _showFilterDialog(
                    context,
                    report,
                    vizIndex: index,
                  ),
                  icon: Badge(
                    isLabelVisible: filterState.hasActiveFilters,
                    label: Text('${filterState.activeFilterCount}'),
                    child: const Icon(Icons.filter_list),
                  ),
                  tooltip: 'Filtros',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Renderizar gráfico real com dados do Supabase
            SizedBox(
              height: 250,
              child: _buildChartWithData(context, report, filterState, viz.type),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostrar dialog de filtros
  void _showFilterDialog(
    BuildContext context,
    CustomReport report, {
    bool isMain = false,
    int? vizIndex,
  }) {
    // Determinar qual estado de filtro usar
    final currentState = isMain
        ? _mainFilterState!
        : _additionalFilterStates[vizIndex]!;

    showDialog(
      context: context,
      builder: (context) => ReportFilterDialog(
        initialState: currentState,
        onApply: (newState) {
          setState(() {
            if (isMain) {
              _mainFilterState = newState;
            } else {
              _additionalFilterStates[vizIndex!] = newState;
            }
          });

          // Os filtros são aplicados automaticamente pelo provider
          // O setState acima faz o widget reconstruir e buscar novos dados
          debugPrint('🔵 Filtros aplicados:');
          debugPrint('  - Período: ${newState.startDate} até ${newState.endDate}');
          debugPrint('  - Status: ${newState.status}');
          debugPrint('  - Gênero: ${newState.gender}');
          debugPrint('  - Total de filtros ativos: ${newState.activeFilterCount}');
        },
      ),
    );
  }

  /// Construir gráfico com dados reais do Supabase
  Widget _buildChartWithData(
    BuildContext context,
    CustomReport report,
    ReportFilterState? filterState,
    VisualizationType visualizationType,
  ) {
    // Buscar dados usando o provider
    final dataAsync = ref.watch(
      customReportDataProvider((
        report: report,
        filterState: filterState,
      )),
    );

    return dataAsync.when(
      data: (data) {
        return CustomReportChartRenderer(
          visualizationType: visualizationType,
          data: data,
          title: report.name,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error is ReportAccessDenied ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: error is ReportAccessDenied ? Colors.grey[500] : Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              error is ReportAccessDenied ? 'Sem acesso' : 'Erro ao carregar dados',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Grava no relatório os filtros aplicados agora (principal e adicionais).
  Future<void> _saveFilters(CustomReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = <String, dynamic>{
      if (_mainFilterState != null) 'main': _mainFilterState!.toJson(),
      for (final e in _additionalFilterStates.entries)
        if (e.key < report.config.visualizations.length)
          report.config.visualizations[e.key].id: e.value.toJson(),
    };
    try {
      await ref.read(updateCustomReportProvider)(
        report.copyWith(config: report.config.copyWith(savedFilters: saved)),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Filtros salvos no relatório')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível salvar os filtros: $e')),
      );
    }
  }

  /// Exporta os dados da visualização principal, com os filtros aplicados.
  Future<void> _export(CustomReport report, {required bool pdf}) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<Map<String, dynamic>> data;
    try {
      data = await ref.read(customReportDataProvider((
        report: report,
        filterState: _mainFilterState,
      )).future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível exportar: $e')));
      return;
    }

    final number = NumberFormat.decimalPattern('pt_BR');
    final valueHeader = report.config.aggregations.firstOrNull?.label ?? 'Valor';
    final rows = [
      for (final row in data)
        [row['label']?.toString() ?? '', number.format(row['value'] ?? 0)],
    ];
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    if (pdf) {
      final doc = pw.Document()
        ..addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(report.name,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Grupo', valueHeader],
              data: rows,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ));
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'relatorio_$stamp.pdf',
      );
      return;
    }

    final csv = CsvWriter(['Grupo', valueHeader]);
    rows.forEach(csv.addRow);
    final filename = 'relatorio_$stamp.csv';
    if (kIsWeb) {
      downloadCsv(filename, csv.build());
      messenger.showSnackBar(SnackBar(content: Text('Planilha baixada: $filename')));
    } else {
      await Share.share(csv.build(), subject: filename);
    }
  }
}
