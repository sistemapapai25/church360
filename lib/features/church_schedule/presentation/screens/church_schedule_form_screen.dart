import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/church_schedule.dart';
import '../providers/church_schedule_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';

class _ResponsibleOption {
  const _ResponsibleOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _ResponsibleOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Tela de formulário para criar/editar agenda da igreja
class ChurchScheduleFormScreen extends ConsumerStatefulWidget {
  final String? scheduleId;

  const ChurchScheduleFormScreen({super.key, this.scheduleId});

  @override
  ConsumerState<ChurchScheduleFormScreen> createState() => _ChurchScheduleFormScreenState();
}

class _ChurchScheduleFormScreenState extends ConsumerState<ChurchScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _scheduleType = 'other';
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);
  String? _responsibleId;
  String _recurrenceType = 'none';
  DateTime? _recurrenceEndDate;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleId != null) {
      _loadSchedule();
    }
  }

  Future<void> _loadSchedule() async {
    final schedule = await ref.read(churchScheduleByIdProvider(widget.scheduleId!).future);
    if (schedule != null && mounted) {
      setState(() {
        _titleController.text = schedule.title;
        _descriptionController.text = schedule.description ?? '';
        _locationController.text = schedule.location ?? '';
        _scheduleType = schedule.scheduleType;
        _startDate = schedule.startDatetime;
        _startTime = TimeOfDay.fromDateTime(schedule.startDatetime);
        _endDate = schedule.endDatetime;
        _endTime = TimeOfDay.fromDateTime(schedule.endDatetime);
        _responsibleId = schedule.responsibleId;
        _recurrenceType = schedule.recurrenceType;
        _recurrenceEndDate = schedule.recurrenceEndDate;
        _isActive = schedule.isActive;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheduleId == null ? 'Nova Agenda' : 'Editar Agenda'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Ex: Ensaio do Louvor',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, informe o título';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Tipo
            DropdownMenu<String>(
              initialSelection: _scheduleType,
              label: const Text('Tipo *'),
              dropdownMenuEntries: ScheduleType.values
                  .map((type) => DropdownMenuEntry<String>(value: type.value, label: type.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() => _scheduleType = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Detalhes sobre a atividade',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Data e hora de início
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Início *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_startDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startTime.format(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data e hora de fim
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Término *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_endDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endTime.format(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Local
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Local',
                hintText: 'Ex: Templo Principal',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 16),

            // Responsável
            membersAsync.when(
              data: (members) {
                final options = <_ResponsibleOption>[
                  const _ResponsibleOption(null, 'Nenhum'),
                  ...members.map((member) => _ResponsibleOption(member.id, member.displayName)),
                ];
                final selectedOption = options.firstWhere(
                  (option) => option.value == _responsibleId,
                  orElse: () => options.first,
                );

                return DropdownMenu<_ResponsibleOption>(
                  initialSelection: selectedOption,
                  label: const Text('Responsável'),
                  leadingIcon: const Icon(Icons.person),
                  dropdownMenuEntries: options
                    .map((option) => DropdownMenuEntry<_ResponsibleOption>(
                      value: option,
                      label: option.label,
                    ))
                    .toList(),
                  onSelected: (option) {
                    setState(() => _responsibleId = option?.value);
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Recorrência
            DropdownMenu<String>(
              initialSelection: _recurrenceType,
              label: const Text('Recorrência'),
              leadingIcon: const Icon(Icons.repeat),
              dropdownMenuEntries: RecurrenceType.values
                  .map((type) => DropdownMenuEntry<String>(value: type.value, label: type.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() => _recurrenceType = value);
                }
              },
            ),

            if (_recurrenceType != 'none') ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectRecurrenceEndDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Repetir até',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(
                    _recurrenceEndDate != null
                        ? DateFormat('dd/MM/yyyy').format(_recurrenceEndDate!)
                        : 'Sem data final',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Status ativo/inativo
            SwitchListTile(
              title: const Text('Ativo'),
              subtitle: Text(_isActive ? 'Agenda visível' : 'Agenda oculta'),
              value: _isActive,
              onChanged: (value) {
                setState(() => _isActive = value);
              },
            ),

            const SizedBox(height: 24),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveSchedule,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _recurrenceEndDate = picked;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final startDatetime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDatetime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final schedule = ChurchSchedule(
        id: widget.scheduleId ?? '',
        title: _titleController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        scheduleType: _scheduleType,
        startDatetime: startDatetime,
        endDatetime: endDatetime,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        responsibleId: _responsibleId,
        recurrenceType: _recurrenceType,
        recurrenceEndDate: _recurrenceEndDate,
        isActive: _isActive,
      );

      if (widget.scheduleId == null) {
        await ref.read(createChurchScheduleProvider)(schedule);
      } else {
        await ref.read(updateChurchScheduleProvider)(widget.scheduleId!, schedule);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.scheduleId == null
                  ? 'Agenda criada com sucesso'
                  : 'Agenda atualizada com sucesso',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar agenda: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
