import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
import '../../data/events_repository.dart';

/// Tela de formulário de evento (criar/editar)
class EventFormScreen extends ConsumerStatefulWidget {
  final String? eventId; // null = criar, não-null = editar

  const EventFormScreen({
    super.key,
    this.eventId,
  });

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventTypeController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  
  // State
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _requiresRegistration = false;
  String _status = 'draft';
  
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;
    if (_isEditMode) {
      _loadEvent();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventTypeController.dispose();
    _locationController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    
    try {
      final event = await ref.read(eventsRepositoryProvider).getEventById(widget.eventId!);
      
      if (event != null) {
        _nameController.text = event.name;
        _descriptionController.text = event.description ?? '';
        _eventTypeController.text = event.eventType ?? '';
        _locationController.text = event.location ?? '';
        _maxCapacityController.text = event.maxCapacity?.toString() ?? '';
        
        _startDate = event.startDate;
        _startTime = TimeOfDay.fromDateTime(event.startDate);
        
        if (event.endDate != null) {
          _endDate = event.endDate;
          _endTime = TimeOfDay.fromDateTime(event.endDate!);
        }
        
        _requiresRegistration = event.requiresRegistration;
        _status = event.status;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar evento: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Evento' : 'Novo Evento'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nome
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Evento *',
                        prefixIcon: Icon(Icons.event),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nome é obrigatório';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Tipo
                    TextFormField(
                      controller: _eventTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Culto, Conferência, Retiro',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data de início
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Data de Início *'),
                      subtitle: Text(
                        _startDate != null
                            ? DateFormat('dd/MM/yyyy').format(_startDate!)
                            : 'Selecione a data',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _pickStartDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Horário de início
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Horário de Início *'),
                      subtitle: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Selecione o horário',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _pickStartTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data de término
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available),
                      title: const Text('Data de Término (opcional)'),
                      subtitle: Text(
                        _endDate != null
                            ? DateFormat('dd/MM/yyyy').format(_endDate!)
                            : 'Selecione a data',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() {
                                _endDate = null;
                                _endTime = null;
                              }),
                            ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: _pickEndDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Horário de término
                    if (_endDate != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: const Text('Horário de Término'),
                        subtitle: Text(
                          _endTime != null
                              ? _endTime!.format(context)
                              : 'Selecione o horário',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _pickEndTime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    if (_endDate != null) const SizedBox(height: 16),

                    // Local
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Local',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capacidade máxima
                    TextFormField(
                      controller: _maxCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacidade Máxima',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                        hintText: 'Deixe vazio para ilimitado',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final number = int.tryParse(value);
                          if (number == null || number <= 0) {
                            return 'Capacidade deve ser um número positivo';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Requer inscrição
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requer Inscrição'),
                      subtitle: const Text('Membros precisam se inscrever para participar'),
                      value: _requiresRegistration,
                      onChanged: (value) {
                        setState(() => _requiresRegistration = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Rascunho')),
                        DropdownMenuItem(value: 'published', child: Text('Publicado')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
                        DropdownMenuItem(value: 'completed', child: Text('Finalizado')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botão salvar
                    FilledButton.icon(
                      onPressed: _saveEvent,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditMode ? 'Salvar Alterações' : 'Criar Evento'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar data e hora de início
    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data e horário de início são obrigatórios')),
      );
      return;
    }

    // Validar data de término se informada
    if (_endDate != null && _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o horário de término')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combinar data e hora
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        // Validar que término é depois do início
        if (endDateTime.isBefore(startDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data de término deve ser após a data de início')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Preparar dados
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'event_type': _eventTypeController.text.trim().isEmpty
            ? null
            : _eventTypeController.text.trim(),
        'start_date': startDateTime.toIso8601String(),
        'end_date': endDateTime?.toIso8601String(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'max_capacity': _maxCapacityController.text.trim().isEmpty
            ? null
            : int.parse(_maxCapacityController.text.trim()),
        'requires_registration': _requiresRegistration,
        'status': _status,
      };

      if (_isEditMode) {
        // Atualizar evento existente
        await ref.read(eventsRepositoryProvider).updateEvent(widget.eventId!, data);

        // Invalidar providers
        ref.invalidate(eventByIdProvider(widget.eventId!));
      } else {
        // Criar novo evento
        await ref.read(eventsRepositoryProvider).createEvent(data);
      }

      // Invalidar listas
      ref.invalidate(allEventsProvider);
      ref.invalidate(activeEventsProvider);
      ref.invalidate(upcomingEventsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Evento atualizado com sucesso!'
                : 'Evento criado com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar evento: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
