import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/worship_service.dart';
import '../../data/worship_repository.dart';
import '../providers/worship_provider.dart';

class WorshipServiceFormScreen extends ConsumerStatefulWidget {
  final String? worshipServiceId;

  const WorshipServiceFormScreen({
    super.key,
    this.worshipServiceId,
  });

  @override
  ConsumerState<WorshipServiceFormScreen> createState() =>
      _WorshipServiceFormScreenState();
}

class _WorshipServiceFormScreenState
    extends ConsumerState<WorshipServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _themeController = TextEditingController();
  final _speakerController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  WorshipType _selectedType = WorshipType.sundayMorning;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.worshipServiceId != null) {
      _loadWorshipService();
    }
  }

  Future<void> _loadWorshipService() async {
    final service = await ref
        .read(worshipRepositoryProvider)
        .getServiceById(widget.worshipServiceId!);

    if (service != null) {
      setState(() {
        _selectedDate = service.serviceDate;
        // Convert String time to TimeOfDay
        if (service.serviceTime != null) {
          final parts = service.serviceTime!.split(':');
          if (parts.length >= 2) {
            _selectedTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
        _selectedType = service.serviceType;
        _themeController.text = service.theme ?? '';
        _speakerController.text = service.speaker ?? '';
        _notesController.text = service.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _themeController.dispose();
    _speakerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveWorshipService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(worshipRepositoryProvider);

      final data = {
        'service_date': _selectedDate.toIso8601String().split('T')[0],
        'service_time': _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'service_type': _selectedType.value,
        'theme': _themeController.text.trim().isEmpty
            ? null
            : _themeController.text.trim(),
        'speaker': _speakerController.text.trim().isEmpty
            ? null
            : _speakerController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      if (widget.worshipServiceId != null) {
        await repo.updateService(widget.worshipServiceId!, data);
      } else {
        await repo.createService(data);
      }

      // Invalidate providers to refresh data
      ref.invalidate(allWorshipServicesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.worshipServiceId != null
                  ? 'Culto atualizado com sucesso!'
                  : 'Culto cadastrado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar culto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getTypeIcon(WorshipType type) {
    switch (type) {
      case WorshipType.sundayMorning:
        return Icons.wb_sunny;
      case WorshipType.sundayEvening:
        return Icons.nightlight;
      case WorshipType.wednesday:
        return Icons.menu_book;
      case WorshipType.friday:
        return Icons.favorite;
      case WorshipType.special:
        return Icons.star;
      case WorshipType.other:
        return Icons.event;
    }
  }

  Color _getTypeColor(WorshipType type) {
    switch (type) {
      case WorshipType.sundayMorning:
        return Colors.orange;
      case WorshipType.sundayEvening:
        return Colors.indigo;
      case WorshipType.wednesday:
        return Colors.teal;
      case WorshipType.friday:
        return Colors.pink;
      case WorshipType.special:
        return Colors.amber;
      case WorshipType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.worshipServiceId != null ? 'Editar Culto' : 'Novo Culto',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data do Culto
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data do Culto'),
                subtitle: Text(_formatDate(_selectedDate)),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),
            ),
            const SizedBox(height: 16),

            // Horário do Culto
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Horário do Culto'),
                subtitle: Text(
                  _selectedTime != null
                      ? _formatTime(_selectedTime!)
                      : 'Não definido',
                ),
                trailing: const Icon(Icons.edit),
                onTap: _selectTime,
              ),
            ),
            const SizedBox(height: 16),

            // Tipo de Culto
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de Culto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WorshipType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getTypeIcon(type),
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : _getTypeColor(type),
                              ),
                              const SizedBox(width: 4),
                              Text(type.label),
                            ],
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = type;
                              });
                            }
                          },
                          selectedColor: _getTypeColor(type),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tema da Mensagem
            TextFormField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'Tema da Mensagem',
                hintText: 'Ex: O Amor de Deus',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Pregador
            TextFormField(
              controller: _speakerController,
              decoration: const InputDecoration(
                labelText: 'Pregador',
                hintText: 'Nome do pregador',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Observações
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Anotações sobre o culto',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveWorshipService,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isLoading
                    ? 'Salvando...'
                    : (widget.worshipServiceId != null
                        ? 'Atualizar Culto'
                        : 'Cadastrar Culto'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

