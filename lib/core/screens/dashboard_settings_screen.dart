import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/dashboard_widget.dart';
import '../providers/dashboard_widget_provider.dart';

/// Tela de configuração da Dashboard
class DashboardSettingsScreen extends ConsumerStatefulWidget {
  const DashboardSettingsScreen({super.key});

  @override
  ConsumerState<DashboardSettingsScreen> createState() => _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState extends ConsumerState<DashboardSettingsScreen> {
  List<DashboardWidget> _widgets = [];
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final widgetsAsync = ref.watch(allDashboardWidgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Dashboard'),
        actions: [
          // Botão de Restaurar Padrão
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restaurar Padrão',
            onPressed: () => _showRestoreDialog(context),
          ),
        ],
      ),
      body: widgetsAsync.when(
        data: (widgets) {
          if (_widgets.isEmpty || !_isReordering) {
            _widgets = List.from(widgets);
          }

          return Column(
            children: [
              // Header com instruções
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ative/desative widgets e arraste para reordenar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de widgets
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _widgets.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      _isReordering = true;
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _widgets.removeAt(oldIndex);
                      _widgets.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final widget = _widgets[index];
                    return _buildWidgetCard(widget, index);
                  },
                ),
              ),

              // Botão de Salvar (aparece quando há mudanças)
              if (_isReordering)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isReordering = false;
                              _widgets = List.from(widgets);
                            });
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _saveOrder(),
                          child: const Text('Salvar Ordem'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildWidgetCard(DashboardWidget widget, int index) {
    return Card(
      key: ValueKey(widget.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de reordenar (arrastável)
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            // Ícone do widget
            CircleAvatar(
              backgroundColor: _getCategoryColor(widget.category).withValues(alpha: 0.2),
              child: Icon(
                _getIconData(widget.iconName),
                color: _getCategoryColor(widget.category),
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          widget.widgetName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.description != null)
              Text(widget.description!),
            const SizedBox(height: 4),
            Text(
              _getCategoryLabel(widget.category),
              style: TextStyle(
                fontSize: 12,
                color: _getCategoryColor(widget.category),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: widget.isEnabled,
          onChanged: (value) => _toggleWidget(widget.id, value),
        ),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.widgets;
    
    final iconMap = {
      'cake': Icons.cake,
      'person_add': Icons.person_add,
      'trending_up': Icons.trending_up,
      'label': Icons.label,
      'event': Icons.event,
      'calendar_today': Icons.calendar_today,
      'groups': Icons.groups,
      'people': Icons.people,
      'payments': Icons.payments,
      'account_balance': Icons.account_balance,
      'pie_chart': Icons.pie_chart,
      'flag': Icons.flag,
    };

    return iconMap[iconName] ?? Icons.widgets;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'members':
        return Colors.blue;
      case 'events':
        return Colors.orange;
      case 'groups':
        return Colors.purple;
      case 'attendance':
        return Colors.green;
      case 'financial':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'members':
        return 'MEMBROS';
      case 'events':
        return 'EVENTOS';
      case 'groups':
        return 'GRUPOS';
      case 'attendance':
        return 'PRESENÇA';
      case 'financial':
        return 'FINANCEIRO';
      default:
        return 'OUTRO';
    }
  }

  Future<void> _toggleWidget(String id, bool isEnabled) async {
    try {
      final repository = ref.read(dashboardWidgetRepositoryProvider);
      await repository.updateEnabled(id, isEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnabled ? 'Widget ativado' : 'Widget desativado'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar widget: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveOrder() async {
    try {
      final repository = ref.read(dashboardWidgetRepositoryProvider);
      
      // Criar lista de updates
      final updates = _widgets.asMap().entries.map((entry) {
        return {
          'id': entry.value.id,
          'display_order': entry.key + 1,
        };
      }).toList();

      await repository.updateMultiple(updates);

      setState(() {
        _isReordering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar ordem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRestoreDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Padrão'),
        content: const Text(
          'Isso irá restaurar todos os widgets para a configuração padrão. '
          'Todos os widgets serão reativados e reordenados. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);

      try {
        final repository = ref.read(dashboardWidgetRepositoryProvider);
        await repository.restoreDefaults();

        if (!context.mounted) return;

        setState(() {
          _isReordering = false;
        });

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Configuração padrão restaurada!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar padrão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
