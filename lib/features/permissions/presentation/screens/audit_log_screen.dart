import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/permissions_providers.dart';

class _AuditActionOption {
  const _AuditActionOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _AuditActionOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Tela de Log de Auditoria
/// Exibe histórico de mudanças de permissões
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _filterUserId;
  String? _filterAction;
  DateTimeRange? _filterDateRange;

  @override
  Widget build(BuildContext context) {
    final auditLogAsync = ref.watch(auditLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Log de Auditoria',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtros',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros ativos
          if (_filterUserId != null || _filterAction != null || _filterDateRange != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filtros Ativos:',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterUserId = null;
                            _filterAction = null;
                            _filterDateRange = null;
                          });
                        },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_filterAction != null)
                        Chip(
                          label: Text('Ação: $_filterAction'),
                          onDeleted: () {
                            setState(() {
                              _filterAction = null;
                            });
                          },
                        ),
                      if (_filterDateRange != null)
                        Chip(
                          label: Text(
                            'Período: ${_formatDate(_filterDateRange!.start)} - ${_formatDate(_filterDateRange!.end)}',
                          ),
                          onDeleted: () {
                            setState(() {
                              _filterDateRange = null;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Lista de logs
          Expanded(
            child: auditLogAsync.when(
              data: (logs) {
                // Aplicar filtros
                var filteredLogs = logs;

                if (_filterAction != null) {
                  filteredLogs = filteredLogs.where((log) => log['action'] == _filterAction).toList();
                }

                if (_filterDateRange != null) {
                  filteredLogs = filteredLogs.where((log) {
                    final performedAt = DateTime.parse(log['performed_at'] as String);
                    return performedAt.isAfter(_filterDateRange!.start) &&
                        performedAt.isBefore(_filterDateRange!.end.add(const Duration(days: 1)));
                  }).toList();
                }

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum registro encontrado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(auditLogProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return _buildLogCard(context, log);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar logs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(auditLogProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, dynamic log) {
    final actionIcon = _getActionIcon(log.action);
    final actionColor = _getActionColor(context, log.action);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAction(log.action),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(log.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Detalhes do log
            if (log.details != null) ...[
              Text(
                'Detalhes:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.details.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'assign_role':
      case 'role_assigned':
        return Icons.person_add;
      case 'remove_role':
      case 'role_removed':
        return Icons.person_remove;
      case 'update_permissions':
      case 'permissions_updated':
        return Icons.security;
      case 'create_role':
      case 'role_created':
        return Icons.add_circle;
      case 'update_role':
      case 'role_updated':
        return Icons.edit;
      case 'delete_role':
      case 'role_deleted':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(BuildContext context, String action) {
    switch (action.toLowerCase()) {
      case 'assign_role':
      case 'role_assigned':
      case 'create_role':
      case 'role_created':
        return Colors.green;
      case 'remove_role':
      case 'role_removed':
      case 'delete_role':
      case 'role_deleted':
        return Colors.red;
      case 'update_permissions':
      case 'permissions_updated':
      case 'update_role':
      case 'role_updated':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatAction(String action) {
    final words = action.split('_');
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inHours < 1) {
      return 'Há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inDays < 1) {
      return 'Há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _showFilterDialog() async {
    final actionOptions = <_AuditActionOption>[
      const _AuditActionOption(null, 'Todas'),
      const _AuditActionOption('assign_role', 'Atribuir Cargo'),
      const _AuditActionOption('remove_role', 'Remover Cargo'),
      const _AuditActionOption('update_permissions', 'Atualizar Permissäes'),
      const _AuditActionOption('create_role', 'Criar Cargo'),
      const _AuditActionOption('update_role', 'Atualizar Cargo'),
    ];
    final selectedAction = actionOptions.firstWhere(
      (option) => option.value == _filterAction,
      orElse: () => actionOptions.first,
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filtro por ação

              DropdownMenu<_AuditActionOption>(
                initialSelection: selectedAction,
                label: const Text('A‡Æo'),
                dropdownMenuEntries: actionOptions
                  .map((option) => DropdownMenuEntry<_AuditActionOption>(
                    value: option,
                    label: option.label,
                  ))
                  .toList(),
                onSelected: (option) {
                  setState(() {
                    _filterAction = option?.value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Filtro por período
              ListTile(
                title: const Text('Período'),
                subtitle: Text(
                  _filterDateRange == null
                      ? 'Todos os períodos'
                      : '${_formatDate(_filterDateRange!.start)} - ${_formatDate(_filterDateRange!.end)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _filterDateRange,
                  );
                  if (range != null) {
                    setState(() {
                      _filterDateRange = range;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
