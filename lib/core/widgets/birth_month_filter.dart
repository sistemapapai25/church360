import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Mês de aniversário. `null` = todos.
///
/// Filtra só pelo mês, ignorando dia e ano: é o recorte que a secretaria usa
/// para montar a lista de aniversariantes do mês.
class BirthMonthSelection {
  final int? month;

  const BirthMonthSelection({this.month});

  static const List<String> monthLabels = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  bool get isActive => month != null;

  /// Membro sem data de nascimento não tem mês e fica de fora quando há
  /// filtro — mesma regra da faixa etária.
  bool matches(DateTime? birthdate) {
    if (month == null) return true;
    if (birthdate == null) return false;
    return birthdate.month == month;
  }
}

/// Filtro visual de mês de aniversário.
class BirthMonthFilter extends StatelessWidget {
  final String label;
  final BirthMonthSelection selection;
  final ValueChanged<BirthMonthSelection> onChanged;
  final IconData icon;

  const BirthMonthFilter({
    super.key,
    this.label = 'Mês de aniversário',
    required this.selection,
    required this.onChanged,
    this.icon = Icons.celebration_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: selection.month == null,
              onSelected: (_) => onChanged(const BirthMonthSelection()),
            ),
            ...List.generate(12, (i) {
              final month = i + 1;
              return ChoiceChip(
                label: Text(BirthMonthSelection.monthLabels[i]),
                selected: selection.month == month,
                onSelected: (_) =>
                    onChanged(BirthMonthSelection(month: month)),
              );
            }),
          ],
        ),
      ],
    );
  }
}
