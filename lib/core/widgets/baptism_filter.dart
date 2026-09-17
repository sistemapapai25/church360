import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Filtro de batismo.
///
/// ⚠️ Deriva de `baptismDate != null` — **batismo realizado**. Não confundir
/// com o campo `wantsBaptism` do modelo, que é interesse declarado por
/// visitante: filtrar por ele devolve uma lista completamente diferente.
enum BaptismOption {
  all('Todos'),
  baptized('Batizado'),
  notBaptized('Não batizado');

  final String label;
  const BaptismOption(this.label);

  /// Verifica se a data de batismo do membro casa com a opção.
  bool matches(DateTime? baptismDate) {
    switch (this) {
      case BaptismOption.all:
        return true;
      case BaptismOption.baptized:
        return baptismDate != null;
      case BaptismOption.notBaptized:
        return baptismDate == null;
    }
  }
}

/// Filtro visual de batismo com chips.
class BaptismFilter extends StatelessWidget {
  final String label;
  final BaptismOption selection;
  final ValueChanged<BaptismOption> onChanged;
  final IconData icon;

  const BaptismFilter({
    super.key,
    this.label = 'Batismo',
    required this.selection,
    required this.onChanged,
    this.icon = Icons.water_drop_outlined,
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
          children: BaptismOption.values.map((option) {
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
