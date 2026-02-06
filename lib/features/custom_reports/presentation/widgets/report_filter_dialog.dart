import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/report_filter_state.dart';

class _NullableStringOption {
  const _NullableStringOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _NullableStringOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Dialog para aplicar filtros temporários em um relatório
class ReportFilterDialog extends StatefulWidget {
  final ReportFilterState initialState;
  final Function(ReportFilterState) onApply;

  const ReportFilterDialog({
    super.key,
    required this.initialState,
    required this.onApply,
  });

  @override
  State<ReportFilterDialog> createState() => _ReportFilterDialogState();
}

class _ReportFilterDialogState extends State<ReportFilterDialog> {
  late ReportFilterState _currentState;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    final availableFilters = ReportFilterState.getAvailableFilters(_currentState.dataSource);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (_currentState.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentState = _currentState.clear();
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filtros
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: availableFilters.map((filter) {
                  return _buildFilterWidget(filter);
                }).toList(),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      widget.onApply(_currentState);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: Text(
                      _currentState.hasActiveFilters
                          ? 'Aplicar (${_currentState.activeFilterCount})'
                          : 'Aplicar',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterWidget(FilterOption filter) {
    switch (filter.type) {
      case FilterType.dateRange:
        return _buildDateRangeFilter(filter);
      case FilterType.select:
        return _buildSelectFilter(filter);
      case FilterType.text:
        return _buildTextFilter(filter);
      case FilterType.number:
        return _buildNumberFilter(filter);
    }
  }

  Widget _buildDateRangeFilter(FilterOption filter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  filter.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _currentState.startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _currentState = _currentState.copyWith(startDate: date);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _currentState.startDate != null
                          ? _dateFormat.format(_currentState.startDate!)
                          : 'Data Inicial',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _currentState.endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _currentState = _currentState.copyWith(endDate: date);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _currentState.endDate != null
                          ? _dateFormat.format(_currentState.endDate!)
                          : 'Data Final',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectFilter(FilterOption filter) {
    String? currentValue;
    if (filter.key == 'status') currentValue = _currentState.status;
    if (filter.key == 'gender') currentValue = _currentState.gender;
    if (filter.key == 'type') currentValue = _currentState.type;

    final options = <_NullableStringOption>[
      const _NullableStringOption(null, 'Todos'),
      ...?filter.options?.map((option) => _NullableStringOption(option, option)),
    ];
    final selectedOption = options.firstWhere(
      (option) => option.value == currentValue,
      orElse: () => options.first,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  filter.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownMenu<_NullableStringOption>(
              initialSelection: selectedOption,
              label: Text('Selecione ${filter.label.toLowerCase()}'),
              dropdownMenuEntries: options
                  .map((option) => DropdownMenuEntry<_NullableStringOption>(
                        value: option,
                        label: option.label,
                      ))
                  .toList(),
              onSelected: (option) {
                final value = option?.value;
                setState(() {
                  if (filter.key == 'status') {
                    _currentState = _currentState.copyWith(status: value);
                  } else if (filter.key == 'gender') {
                    _currentState = _currentState.copyWith(gender: value);
                  } else if (filter.key == 'type') {
                    _currentState = _currentState.copyWith(type: value);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFilter(FilterOption filter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            labelText: filter.label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberFilter(FilterOption filter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            labelText: filter.label,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }
}
