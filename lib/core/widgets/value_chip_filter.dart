import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Uma opção de filtro: o valor cru que vai ao banco e o rótulo de tela.
///
/// `value == null` é sempre a opção "Todos" — quem consome trata `null` como
/// "não filtra".
class ValueChipOption {
  final String? value;
  final String label;

  const ValueChipOption(this.value, this.label);
}

/// Filtro genérico de chips sobre um campo de texto do modelo.
///
/// Serve tanto para lista fixa (gênero) quanto para lista montada a partir dos
/// valores que realmente existem nos dados carregados (tipo de membro,
/// situação). Montar a lista a partir dos dados evita oferecer um filtro que
/// nunca devolve ninguém.
class ValueChipFilter extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<ValueChipOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const ValueChipFilter({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon = Icons.tune,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Com uma opção real só (além de "Todos"), o filtro não separa nada.
    if (options.where((o) => o.value != null).length < 2) {
      return const SizedBox.shrink();
    }

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
          children: options.map((option) {
            return ChoiceChip(
              label: Text(option.label),
              selected: selected == option.value,
              onSelected: (_) => onChanged(option.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
