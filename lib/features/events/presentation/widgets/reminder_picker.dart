import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presets rotulados em português, em minutos. D-02 não impõe limite de
/// quantidade de lembretes; estes presets são só atalho — a entrada livre
/// abaixo cobre qualquer offset dentro da faixa do servidor.
const List<({String label, int minutes})> _kReminderPresets = [
  (label: '15 minutos antes', minutes: 15),
  (label: '1 hora antes', minutes: 60),
  (label: '2 horas antes', minutes: 120),
  (label: '24 horas antes', minutes: 1440),
  (label: '48 horas antes', minutes: 2880),
  (label: '1 semana antes', minutes: 10080),
];

enum _ReminderUnit { minutos, horas, dias }

/// Abre o seletor de lembrete de evento. Retorna o `offset_minutes`
/// escolhido, ou `null` se o usuário fechar sem concluir.
///
/// [existingOffsets] são os offsets já cadastrados no evento — o servidor
/// tem `UNIQUE (event_id, offset_minutes)` (`event_reminder_unique`), então
/// o picker desabilita/marca os presets repetidos e recusa a entrada livre
/// repetida, para o usuário não descobrir o limite por erro 409 do banco.
Future<int?> showReminderPicker(
  BuildContext context, {
  required List<int> existingOffsets,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReminderPicker(existingOffsets: existingOffsets),
  );
}

class ReminderPicker extends ConsumerStatefulWidget {
  final List<int> existingOffsets;

  const ReminderPicker({super.key, required this.existingOffsets});

  @override
  ConsumerState<ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends ConsumerState<ReminderPicker> {
  final _customValueController = TextEditingController();
  _ReminderUnit _customUnit = _ReminderUnit.horas;
  String? _customError;

  @override
  void dispose() {
    _customValueController.dispose();
    super.dispose();
  }

  bool _isUsed(int minutes) => widget.existingOffsets.contains(minutes);

  int _toMinutes(int value, _ReminderUnit unit) {
    switch (unit) {
      case _ReminderUnit.minutos:
        return value;
      case _ReminderUnit.horas:
        return value * 60;
      case _ReminderUnit.dias:
        return value * 1440;
    }
  }

  String _unitLabel(_ReminderUnit unit) {
    switch (unit) {
      case _ReminderUnit.minutos:
        return 'Minutos';
      case _ReminderUnit.horas:
        return 'Horas';
      case _ReminderUnit.dias:
        return 'Dias';
    }
  }

  void _confirmCustom() {
    final rawValue = int.tryParse(_customValueController.text.trim());
    if (rawValue == null || rawValue <= 0) {
      setState(() => _customError = 'Informe um número inteiro maior que zero.');
      return;
    }

    final minutes = _toMinutes(rawValue, _customUnit);

    // Espelha o CHECK do servidor (event_reminder_offset_chk): 1 minuto a
    // 525600 minutos (1 ano). Validar aqui evita que o usuário descubra o
    // limite só quando o Postgres recusar o INSERT.
    if (minutes <= 0 || minutes > 525600) {
      setState(
        () => _customError =
            'O lembrete precisa ser entre 1 minuto e 525600 minutos (1 ano) antes do evento.',
      );
      return;
    }

    // event_reminder_unique: (event_id, offset_minutes) não pode repetir.
    if (_isUsed(minutes)) {
      setState(
        () => _customError =
            'Já existe um lembrete com esse mesmo tempo de antecedência neste evento.',
      );
      return;
    }

    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Adicionar lembrete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                for (final preset in _kReminderPresets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: _isUsed(preset.minutes)
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                          : colorScheme.primary,
                    ),
                    title: Text(
                      preset.label,
                      style: TextStyle(
                        color: _isUsed(preset.minutes)
                            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                            : colorScheme.onSurface,
                      ),
                    ),
                    trailing: _isUsed(preset.minutes)
                        ? const Text('já adicionado')
                        : null,
                    enabled: !_isUsed(preset.minutes),
                    onTap: () => Navigator.pop(context, preset.minutes),
                  ),
                const Divider(height: 32),
                Text(
                  'Ou escolha um tempo personalizado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_ReminderUnit>(
                        initialValue: _customUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unidade',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final unit in _ReminderUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(_unitLabel(unit)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _customUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_customError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _customError!,
                    style: TextStyle(fontSize: 13, color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _confirmCustom,
                    child: const Text('Adicionar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
