import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Filtro de valor único em dropdown, para campos com lista longa e aberta:
/// cidade, bairro, profissão.
///
/// Chips não servem aqui — uma igreja pode ter dezenas de bairros e o painel
/// viraria uma parede. A lista vem dos valores que existem nos dados
/// carregados, então nunca oferece uma opção que devolve lista vazia.
class ValueDropdownFilter extends StatelessWidget {
  final String label;
  final IconData icon;

  /// Valores crus distintos, já ordenados pelo chamador.
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  /// Texto da opção "sem filtro".
  final String allLabel;

  const ValueDropdownFilter({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.icon = Icons.list,
    this.allLabel = 'Todos',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Com um valor só não há o que separar.
    if (values.length < 2) return const SizedBox.shrink();

    // Se o valor selecionado sumiu dos dados (mudou o recorte da lista), cai
    // para "Todos" em vez de estourar assertion do DropdownButton.
    final effective = (selected != null && values.contains(selected))
        ? selected
        : null;

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
        DropdownButtonFormField<String?>(
          initialValue: effective,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            ...values.map(
              (v) => DropdownMenuItem<String?>(value: v, child: Text(v)),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
