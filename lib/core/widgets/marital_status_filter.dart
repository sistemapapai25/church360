import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Estado civil para filtro.
///
/// O rótulo é em português, mas [dbValue] é o valor cru gravado no banco pelo
/// formulário de membro (`member_form_screen.dart`). Filtrar pelo rótulo
/// quebraria na primeira mudança de texto.
enum MaritalStatusOption {
  all('Todos', null),
  single('Solteiro(a)', 'single'),
  married('Casado(a)', 'married'),
  divorced('Divorciado(a)', 'divorced'),
  widowed('Viúvo(a)', 'widowed');

  final String label;
  final String? dbValue;
  const MaritalStatusOption(this.label, this.dbValue);

  /// Verifica se o estado civil cru do membro casa com a opção.
  ///
  /// Membro sem estado civil preenchido (`null`) só aparece em [all].
  bool matches(String? value) {
    if (this == MaritalStatusOption.all) return true;
    return value == dbValue;
  }
}

/// Filtro visual de estado civil com chips.
class MaritalStatusFilter extends StatelessWidget {
  final String label;
  final MaritalStatusOption selection;
  final ValueChanged<MaritalStatusOption> onChanged;
  final IconData icon;

  const MaritalStatusFilter({
    super.key,
    this.label = 'Estado civil',
    required this.selection,
    required this.onChanged,
    this.icon = Icons.favorite_outline,
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
          children: MaritalStatusOption.values.map((option) {
            return ChoiceChip(
              label: Text(option.label),
              selected: selection == option,
              onSelected: (_) => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}
