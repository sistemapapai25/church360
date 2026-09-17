import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Filtro de batismo.
///
/// ⚠️ Deriva de `baptismDate != null` — **batismo realizado**. Não confundir
/// com o campo `wantsBaptism` do modelo, que é interesse declarado por
/// visitante: filtrar por ele devolve uma lista completamente diferente.
///
/// A opção negativa se chama "Sem registro", e não "Não batizado", porque o
/// banco não sabe a diferença: ausência de `baptism_date` é ausência de dado,
/// não prova de que a pessoa não foi batizada. Em 17/09/2026 o campo estava
/// preenchido em 11 de 263 pessoas do tenant real (4%) — com o rótulo antigo,
/// o filtro afirmava "não batizado" para ~252 pessoas, quase todas batizadas.
/// Se um dia o cadastro for preenchido, isto continua correto: "sem registro"
/// simplesmente esvazia.
enum BaptismOption {
  all('Todos'),
  baptized('Batizado'),
  noRecord('Sem registro');

  final String label;
  const BaptismOption(this.label);

  /// Verifica se a data de batismo do membro casa com a opção.
  bool matches(DateTime? baptismDate) {
    switch (this) {
      case BaptismOption.all:
        return true;
      case BaptismOption.baptized:
        return baptismDate != null;
      case BaptismOption.noRecord:
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
        const SizedBox(height: 6),
        // Sem esta linha o usuario le "Sem registro" como "nao batizado", que
        // e exatamente o erro que o rotulo antigo cometia.
        Text(
          '"Sem registro" é data de batismo em branco — não é o mesmo que '
          'não batizado.',
          style: CommunityDesign.contentStyle(context).copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
