import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Períodos rápidos para filtros por data.
enum DatePeriod {
  all('Todos'),
  thisMonth('Este mês'),
  last30Days('Últimos 30 dias'),
  last90Days('Últimos 90 dias'),
  thisYear('Ano atual'),
  custom('Personalizado');

  final String label;
  const DatePeriod(this.label);
}

/// Resultado de seleção do filtro: período + intervalo customizado opcional.
class DatePeriodSelection {
  final DatePeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DatePeriodSelection({
    this.period = DatePeriod.all,
    this.customStart,
    this.customEnd,
  });

  /// Resolve as datas (start, end) levando em conta o período selecionado.
  /// Retorna `(null, null)` para [DatePeriod.all] ou intervalo incompleto em custom.
  ({DateTime? start, DateTime? end}) resolve({DateTime? now}) {
    final today = now ?? DateTime.now();
    switch (period) {
      case DatePeriod.all:
        return (start: null, end: null);
      case DatePeriod.thisMonth:
        final s = DateTime(today.year, today.month, 1);
        return (start: s, end: today);
      case DatePeriod.last30Days:
        return (start: today.subtract(const Duration(days: 30)), end: today);
      case DatePeriod.last90Days:
        return (start: today.subtract(const Duration(days: 90)), end: today);
      case DatePeriod.thisYear:
        return (start: DateTime(today.year, 1, 1), end: today);
      case DatePeriod.custom:
        if (customStart == null || customEnd == null) {
          return (start: null, end: null);
        }
        return (start: customStart, end: customEnd);
    }
  }

  /// Verifica se uma data está dentro do filtro selecionado.
  /// Retorna `true` quando o filtro é `all` ou quando o `value` cai no intervalo.
  bool matches(DateTime? value, {DateTime? now}) {
    if (period == DatePeriod.all) return true;
    if (value == null) return false;
    final range = resolve(now: now);
    if (range.start == null || range.end == null) return true;
    final dayValue = DateTime(value.year, value.month, value.day);
    final dayStart = DateTime(
      range.start!.year,
      range.start!.month,
      range.start!.day,
    );
    final dayEnd = DateTime(
      range.end!.year,
      range.end!.month,
      range.end!.day,
    );
    return !dayValue.isBefore(dayStart) && !dayValue.isAfter(dayEnd);
  }

  DatePeriodSelection copyWith({
    DatePeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomStart = false,
    bool clearCustomEnd = false,
  }) {
    return DatePeriodSelection(
      period: period ?? this.period,
      customStart: clearCustomStart ? null : (customStart ?? this.customStart),
      customEnd: clearCustomEnd ? null : (customEnd ?? this.customEnd),
    );
  }
}

/// Filtro visual de período por data com chips e seletor de intervalo customizado.
class DatePeriodFilter extends StatelessWidget {
  final String label;
  final DatePeriodSelection selection;
  final ValueChanged<DatePeriodSelection> onChanged;
  final IconData icon;

  const DatePeriodFilter({
    super.key,
    required this.label,
    required this.selection,
    required this.onChanged,
    this.icon = Icons.event,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final initialRange = (selection.customStart != null && selection.customEnd != null)
        ? DateTimeRange(start: selection.customStart!, end: selection.customEnd!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
      helpText: 'Selecione o período de $label',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      onChanged(
        selection.copyWith(
          period: DatePeriod.custom,
          customStart: picked.start,
          customEnd: picked.end,
        ),
      );
    }
  }

  String _customRangeLabel() {
    final s = selection.customStart;
    final e = selection.customEnd;
    if (s == null || e == null) return 'Selecionar intervalo';
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${fmt(s)} - ${fmt(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = selection.period == DatePeriod.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DatePeriod.values.map((period) {
            final selected = selection.period == period;
            return ChoiceChip(
              label: Text(period.label),
              selected: selected,
              onSelected: (_) {
                if (period == DatePeriod.custom) {
                  _pickCustomRange(context);
                } else {
                  onChanged(
                    selection.copyWith(
                      period: period,
                      clearCustomStart: true,
                      clearCustomEnd: true,
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
        if (isCustom) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickCustomRange(context),
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(_customRangeLabel()),
          ),
        ],
      ],
    );
  }
}
