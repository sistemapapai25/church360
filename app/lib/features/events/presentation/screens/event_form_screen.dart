import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../providers/events_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';

/// Tela de formulário de evento (criar/editar)
class EventFormScreen extends ConsumerStatefulWidget {
  final String? eventId; // null = criar, não-null = editar

  const EventFormScreen({super.key, this.eventId});

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
  bool _isMandatory = false;
  String _status = 'draft';
  String? _imageUrl;

  List<Map<String, String>> _eventTypeOptions = [];
  String? _managingError;

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isFixed = false;
  String _fixedPatternGroup = 'semanal'; // 'semanal' | 'variavel'
  String _variableType = 'quinzenal'; // 'quinzenal' | 'dias' | 'unico'
  final Set<int> _fixedWeekdays = {DateTime.sunday};
  int _intervalWeeks = 2;
  int? _variableMonthlyOrdinal;
  int? _diasBase;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;
    if (_isEditMode) {
      _loadEvent();
    }
    _loadEventTypes();
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

  Future<void> _loadEventTypes() async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final catalog = await repo.getEventTypesCatalog();
      if (catalog.isNotEmpty) {
        setState(() => _eventTypeOptions = catalog);
        return;
      }
    } catch (_) {}
    final defaults = [
      {'code': 'culto_normal', 'label': 'Culto Normal / Ceia'},
      {'code': 'ensaio', 'label': 'Ensaio'},
      {
        'code': 'reuniao_ministerio',
        'label': 'Reunião do Ministério (interna)',
      },
      {'code': 'reuniao_externa', 'label': 'Reunião Externa / Célula'},
      {
        'code': 'evento_conjunto',
        'label': 'Evento Conjunto (vários ministérios)',
      },
      {'code': 'lideranca_geral', 'label': 'Reunião de Liderança Geral'},
      {'code': 'vigilia', 'label': 'Vigília ou Culto Especial'},
      {'code': 'mutirao', 'label': 'Limpeza / Mutirão / Manutenção'},
    ];
    setState(() => _eventTypeOptions = defaults);
  }

  Future<String?> _manageEventTypes() async {
    final newLabelController = TextEditingController();
    String? addedCode;
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Gerenciar Tipos de Evento'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_managingError != null && _managingError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _managingError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newLabelController,
                            decoration: InputDecoration(
                              labelText: 'Nome exibido',
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final lbl = newLabelController.text.trim();
                            if (lbl.isEmpty) {
                              setStateDialog(
                                () => _managingError =
                                    'Informe um nome para o tipo.',
                              );
                              return;
                            }
                            final code = lbl.toLowerCase().replaceAll(' ', '_');
                            try {
                              final repo = ref.read(eventsRepositoryProvider);
                              await repo.upsertEventType(code, lbl);
                              await _loadEventTypes();
                              setStateDialog(() => _managingError = '');
                              addedCode = code;
                              newLabelController.clear();
                            } catch (e) {
                              final msg = e.toString();
                              if (msg.contains('code: 404')) {
                                final exists = _eventTypeOptions.any(
                                  (t) => t['code'] == code,
                                );
                                if (!exists) {
                                  _eventTypeOptions.add({
                                    'code': code,
                                    'label': lbl,
                                  });
                                }
                                setStateDialog(
                                  () => _managingError =
                                      'Catálogo não encontrado; incluído localmente (não persistido).',
                                );
                                addedCode = code;
                                newLabelController.clear();
                              } else {
                                setStateDialog(
                                  () => _managingError = 'Erro ao incluir: $e',
                                );
                              }
                            }
                          },
                          child: const Text('Incluir'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _eventTypeOptions.length,
                        itemBuilder: (context, index) {
                          final item = _eventTypeOptions[index];
                          final code = item['code']!;
                          final label = item['label'] ?? code;
                          return ListTile(
                            title: Text(label),
                            subtitle: Text(code),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final controller = TextEditingController(
                                      text: label,
                                    );
                                    final newLabel = await showDialog<String?>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Editar Tipo'),
                                          content: TextField(
                                            controller: controller,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, null),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                controller.text.trim(),
                                              ),
                                              child: const Text('Salvar'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (newLabel == null || newLabel.isEmpty) {
                                      return;
                                    }
                                    try {
                                      final repo = ref.read(
                                        eventsRepositoryProvider,
                                      );
                                      await repo.upsertEventType(
                                        code,
                                        newLabel,
                                      );
                                      await _loadEventTypes();
                                      setStateDialog(() => _managingError = '');
                                    } catch (e) {
                                      final msg = e.toString();
                                      if (msg.contains('code: 404')) {
                                        _eventTypeOptions = _eventTypeOptions
                                            .map(
                                              (t) => t['code'] == code
                                                  ? {
                                                      'code': code,
                                                      'label': newLabel,
                                                    }
                                                  : t,
                                            )
                                            .toList();
                                        setStateDialog(
                                          () => _managingError =
                                              'Catálogo não encontrado; alterado localmente (não persistido).',
                                        );
                                      } else {
                                        setStateDialog(
                                          () => _managingError =
                                              'Erro ao editar: $e',
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    try {
                                      final repo = ref.read(
                                        eventsRepositoryProvider,
                                      );
                                      final used = await repo
                                          .getEventsCountByType(code);
                                      if (used > 0) {
                                        setStateDialog(
                                          () => _managingError =
                                              'Tipo em uso por $used evento(s).',
                                        );
                                        return;
                                      }
                                      await repo.deleteEventType(code);
                                      await _loadEventTypes();
                                      setStateDialog(() => _managingError = '');
                                    } catch (e) {
                                      setStateDialog(
                                        () => _managingError =
                                            'Erro ao excluir: $e',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, addedCode),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);

    try {
      final event = await ref
          .read(eventsRepositoryProvider)
          .getEventById(widget.eventId!);

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
        _isMandatory = event.isMandatory;
        _status = event.status;
        _imageUrl = event.imageUrl;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar evento: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          _isEditMode ? 'Editar Evento' : 'Novo Evento',
          style: CommunityDesign.titleStyle(context),
        ),
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
                      decoration: InputDecoration(
                        labelText: 'Nome do Evento *',
                        prefixIcon: const Icon(Icons.event),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        prefixIcon: const Icon(Icons.description),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Upload de Imagem
                    ImageUploadWidget(
                      initialImageUrl: _imageUrl,
                      onImageUrlChanged: (url) {
                        setState(() {
                          _imageUrl = url;
                        });
                      },
                      storageBucket: 'event-images',
                      label: 'Imagem do Evento',
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey(
                              'evt-type-${_eventTypeController.text}',
                            ),
                            initialValue: _eventTypeController.text.isEmpty
                                ? null
                                : _eventTypeController.text,
                            decoration: InputDecoration(
                              labelText: 'Tipo de Evento',
                              prefixIcon: const Icon(Icons.category),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: const OutlineInputBorder(),
                            ),
                            items: _eventTypeOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e['code'],
                                    child: Text(e['label'] ?? e['code']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(
                                () => _eventTypeController.text = value ?? '',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created = await _manageEventTypes();
                            if (created != null && created.isNotEmpty) {
                              setState(
                                () => _eventTypeController.text = created,
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar tipo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Evento fixo'),
                      subtitle: const Text(
                        'Gera ocorrências automaticamente, sem data de início obrigatória',
                      ),
                      value: _isFixed,
                      onChanged: (v) {
                        setState(() => _isFixed = v);
                      },
                    ),
                    if (_isFixed) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _fixedPatternGroup,
                        decoration: InputDecoration(
                          labelText: 'Padrão',
                          prefixIcon: const Icon(Icons.repeat),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'semanal',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'variavel',
                            child: Text('Variável'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _fixedPatternGroup = v ?? 'semanal';
                          if (_fixedPatternGroup == 'variavel' &&
                              _intervalWeeks < 2) {
                            _intervalWeeks = 2;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_fixedPatternGroup == 'semanal') ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _intervalWeeks,
                                decoration: const InputDecoration(
                                  labelText: 'Intervalo (semanas)',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('1 semana'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('2 semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('3 semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('4 semanas'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _intervalWeeks = v ?? 2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Dias da semana',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in [
                              DateTime.sunday,
                              DateTime.monday,
                              DateTime.tuesday,
                              DateTime.wednesday,
                              DateTime.thursday,
                              DateTime.friday,
                              DateTime.saturday,
                            ])
                              ChoiceChip(
                                label: Text(_weekdayLabel(d)),
                                selected: _fixedWeekdays.contains(d),
                                onSelected: (sel) {
                                  setState(() {
                                    if (sel) {
                                      _fixedWeekdays.add(d);
                                    } else {
                                      _fixedWeekdays.remove(d);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      if (_fixedPatternGroup == 'variavel') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _variableType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo variável',
                            prefixIcon: Icon(Icons.tune),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'quinzenal',
                              child: Text('Quinzenal (mesmo dia)'),
                            ),
                            DropdownMenuItem(
                              value: 'dias',
                              child: Text('Por dias corridos'),
                            ),
                            DropdownMenuItem(
                              value: 'unico',
                              child: Text('Único (próxima ocorrência)'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _variableType = v ?? 'quinzenal';
                            if (_variableType == 'quinzenal' &&
                                _intervalWeeks < 2) {
                              _intervalWeeks = 2;
                            }
                            if (_variableType == 'dias') {
                              _fixedWeekdays.clear();
                              _diasBase = null;
                            }
                          }),
                        ),
                        const SizedBox(height: 8),
                        if (_variableType == 'quinzenal') ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _intervalWeeks,
                                  decoration: const InputDecoration(
                                    labelText: 'Intervalo (semanas)',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('2 semanas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('3 semanas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('4 semanas'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _intervalWeeks = v ?? 2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dia da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _fixedWeekdays.clear();
                                      if (sel) _fixedWeekdays.add(d);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        if (_variableType == 'dias') ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dias da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _handleDiasChip(d, sel);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        if (_variableType == 'unico') ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dia da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _fixedWeekdays.clear();
                                      if (sel) _fixedWeekdays.add(d);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _variableMonthlyOrdinal,
                          decoration: const InputDecoration(
                            labelText: 'Semana do mês',
                            prefixIcon: Icon(Icons.calendar_view_month),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1º')),
                            DropdownMenuItem(value: 2, child: Text('2º')),
                            DropdownMenuItem(value: 3, child: Text('3º')),
                            DropdownMenuItem(value: 4, child: Text('4º')),
                          ],
                          onChanged: (v) =>
                              setState(() => _variableMonthlyOrdinal = v),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // Data de início
                    if (!_isFixed)
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
                    if (!_isFixed) const SizedBox(height: 16),

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
                    if (!_isFixed)
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
                    if (!_isFixed) const SizedBox(height: 16),

                    // Horário de término
                    if (_endDate != null && !_isFixed)
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
                    if (_endDate != null && !_isFixed)
                      const SizedBox(height: 16),

                    // Local
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Local',
                        prefixIcon: Icon(Icons.location_on),
                        filled: true,
                        fillColor: Colors.white,
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
                        filled: true,
                        fillColor: Colors.white,
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
                      subtitle: const Text(
                        'Membros precisam se inscrever para participar',
                      ),
                      value: _requiresRegistration,
                      onChanged: (value) {
                        setState(() => _requiresRegistration = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Obrigatório
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Evento obrigatório'),
                      subtitle: const Text(
                        'Presença marcada como obrigatória para o tipo adequado',
                      ),
                      value: _isMandatory,
                      onChanged: (value) {
                        setState(() => _isMandatory = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Rascunho'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Publicado'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelado'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Finalizado'),
                        ),
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
                      label: Text(
                        _isEditMode ? 'Salvar Alterações' : 'Criar Evento',
                      ),
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

    // Validação de horário
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horário de início é obrigatório')),
      );
      return;
    }

    // Validar data de início apenas para evento não fixo
    if (!_isFixed && _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data de início é obrigatória para evento não fixo'),
        ),
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
      // Combinar data e hora (para não fixo)
      DateTime startDateTime = DateTime(
        (_startDate ?? DateTime.now()).year,
        (_startDate ?? DateTime.now()).month,
        (_startDate ?? DateTime.now()).day,
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
            const SnackBar(
              content: Text('Data de término deve ser após a data de início'),
            ),
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
        'is_mandatory': _isMandatory,
        'status': _status,
        'image_url': _imageUrl,
      };

      if (_isFixed) {
        if (_fixedWeekdays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecione ao menos um dia da semana'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final repo = ref.read(eventsRepositoryProvider);
        int count = 0;
        final from = DateTime.now();
        final until = DateTime(
          from.year + 1,
          from.month,
          from.day,
          23,
          59,
        ); // horizonte padrão: 12 meses

        if (_fixedPatternGroup == 'semanal') {
          DateTime cursor = DateTime(from.year, from.month, from.day);
          while (!cursor.isAfter(until)) {
            if (_fixedWeekdays.contains(cursor.weekday)) {
              if (_matchesWeekInterval(from, cursor, _intervalWeeks)) {
                final fixedStart = DateTime(
                  cursor.year,
                  cursor.month,
                  cursor.day,
                  _startTime!.hour,
                  _startTime!.minute,
                );
                final fixedData = Map<String, dynamic>.from(data);
                fixedData['start_date'] = fixedStart.toIso8601String();
                fixedData['end_date'] = null;
                fixedData['status'] = 'published';
                await repo.createEvent(fixedData);
                count++;
              }
            }
            cursor = cursor.add(const Duration(days: 1));
          }
        } else if (_fixedPatternGroup == 'variavel') {
          if (_variableType == 'quinzenal') {
            final first = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
            DateTime cursor = DateTime(
              first.year,
              first.month,
              first.day,
              _startTime!.hour,
              _startTime!.minute,
            );
            while (!cursor.isAfter(until)) {
              final fixedData = Map<String, dynamic>.from(data);
              fixedData['start_date'] = cursor.toIso8601String();
              fixedData['end_date'] = null;
              fixedData['status'] = 'published';
              await repo.createEvent(fixedData);
              count++;
              cursor = cursor.add(Duration(days: 7 * _intervalWeeks));
            }
          } else if (_variableType == 'dias') {
            final base = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
            DateTime cursor = DateTime(base.year, base.month, base.day);
            while (!cursor.isAfter(until)) {
              final weekdayOk = _fixedWeekdays.contains(cursor.weekday);
              final ordinalOk = _variableMonthlyOrdinal == null
                  ? true
                  : _isOrdinalOfMonth(cursor, _variableMonthlyOrdinal!);
              if (weekdayOk && ordinalOk) {
                final fixedStart = DateTime(
                  cursor.year,
                  cursor.month,
                  cursor.day,
                  _startTime!.hour,
                  _startTime!.minute,
                );
                final fixedData = Map<String, dynamic>.from(data);
                fixedData['start_date'] = fixedStart.toIso8601String();
                fixedData['end_date'] = null;
                fixedData['status'] = 'published';
                await repo.createEvent(fixedData);
                count++;
              }
              cursor = cursor.add(const Duration(days: 1));
            }
          } else if (_variableType == 'unico') {
            final first = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
            DateTime target = first;
            if (_variableMonthlyOrdinal != null) {
              DateTime monthCursor = DateTime(from.year, from.month, 1);
              for (int m = 0; m < 24; m++) {
                final wd = _fixedWeekdays.isEmpty
                    ? DateTime.sunday
                    : _fixedWeekdays.first;
                final occ = _nthWeekdayOfMonth(
                  monthCursor.year,
                  monthCursor.month,
                  wd,
                  _variableMonthlyOrdinal!,
                );
                if (occ != null && !occ.isBefore(from)) {
                  target = occ;
                  break;
                }
                monthCursor = DateTime(
                  monthCursor.year,
                  monthCursor.month + 1,
                  1,
                );
              }
            }
            final fixedStart = DateTime(
              target.year,
              target.month,
              target.day,
              _startTime!.hour,
              _startTime!.minute,
            );
            final fixedData = Map<String, dynamic>.from(data);
            fixedData['start_date'] = fixedStart.toIso8601String();
            fixedData['end_date'] = null;
            fixedData['status'] = 'published';
            await repo.createEvent(fixedData);
            count++;
          }
        }

        ref.invalidate(allEventsProvider);
        ref.invalidate(activeEventsProvider);
        ref.invalidate(upcomingEventsProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gerados $count eventos fixos')),
          );
        }
      } else {
        if (_isEditMode) {
          await ref
              .read(eventsRepositoryProvider)
              .updateEvent(widget.eventId!, data);
          ref.invalidate(eventByIdProvider(widget.eventId!));
        } else {
          await ref.read(eventsRepositoryProvider).createEvent(data);
        }

        ref.invalidate(allEventsProvider);
        ref.invalidate(activeEventsProvider);
        ref.invalidate(upcomingEventsProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'Evento atualizado com sucesso!'
                    : 'Evento criado com sucesso!',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar evento: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
      default:
        return 'Dom';
    }
  }

  bool _matchesWeekInterval(DateTime from, DateTime date, int interval) {
    final days = date.difference(from).inDays;
    final weeks = days ~/ 7;
    return weeks % interval == 0;
  }

  DateTime? _firstMatchOnOrAfter(DateTime start, Set<int> weekdays) {
    DateTime cursor = start;
    for (int i = 0; i < 7; i++) {
      if (weekdays.contains(cursor.weekday)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  bool _isOrdinalOfMonth(DateTime date, int ordinal) {
    final nth = _nthWeekdayOfMonth(
      date.year,
      date.month,
      date.weekday,
      ordinal,
    );
    return nth != null && nth.day == date.day;
  }

  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    DateTime date = DateTime(year, month, 1);
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    date = date.add(Duration(days: (n - 1) * 7));
    return date.month == month ? date : null;
  }

  void _handleDiasChip(int d, bool sel) {
    int next(int x) => x == 7 ? 1 : x + 1;
    if (sel) {
      if (_diasBase == null) {
        _diasBase = d;
        _fixedWeekdays
          ..clear()
          ..add(d);
        return;
      }
      int last = _diasBase!;
      while (_fixedWeekdays.contains(last)) {
        final n = next(last);
        if (_fixedWeekdays.contains(n)) {
          last = n;
        } else {
          break;
        }
      }
      final expected = next(last);
      if (d == expected) {
        _fixedWeekdays.add(d);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selecione ${_weekdayLabel(expected)}')),
        );
      }
    } else {
      if (_diasBase == null) return;
      int last = _diasBase!;
      while (_fixedWeekdays.contains(last)) {
        final n = next(last);
        if (_fixedWeekdays.contains(n)) {
          last = n;
        } else {
          break;
        }
      }
      if (d == _diasBase) {
        if (d == last) {
          _fixedWeekdays.remove(d);
          if (_fixedWeekdays.isEmpty) _diasBase = null;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Remova primeiro ${_weekdayLabel(last)}')),
          );
        }
      } else if (d == last) {
        _fixedWeekdays.remove(d);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remova primeiro ${_weekdayLabel(last)}')),
        );
      }
    }
  }

  // removido: última semana do mês não é necessária
}
