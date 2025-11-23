import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/custom_report.dart';
import '../providers/custom_report_providers.dart';

/// Tela de listagem de relatórios customizados
class CustomReportsListScreen extends ConsumerStatefulWidget {
  const CustomReportsListScreen({super.key});

  @override
  ConsumerState<CustomReportsListScreen> createState() => _CustomReportsListScreenState();
}

class _CustomReportsListScreenState extends ConsumerState<CustomReportsListScreen> {
  bool _showOnlyMyReports = false;

  @override
  Widget build(BuildContext context) {
    final reportsAsync = _showOnlyMyReports
        ? ref.watch(myCustomReportsProvider)
        : ref.watch(allCustomReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Customizados'),
        actions: [
          // Toggle entre todos os relatórios e meus relatórios
          IconButton(
            icon: Icon(_showOnlyMyReports ? Icons.people : Icons.person),
            onPressed: () {
              setState(() {
                _showOnlyMyReports = !_showOnlyMyReports;
              });
            },
            tooltip: _showOnlyMyReports ? 'Ver Todos' : 'Ver Meus Relatórios',
          ),
        ],
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allCustomReportsProvider);
              ref.invalidate(myCustomReportsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return _ReportCard(
                  report: report,
                  onTap: () {
                    context.push('/custom-reports/${report.id}/view');
                  },
                  onEdit: () {
                    context.push('/custom-reports/${report.id}/edit');
                  },
                  onDuplicate: () => _duplicateReport(report),
                  onDelete: () => _confirmDelete(context, report),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar relatórios: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allCustomReportsProvider);
                  ref.invalidate(myCustomReportsProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/custom-reports/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Relatório'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            _showOnlyMyReports
                ? 'Você ainda não criou nenhum relatório'
                : 'Nenhum relatório disponível',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie relatórios personalizados para visualizar seus dados',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/custom-reports/new');
            },
            icon: const Icon(Icons.add),
            label: const Text('Criar Primeiro Relatório'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateReport(CustomReport report) async {
    try {
      final duplicate = ref.read(duplicateCustomReportProvider);
      await duplicate(report.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relatório duplicado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao duplicar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, CustomReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir o relatório "${report.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final delete = ref.read(deleteCustomReportProvider);
        await delete(report.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Relatório excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir relatório: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Card de relatório
class _ReportCard extends StatelessWidget {
  final CustomReport report;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Nome + Ícone do tipo de visualização
              Row(
                children: [
                  _getVisualizationIcon(report.visualizationType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),

              if (report.description != null && report.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  report.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Badges: Fonte de dados + Tipo de visualização
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: report.dataSource.label,
                    icon: Icons.storage,
                    color: Colors.blue,
                  ),
                  _Badge(
                    label: report.visualizationType.label,
                    icon: Icons.bar_chart,
                    color: Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Duplicar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getVisualizationIcon(visualizationType) {
    IconData iconData;
    Color color;

    switch (visualizationType.value) {
      case 'pie':
        iconData = Icons.pie_chart;
        color = Colors.orange;
        break;
      case 'bar':
      case 'horizontal_bar':
        iconData = Icons.bar_chart;
        color = Colors.blue;
        break;
      case 'line':
        iconData = Icons.show_chart;
        color = Colors.green;
        break;
      case 'area':
        iconData = Icons.area_chart;
        color = Colors.teal;
        break;
      case 'table':
        iconData = Icons.table_chart;
        color = Colors.purple;
        break;
      case 'card':
      case 'kpi':
      case 'multi_card':
        iconData = Icons.dashboard;
        color = Colors.indigo;
        break;
      case 'gauge':
        iconData = Icons.speed;
        color = Colors.red;
        break;
      default:
        iconData = Icons.assessment;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}

/// Badge para exibir informações
class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
