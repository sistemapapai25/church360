import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Faixas etárias rápidas para filtros por idade.
///
/// Os limites são inclusivos nas duas pontas: `Jovens (18-29)` pega quem tem
/// 18 e quem tem 29.
enum AgeRange {
  all('Todos', null, null),
  children('Crianças (0-11)', 0, 11),
  teens('Adolescentes (12-17)', 12, 17),
  youth('Jovens (18-29)', 18, 29),
  adults('Adultos (30-59)', 30, 59),
  seniors('Idosos (60+)', 60, null),
  custom('Idade personalizada', null, null);

  final String label;
  final int? min;
  final int? max;
  const AgeRange(this.label, this.min, this.max);
}

/// Resultado de seleção do filtro: faixa + intervalo customizado opcional.
class AgeRangeSelection {
  final AgeRange range;
  final int? customMin;
  final int? customMax;

  const AgeRangeSelection({
    this.range = AgeRange.all,
    this.customMin,
    this.customMax,
  });

  /// Resolve os limites (min, max) levando em conta a faixa selecionada.
  /// Retorna `(null, null)` para [AgeRange.all] ou intervalo vazio em custom.
  ({int? min, int? max}) resolve() {
    switch (range) {
      case AgeRange.all:
        return (min: null, max: null);
      case AgeRange.custom:
        if (customMin == null && customMax == null) {
          return (min: null, max: null);
        }
        return (min: customMin, max: customMax);
      default:
        return (min: range.min, max: range.max);
    }
  }

  /// Verifica se uma idade está dentro do filtro selecionado.
  ///
  /// O parâmetro é a idade **já calculada** (use o getter `age` do próprio
  /// modelo). Recalcular aqui faria o número do filtro divergir do número
  /// exibido no card do membro sempre que o aniversário caísse no meio.
  ///
  /// Retorna `true` quando o filtro é `all`. Membro sem data de nascimento
  /// (`age == null`) fica **de fora** de qualquer faixa — ele não tem como
  /// ser classificado, e incluí-lo inflaria toda contagem.
  bool matches(int? age) {
    if (range == AgeRange.all) return true;
    final limits = resolve();
    if (limits.min == null && limits.max == null) return true;
    if (age == null) return false;
    if (limits.min != null && age < limits.min!) return false;
    if (limits.max != null && age > limits.max!) return false;
    return true;
  }

  /// `true` quando o filtro efetivamente restringe a lista.
  bool get isActive => range != AgeRange.all && resolve() != (min: null, max: null);

  AgeRangeSelection copyWith({
    AgeRange? range,
    int? customMin,
    int? customMax,
    bool clearCustomMin = false,
    bool clearCustomMax = false,
  }) {
    return AgeRangeSelection(
      range: range ?? this.range,
      customMin: clearCustomMin ? null : (customMin ?? this.customMin),
      customMax: clearCustomMax ? null : (customMax ?? this.customMax),
    );
  }
}

/// Filtro visual de faixa etária com chips e intervalo customizado.
class AgeRangeFilter extends StatelessWidget {
  final String label;
  final AgeRangeSelection selection;
  final ValueChanged<AgeRangeSelection> onChanged;
  final IconData icon;

  const AgeRangeFilter({
    super.key,
    this.label = 'Faixa etária',
    required this.selection,
    required this.onChanged,
    this.icon = Icons.cake_outlined,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final result = await showDialog<({int? min, int? max})>(
      context: context,
      builder: (_) => _CustomAgeDialog(
        initialMin: selection.customMin,
        initialMax: selection.customMax,
      ),
    );
    if (result == null) return;
    onChanged(
      AgeRangeSelection(
        range: AgeRange.custom,
        customMin: result.min,
        customMax: result.max,
      ),
    );
  }

  String _customRangeLabel() {
    final min = selection.customMin;
    final max = selection.customMax;
    if (min == null && max == null) return 'Definir idade';
    if (min != null && max != null) return 'De $min a $max anos';
    if (min != null) return 'A partir de $min anos';
    return 'Até $max anos';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = selection.range == AgeRange.custom;

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
          children: AgeRange.values.map((range) {
            final selected = selection.range == range;
            return ChoiceChip(
              label: Text(range.label),
              selected: selected,
              onSelected: (_) {
                if (range == AgeRange.custom) {
                  _pickCustomRange(context);
                } else {
                  onChanged(
                    selection.copyWith(
                      range: range,
                      clearCustomMin: true,
                      clearCustomMax: true,
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
            icon: const Icon(Icons.tune, size: 18),
            label: Text(_customRangeLabel()),
          ),
        ],
      ],
    );
  }
}

/// Diálogo de idade mínima/máxima. Os dois campos são opcionais: preencher só
/// um vale como "a partir de" ou "até".
class _CustomAgeDialog extends StatefulWidget {
  final int? initialMin;
  final int? initialMax;

  const _CustomAgeDialog({this.initialMin, this.initialMax});

  @override
  State<_CustomAgeDialog> createState() => _CustomAgeDialogState();
}

class _CustomAgeDialogState extends State<_CustomAgeDialog> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initialMin?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initialMax?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    final min = int.tryParse(_minController.text.trim());
    final max = int.tryParse(_maxController.text.trim());

    if (_minController.text.trim().isEmpty &&
        _maxController.text.trim().isEmpty) {
      setState(() => _error = 'Preencha ao menos uma das idades.');
      return;
    }
    if (_minController.text.trim().isNotEmpty && min == null ||
        _maxController.text.trim().isNotEmpty && max == null) {
      setState(() => _error = 'Use apenas números inteiros.');
      return;
    }
    if ((min != null && min < 0) || (max != null && max < 0)) {
      setState(() => _error = 'Idade não pode ser negativa.');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _error = 'A idade mínima não pode ser maior que a máxima.');
      return;
    }
    Navigator.of(context).pop((min: min, max: max));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Idade personalizada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'De',
                    suffixText: 'anos',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Até',
                    suffixText: 'anos',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Aplicar')),
      ],
    );
  }
}
