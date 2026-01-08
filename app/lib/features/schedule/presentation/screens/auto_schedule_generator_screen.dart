import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:math' as math;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/file_download.dart';

import '../providers/schedule_provider.dart';
import '../../../events/domain/models/event.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../domain/auto_scheduler_service.dart';
import 'scale_preview_screen.dart';
import 'schedule_rules_preferences_screen.dart';
import '../../../permissions/providers/permissions_providers.dart';

class AutoScheduleGeneratorScreen extends ConsumerStatefulWidget {
  final String ministryId;
  const AutoScheduleGeneratorScreen({super.key, required this.ministryId});

  @override
  ConsumerState<AutoScheduleGeneratorScreen> createState() => _AutoScheduleGeneratorScreenState();
}

class _AutoScheduleGeneratorScreenState extends ConsumerState<AutoScheduleGeneratorScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 21));
  bool _isGenerating = false;

  // Evento conjunto
  final Set<String> _selectedMinistryIds = {};
  bool _jointByFunction = false;

  @override
  void initState() {
    super.initState();
    _selectedMinistryIds.add(widget.ministryId);
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'culto_normal':
        return Icons.church;
      case 'vigilia':
        return Icons.nightlight_round;
      case 'ensaio':
        return Icons.music_note;
      case 'reuniao_ministerio':
        return Icons.groups;
      case 'reuniao_externa':
        return Icons.meeting_room;
      case 'evento_conjunto':
        return Icons.layers;
      case 'lideranca_geral':
        return Icons.supervisor_account;
      case 'mutirao':
        return Icons.cleaning_services;
      default:
        return Icons.event;
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _start, end: _end.isBefore(_start) ? _start : _end),
      helpText: 'Selecione o período',
      cancelText: 'Cancelar',
      saveText: 'OK',
    );
    if (range == null) return;
    if (!mounted) return;
    setState(() {
      _start = range.start;
      _end = range.end;
    });
  }

  Future<void> _generate(List<Event> events) async {
    setState(() => _isGenerating = true);
    final service = AutoSchedulerService();
    try {
      for (final event in events) {
        final type = event.eventType ?? 'culto_normal';
        if (type == 'evento_conjunto') {
          if (_selectedMinistryIds.isEmpty) {
            _selectedMinistryIds.add(widget.ministryId);
          }
          await service.generateForEvent(
            ref: ref,
            event: event,
            ministryIds: _selectedMinistryIds.toList(),
            byFunction: _jointByFunction,
            overwriteExisting: _jointByFunction,
          );
        } else if (type == 'reuniao_ministerio' || type == 'reuniao_externa' || type == 'lideranca_geral' || type == 'mutirao') {
          await service.generateForEvent(
            ref: ref,
            event: event,
            ministryIds: [widget.ministryId],
            byFunction: false,
          );
        } else {
          await service.generateForEvent(
            ref: ref,
            event: event,
            ministryIds: [widget.ministryId],
            byFunction: true,
            overwriteExisting: true,
          );
        }
      }

      // Atualizar listas
      for (final e in events) {
        ref.invalidate(eventSchedulesProvider(e.id));
      }
      ref.invalidate(ministrySchedulesProvider(widget.ministryId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escala gerada com sucesso')),
        );
        _openScalePreview(events);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar escala: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openSendPreview(List<Event> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enviar Escala'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                final dow = DateFormat('EEEE', 'pt_BR').format(e.startDate);
                final day = DateFormat('dd/MM', 'pt_BR').format(e.startDate);
                final hour = DateFormat('HH:mm', 'pt_BR').format(e.startDate);
                final type = e.eventType ?? 'culto_normal';
                String msg;
                switch (type) {
                  case 'reuniao_ministerio':
                  case 'reuniao_externa':
                    msg = 'Reunião${e.isMandatory ? ' obrigatória' : ''} dia $day - $hour${e.location != null ? ' em ${e.location}' : ''}. Sua presença é essencial!';
                    break;
                  case 'evento_conjunto':
                    msg = 'Evento conjunto $day - $hour${e.location != null ? ' • ${e.location}' : ''}. Presenças/escala conforme funções definidas.';
                    break;
                  case 'lideranca_geral':
                    msg = 'Reunião de Liderança Geral $day - $hour. Presença de líderes e coordenadores.';
                    break;
                  case 'vigilia':
                    msg = 'Vigília $day - $hour • $dow. Escala por função (Louvor/Serviço).';
                    break;
                  case 'ensaio':
                    msg = 'Ensaio $day - $hour. Escala por função (instrumentos/voz).';
                    break;
                  default:
                    msg = 'Culto $day - $dow $hour. Escala por função (ex: Violão, Teclado, Back).';
                }
                return ListTile(
                  leading: Icon(_iconForType(e.eventType)),
                  title: Text(e.name),
                  subtitle: Text(msg),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        );
      },
    );
  }

  void _openScalePreview(List<Event> events) async {
    final ids = _selectedMinistryIds.isEmpty ? [widget.ministryId] : _selectedMinistryIds.toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScalePreviewScreen(
          ministryId: widget.ministryId,
          events: events,
          jointMinistryIds: ids,
          byFunction: true,
        ),
      ),
    );
  }

  void _openJointConfig() async {
    final ministries = await ref.read(ministriesRepositoryProvider).getActiveMinistries();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Evento Conjunto'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Quais ministérios vão servir neste evento?'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: ministries.length,
                    itemBuilder: (context, index) {
                      final m = ministries[index];
                      final selected = _selectedMinistryIds.contains(m.id);
                      return CheckboxListTile(
                        title: Text(m.name),
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedMinistryIds.add(m.id);
                            } else {
                              _selectedMinistryIds.remove(m.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Escalar por função'),
                  subtitle: const Text('Caso desativado, gera apenas presença'),
                  value: _jointByFunction,
                  onChanged: (v) => setState(() => _jointByFunction = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        );
      },
    );
  }

  void _openRecurringDialog() {
    String name = 'Culto';
    String type = 'culto_normal';
    TimeOfDay time = const TimeOfDay(hour: 19, minute: 0);
    final Set<int> weekdays = {DateTime.sunday};
    String? location;
    bool mandatory = false;
    String pattern = 'semanal'; // semanal | quinzenal | dias | mensal
    int intervalWeeks = 2; // para quinzenal ou N semanas
    int intervalDays = 15; // para a cada N dias
    int monthlyOrdinal = 1; // 1..4, 5 = último
    int monthlyWeekday = DateTime.sunday;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Eventos fixos semanais'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Nome do evento'),
                      controller: TextEditingController(text: name),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items: const [
                        DropdownMenuItem(value: 'culto_normal', child: Text('Culto')),
                        DropdownMenuItem(value: 'vigilia', child: Text('Vigília')),
                        DropdownMenuItem(value: 'ensaio', child: Text('Ensaio')),
                        DropdownMenuItem(value: 'reuniao_ministerio', child: Text('Reunião de Ministério')),
                        DropdownMenuItem(value: 'reuniao_externa', child: Text('Reunião Externa')),
                        DropdownMenuItem(value: 'evento_conjunto', child: Text('Evento Conjunto')),
                        DropdownMenuItem(value: 'lideranca_geral', child: Text('Liderança Geral')),
                        DropdownMenuItem(value: 'mutirao', child: Text('Mutirão')),
                      ],
                      onChanged: (v) => setLocalState(() => type = v ?? 'culto_normal'),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: pattern,
                      decoration: const InputDecoration(labelText: 'Padrão de recorrência'),
                      items: const [
                        DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                        DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal (mesmo dia)')),
                        DropdownMenuItem(value: 'dias', child: Text('A cada N dias')),
                        DropdownMenuItem(value: 'mensal', child: Text('Mensal (Nº do domingo)')),
                      ],
                      onChanged: (v) => setLocalState(() => pattern = v ?? 'semanal'),
                    ),
                    const SizedBox(height: 12),

                    if (pattern == 'quinzenal' || pattern == 'semanal')
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: intervalWeeks,
                              decoration: const InputDecoration(labelText: 'Intervalo (semanas)'),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 semana')),
                                DropdownMenuItem(value: 2, child: Text('2 semanas')),
                                DropdownMenuItem(value: 3, child: Text('3 semanas')),
                                DropdownMenuItem(value: 4, child: Text('4 semanas')),
                              ],
                              onChanged: (v) => setLocalState(() => intervalWeeks = v ?? 2),
                            ),
                          ),
                        ],
                      ),

                    if (pattern == 'dias')
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: intervalDays.toString(),
                              decoration: const InputDecoration(labelText: 'Intervalo (dias)'),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n > 0) setLocalState(() => intervalDays = n);
                              },
                            ),
                          ),
                        ],
                      ),

                    if (pattern == 'mensal')
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: monthlyOrdinal,
                              decoration: const InputDecoration(labelText: 'Nº do domingo no mês'),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1º')),
                                DropdownMenuItem(value: 2, child: Text('2º')),
                                DropdownMenuItem(value: 3, child: Text('3º')),
                                DropdownMenuItem(value: 4, child: Text('4º')),
                                DropdownMenuItem(value: 5, child: Text('Último')),
                              ],
                              onChanged: (v) => setLocalState(() => monthlyOrdinal = v ?? 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: monthlyWeekday,
                              decoration: const InputDecoration(labelText: 'Dia da semana'),
                              items: const [
                                DropdownMenuItem(value: DateTime.sunday, child: Text('Domingo')),
                                DropdownMenuItem(value: DateTime.monday, child: Text('Segunda')),
                                DropdownMenuItem(value: DateTime.tuesday, child: Text('Terça')),
                                DropdownMenuItem(value: DateTime.wednesday, child: Text('Quarta')),
                                DropdownMenuItem(value: DateTime.thursday, child: Text('Quinta')),
                                DropdownMenuItem(value: DateTime.friday, child: Text('Sexta')),
                                DropdownMenuItem(value: DateTime.saturday, child: Text('Sábado')),
                              ],
                              onChanged: (v) => setLocalState(() => monthlyWeekday = v ?? DateTime.sunday),
                            ),
                          ),
                        ],
                      ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Local (opcional)'),
                      controller: TextEditingController(text: location ?? ''),
                      onChanged: (v) => location = v.isEmpty ? null : v,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Horário'),
                      subtitle: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: time);
                        if (picked != null) {
                          setLocalState(() => time = picked);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Dias da semana', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in [1, 2, 3, 4, 5, 6, 7])
                          ChoiceChip(
                            label: Text(_weekdayLabel(d)),
                            selected: weekdays.contains(d),
                            onSelected: (sel) {
                              setLocalState(() {
                                if (sel) {
                                  weekdays.add(d);
                                } else {
                                  weekdays.remove(d);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Evento obrigatório'),
                      value: mandatory,
                      onChanged: (v) => setLocalState(() => mandatory = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.repeat),
                  label: const Text('Gerar eventos'),
                  onPressed: () async {
                    final repo = ref.read(eventsRepositoryProvider);
                    final created = <Event>[];
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final from = DateTime(_start.year, _start.month, _start.day);
                    final until = DateTime(_end.year, _end.month, _end.day, 23, 59);

                    if (pattern == 'semanal') {
                      DateTime cursor = from;
                      while (!cursor.isAfter(until)) {
                        if (weekdays.contains(cursor.weekday)) {
                          if (_matchesWeekInterval(from, cursor, intervalWeeks)) {
                            final startDateTime = DateTime(cursor.year, cursor.month, cursor.day, time.hour, time.minute);
                            final data = {
                              'name': name,
                              'event_type': type,
                              'start_date': startDateTime.toIso8601String(),
                              'location': location,
                              'requires_registration': false,
                              'is_mandatory': mandatory,
                              'status': 'published',
                            };
                            try {
                              final ev = await repo.createEvent(data);
                              created.add(ev);
                            } catch (_) {}
                          }
                        }
                        cursor = cursor.add(const Duration(days: 1));
                      }
                    } else if (pattern == 'quinzenal') {
                      final first = _firstMatchOnOrAfter(from, weekdays);
                      if (first != null) {
                        DateTime cursor = DateTime(first.year, first.month, first.day, time.hour, time.minute);
                        while (!cursor.isAfter(until)) {
                          final data = {
                            'name': name,
                            'event_type': type,
                            'start_date': cursor.toIso8601String(),
                            'location': location,
                            'requires_registration': false,
                            'is_mandatory': mandatory,
                            'status': 'published',
                          };
                          try {
                            final ev = await repo.createEvent(data);
                            created.add(ev);
                          } catch (_) {}
                          cursor = cursor.add(Duration(days: 7 * intervalWeeks)); // 2 semanas por padrão
                        }
                      }
                    } else if (pattern == 'dias') {
                      DateTime cursor = from;
                      while (!cursor.isAfter(until)) {
                        final startDateTime = DateTime(cursor.year, cursor.month, cursor.day, time.hour, time.minute);
                        final data = {
                          'name': name,
                          'event_type': type,
                          'start_date': startDateTime.toIso8601String(),
                          'location': location,
                          'requires_registration': false,
                          'is_mandatory': mandatory,
                          'status': 'published',
                        };
                        try {
                          final ev = await repo.createEvent(data);
                          created.add(ev);
                        } catch (_) {}
                        cursor = cursor.add(Duration(days: intervalDays));
                      }
                    } else if (pattern == 'mensal') {
                      DateTime monthCursor = DateTime(from.year, from.month, 1);
                      while (!monthCursor.isAfter(until)) {
                        final occurrence = monthlyOrdinal == 5
                            ? _lastWeekdayOfMonth(monthCursor.year, monthCursor.month, monthlyWeekday)
                            : _nthWeekdayOfMonth(monthCursor.year, monthCursor.month, monthlyWeekday, monthlyOrdinal);
                        if (occurrence != null && !occurrence.isBefore(from) && !occurrence.isAfter(until)) {
                          final startDateTime = DateTime(occurrence.year, occurrence.month, occurrence.day, time.hour, time.minute);
                          final data = {
                            'name': name,
                            'event_type': type,
                            'start_date': startDateTime.toIso8601String(),
                            'location': location,
                            'requires_registration': false,
                            'is_mandatory': mandatory,
                            'status': 'published',
                          };
                          try {
                            final ev = await repo.createEvent(data);
                            created.add(ev);
                          } catch (_) {}
                        }
                        monthCursor = DateTime(monthCursor.year, monthCursor.month + 1, 1);
                      }
                    }
                    if (!mounted) return;
                    navigator.pop();
                    setState(() {});
                    messenger.showSnackBar(
                      SnackBar(content: Text('Gerados ${created.length} eventos fixos')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
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

  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    DateTime date = DateTime(year, month, 1);
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    date = date.add(Duration(days: (n - 1) * 7));
    return date.month == month ? date : null;
  }

  DateTime? _lastWeekdayOfMonth(int year, int month, int weekday) {
    DateTime date = DateTime(year, month + 1, 0); // último dia do mês
    while (date.weekday != weekday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerador de Escala Automática'),
        actions: [
          FutureBuilder<int>(
            future: _countActiveRules(widget.ministryId),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScheduleRulesPreferencesScreen(ministryId: widget.ministryId),
                    ),
                  ),
                  icon: const Icon(Icons.rule),
                  label: Text(count > 0 ? 'Regras ($count)' : 'Regras'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_input_component),
            onPressed: _openJointConfig,
            tooltip: 'Evento conjunto',
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            onPressed: _openRecurringDialog,
            tooltip: 'Eventos fixos',
          ),
        ],
      ),
      body: FutureBuilder<List<Event>>(
        future: repo.getEventsByDateRange(_start, _end),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.date_range),
                        title: const Text('Período'),
                        subtitle: Text('${DateFormat('dd/MM').format(_start)} → ${DateFormat('dd/MM').format(_end)}'),
                        onTap: _pickRange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isGenerating || events.isEmpty ? null : () => _generate(events),
                      icon: _isGenerating ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                      label: const Text('GERAR ESCALA'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: events.isEmpty ? null : () => _openSendPreview(events),
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar Escala'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: events.isEmpty ? null : () => _openScalePreview(events),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Pré-visualizar/Editar'),
                    ),
                  ],
                ),
                  ],
                ),
              ),
  Expanded(
    child: ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];
        final icon = _iconForType(e.eventType);
        final dateText = DateFormat('EEE, dd/MM • HH:mm', 'pt_BR').format(e.startDate);
        final schedulesAsync = ref.watch(eventSchedulesProvider(e.id));
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            leading: Icon(icon, color: Colors.blue),
            title: Text(e.name),
            subtitle: Text('${e.eventType ?? 'Evento'} • $dateText'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              schedulesAsync.when(
                data: (schedules) {
                  if (schedules.isEmpty) {
                    return Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Sem escala salva para este evento')),
                        TextButton.icon(
                          onPressed: () => _openScalePreview([e]),
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar Escala'),
                        ),
                      ],
                    );
                  }
                  final groupedUsers = <String, List<Map<String, String>>>{};
                  final Set<String> uniqueUserIds = {};
                  for (final s in schedules) {
                    final f = s.notes ?? 'Presença';
                    final uid = s.memberId;
                    final name = s.memberName;
                    groupedUsers.putIfAbsent(f, () => []).add({'id': uid, 'name': name});
                    uniqueUserIds.add(uid);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          for (final entry in groupedUsers.entries)
                            Chip(
                              label: Text(
                                '${entry.key}: ${entry.value.map((m) => m['name'] ?? '').where((s) => s.isNotEmpty).join(', ')}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final doc = pw.Document();
                              doc.addPage(
                                pw.Page(
                                  build: (context) {
                                    // Paleta de cores e mapeamento por usuário (consistente por userId, ajusta conflitos locais)
                                    final palette = <PdfColor>[
                                      PdfColors.red,
                                      PdfColors.blue,
                                      PdfColors.green,
                                      PdfColors.orange,
                                      PdfColors.purple,
                                      PdfColors.cyan,
                                      PdfColors.lime,
                                      PdfColors.pink,
                                      PdfColors.teal,
                                      PdfColors.amber,
                                      PdfColors.indigo,
                                      PdfColors.brown,
                                      PdfColors.deepOrange,
                                      PdfColors.lightBlue,
                                      PdfColors.deepPurple,
                                      PdfColors.lightGreen,
                                    ];
                                    int idxFor(String s) {
                                      int h = 0;
                                      for (final c in s.codeUnits) { h = (h * 31 + c) & 0x7fffffff; }
                                      return h % palette.length;
                                    }
                                    final used = <int>{};
                                    final colorForUser = <String, PdfColor>{};
                                    for (final uid in uniqueUserIds) {
                                      int i = idxFor(uid);
                                      int loops = 0;
                                      while (used.contains(i) && loops < palette.length) { i = (i + 1) % palette.length; loops++; }
                                      used.add(i);
                                      colorForUser[uid] = palette[i];
                                    }

                                    final funcs = groupedUsers.keys.toList();
                                    funcs.sort();

                                    String dowAbbrevPt(DateTime d) {
                                      const map = {
                                        DateTime.monday: 'Seg',
                                        DateTime.tuesday: 'Ter',
                                        DateTime.wednesday: 'Qua',
                                        DateTime.thursday: 'Qui',
                                        DateTime.friday: 'Sex',
                                        DateTime.saturday: 'Sáb',
                                        DateTime.sunday: 'Dom',
                                      };
                                      return map[d.weekday] ?? '';
                                    }

                                    String labelForFunc(String f) {
                                      final lc = f.toLowerCase();
                                      if (lc == 'ministrante') return 'Ministrante';
                                      if (lc == 'tecnico de som' || lc == 'técnico de som') return 'Técnico de som';
                                      return f.toUpperCase();
                                    }

                                    double fontFor(String text, double width, {int maxLines = 1}) {
                                      final lines = text.split('\n');
                                      double best = 12.0;
                                      for (final line in lines) {
                                        final len = line.trim().isEmpty ? 1 : line.trim().length;
                                        final fs = width / (len * 0.6);
                                        best = math.min(best, fs);
                                      }
                                      if (best < 8.0) return 8.0;
                                      if (best > 12.0) return 12.0;
                                      return best;
                                    }

                                    final pageW = context.page.pageFormat.width;
                                    final dataInnerW = 60.0 - 8.0;
                                    final diaInnerW = 50.0 - 8.0;
                                    final remainingW = pageW - 60.0 - 50.0;
                                    final funcWidth = remainingW / (funcs.isEmpty ? 1 : funcs.length);
                                    final funcInnerW = funcWidth - 8.0;
                                    double headerFontSize = 12.0;
                                    headerFontSize = math.min(headerFontSize, fontFor('DATA', dataInnerW));
                                    headerFontSize = math.min(headerFontSize, fontFor('DIA', diaInnerW));
                                    for (final f in funcs) {
                                      headerFontSize = math.min(headerFontSize, fontFor(labelForFunc(f), funcInnerW, maxLines: 1));
                                    }

                                    pw.Widget chip(String uid, String name) {
                                      final col = colorForUser[uid] ?? PdfColors.grey;
                                      return pw.Container(
                                        margin: const pw.EdgeInsets.all(2),
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: pw.BoxDecoration(
                                          color: col,
                                          borderRadius: pw.BorderRadius.circular(3),
                                        ),
                                        child: pw.FittedBox(
                                          fit: pw.BoxFit.scaleDown,
                                          child: pw.Text(
                                            name,
                                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                                            maxLines: 1,
                                            overflow: pw.TextOverflow.clip,
                                          ),
                                        ),
                                      );
                                    }

                                    return pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text(e.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                                            pw.Text(DateFormat('yyyy').format(e.startDate), style: pw.TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                        pw.SizedBox(height: 6),
                                        pw.Text(
                                          '${dowAbbrevPt(e.startDate)}, ${DateFormat('dd/MM').format(e.startDate)} - ${DateFormat('HH:mm').format(e.startDate)}',
                                        ),
                                        pw.SizedBox(height: 12),
                                        pw.Table(
                                          border: pw.TableBorder.all(),
                                          columnWidths: {
                                            0: const pw.FixedColumnWidth(60),
                                            1: const pw.FixedColumnWidth(50),
                                            for (int i = 0; i < funcs.length; i++) 2 + i: pw.FixedColumnWidth(funcWidth),
                                          },
                                          children: [
                                            // Cabeçalho
                                            pw.TableRow(
                                              decoration: pw.BoxDecoration(color: PdfColors.black),
                                              children: [
                                                pw.Padding(
                                                  padding: const pw.EdgeInsets.all(4),
                                                  child: pw.Align(
                                                    alignment: pw.Alignment.center,
                                                    child: pw.Text('DATA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize), maxLines: 1, textAlign: pw.TextAlign.center),
                                                  ),
                                                ),
                                                pw.Padding(
                                                  padding: const pw.EdgeInsets.all(4),
                                                  child: pw.Align(
                                                    alignment: pw.Alignment.center,
                                                    child: pw.Text('DIA', style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize), maxLines: 1, textAlign: pw.TextAlign.center),
                                                  ),
                                                ),
                                                for (final f in funcs)
                                                  pw.Padding(
                                                    padding: const pw.EdgeInsets.all(4),
                                                    child: pw.Align(
                                                      alignment: pw.Alignment.center,
                                                      child: pw.Text(
                                                        labelForFunc(f),
                                                        style: pw.TextStyle(color: PdfColors.white, fontSize: headerFontSize),
                                                        maxLines: 1,
                                                        textAlign: pw.TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            // Linha do evento
                                            pw.TableRow(
                                              children: [
                                                pw.Padding(
                                                  padding: const pw.EdgeInsets.all(4),
                                                  child: pw.Align(
                                                    alignment: pw.Alignment.center,
                                                    child: pw.FittedBox(
                                                      fit: pw.BoxFit.scaleDown,
                                                      child: pw.Text(DateFormat('dd/MM').format(e.startDate), maxLines: 1, textAlign: pw.TextAlign.center),
                                                    ),
                                                  ),
                                                ),
                                                pw.Padding(
                                                  padding: const pw.EdgeInsets.all(4),
                                                  child: pw.Align(
                                                    alignment: pw.Alignment.center,
                                                    child: pw.FittedBox(
                                                      fit: pw.BoxFit.scaleDown,
                                                      child: pw.Text(dowAbbrevPt(e.startDate), maxLines: 1, textAlign: pw.TextAlign.center),
                                                    ),
                                                  ),
                                                ),
                                                for (final f in funcs)
                                                  pw.Padding(
                                                    padding: const pw.EdgeInsets.all(4),
                                                    child: pw.Wrap(
                                                      spacing: 2,
                                                      runSpacing: 2,
                                                      children: [
                                                        for (final u in groupedUsers[f] ?? const <Map<String, String>>[])
                                                          chip(u['id'] ?? '', u['name'] ?? ''),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                              final bytes = await doc.save();
                              if (kIsWeb) {
                                downloadFile('escala_${e.id}.pdf', bytes);
                              } else {
                                await Printing.sharePdf(bytes: bytes, filename: 'escala_${e.id}.pdf').catchError((_) async {
                                  await Printing.layoutPdf(onLayout: (format) async => bytes);
                                  return true;
                                });
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Exportar PDF'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openSendPreview([e]),
                            icon: const Icon(Icons.send),
                            label: const Text('Enviar'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _openScalePreview([e]),
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar Escala'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, st) => Text('Erro ao carregar escala: $err'),
              ),
            ],
          ),
        );
      },
    ),
  ),
            ],
          );
        },
      ),
    );
  }

  Future<int> _countActiveRules(String ministryId) async {
    try {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
      if (contexts.isEmpty) return 0;
      final meta = Map<String, dynamic>.from(contexts.first.metadata ?? {});
      final rules = Map<String, dynamic>.from(meta['schedule_rules'] ?? {});
      int total = 0;
      {
        final list = List<dynamic>.from(rules['prohibited_combinations'] ?? const []);
        final seen = <String>{};
        for (final e in list) {
          if (e is Map) {
            final a = e['a']?.toString() ?? '';
            final b = e['b']?.toString() ?? '';
            if (a.isEmpty || b.isEmpty) continue;
            final key = (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
            seen.add(key);
          }
        }
        total += seen.length;
      }
      {
        final list = List<dynamic>.from(rules['preferred_combinations'] ?? const []);
        final seen = <String>{};
        for (final e in list) {
          if (e is Map) {
            final a = e['a']?.toString() ?? '';
            final b = e['b']?.toString() ?? '';
            if (a.isEmpty || b.isEmpty) continue;
            final key = (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
            seen.add(key);
          }
        }
        total += seen.length;
      }
      {
        final mp = Map<String, dynamic>.from(rules['member_priorities'] ?? {});
        total += mp.length;
      }
      {
        final leaders = Map<String, dynamic>.from(rules['leaders_by_function'] ?? {});
        int count = 0;
        leaders.forEach((f, rowDyn) {
          final row = Map<String, dynamic>.from(rowDyn ?? {});
          final leader = (row['leader']?.toString() ?? '');
          final subs = List<String>.from(row['subs'] ?? const []);
          if (leader.isNotEmpty || subs.isNotEmpty) count++;
        });
        total += count;
      }
      {
        final gr = Map<String, dynamic>.from(rules['general_rules'] ?? {});
        gr.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
        total += gr.keys.length;
      }
      {
        final list = List<dynamic>.from(rules['blocks'] ?? const []);
        final seen = <String>{};
        for (final b in list) {
          if (b is Map) {
            final uid = b['user_id']?.toString() ?? '';
            final start = b['start']?.toString() ?? '';
            final end = b['end']?.toString() ?? '';
            final type = b['type']?.toString() ?? '';
            final reason = b['reason']?.toString() ?? '';
            if (uid.isEmpty) continue;
            seen.add('$uid|$start|$end|$type|$reason');
          }
        }
        total += seen.length;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
