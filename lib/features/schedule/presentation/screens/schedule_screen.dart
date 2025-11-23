import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/schedule_provider.dart';
import '../providers/holidays_provider.dart';
import '../../../events/domain/models/event.dart';
import '../../domain/models/holiday.dart';
import '../../../church_schedule/domain/models/church_schedule.dart';
import '../../../church_schedule/presentation/providers/church_schedule_provider.dart';

/// Tela de Agenda
class ScheduleScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const ScheduleScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsOfMonthProvider(_focusedDay));
    final churchSchedulesAsync = ref.watch(churchSchedulesOfMonthProvider(_focusedDay));
    final holidays = ref.watch(holidaysOfMonthProvider(_focusedDay));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Voltar para a tela Home ao invés de sair do app
        context.go('/home');
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Agenda'),
                centerTitle: true,
              )
            : null,
        body: Column(
        children: [
          // Calendário
          eventsAsync.when(
            data: (events) {
              return churchSchedulesAsync.when(
                data: (churchSchedules) => _buildCalendar(events, churchSchedules, holidays),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Erro ao carregar agendas: $error',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar eventos: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Lista de eventos do dia selecionado
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      ),
    );
  }

  /// Constrói o calendário
  Widget _buildCalendar(List<Event> events, List<ChurchSchedule> churchSchedules, List<Holiday> holidays) {
    return TableCalendar(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      locale: 'pt_BR',
      
      // Eventos
      eventLoader: (day) {
        return _getEventsForDay(day, events, churchSchedules, holidays);
      },

      // Callbacks
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        
        // Mostrar bottom sheet com detalhes do dia
        _showDayDetailsBottomSheet(selectedDay);
      },
      
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },

      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },

      // Customização de header
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          return '${DateFormat.MMM(locale).format(date).toUpperCase()}. ${date.year}';
        },
        leftChevronIcon: const Icon(Icons.chevron_left),
        rightChevronIcon: const Icon(Icons.chevron_right),
        headerPadding: const EdgeInsets.symmetric(vertical: 16),
      ),

      // Callback para clicar no título (abrir seletor de mês/ano)
      onHeaderTapped: (focusedDay) {
        _showMonthYearPicker();
      },

      // Customização de dias da semana
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        weekendStyle: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Customização de células
      calendarStyle: CalendarStyle(
        // Dia de hoje
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),

        // Dia selecionado
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),

        // Domingos
        weekendTextStyle: TextStyle(
          color: Colors.red.shade700,
        ),

        // Marcadores de eventos
        markerDecoration: BoxDecoration(
          color: Colors.green.shade700,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        markerSize: 6,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
      ),

      // Builders customizados
      calendarBuilders: CalendarBuilders(
        // Customizar marcadores
        markerBuilder: (context, day, dayEvents) {
          if (dayEvents.isEmpty) return const SizedBox.shrink();

          final hasHoliday = _hasHolidayOnDay(day, holidays);
          final hasEvent = _hasEventOnDay(day, events);
          final hasChurchSchedule = _hasChurchScheduleOnDay(day, churchSchedules);

          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasHoliday)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasEvent)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasChurchSchedule)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Retorna os eventos de um dia (para o eventLoader)
  List<dynamic> _getEventsForDay(DateTime day, List<Event> events, List<ChurchSchedule> churchSchedules, List<Holiday> holidays) {
    final dayEvents = <dynamic>[];

    // Adicionar feriados
    for (final holiday in holidays) {
      if (holiday.isOnDate(day)) {
        dayEvents.add(holiday);
      }
    }

    // Adicionar eventos
    for (final event in events) {
      if (isSameDay(event.startDate, day)) {
        dayEvents.add(event);
      }
    }

    // Adicionar agendas da igreja
    for (final schedule in churchSchedules) {
      if (isSameDay(schedule.startDatetime, day)) {
        dayEvents.add(schedule);
      }
    }

    return dayEvents;
  }

  /// Verifica se há feriado no dia
  bool _hasHolidayOnDay(DateTime day, List<Holiday> holidays) {
    return holidays.any((holiday) => holiday.isOnDate(day));
  }

  /// Verifica se há evento no dia
  bool _hasEventOnDay(DateTime day, List<Event> events) {
    return events.any((event) => isSameDay(event.startDate, day));
  }

  /// Verifica se há agenda da igreja no dia
  bool _hasChurchScheduleOnDay(DateTime day, List<ChurchSchedule> churchSchedules) {
    return churchSchedules.any((schedule) => isSameDay(schedule.startDatetime, day));
  }

  /// Lista de eventos do dia selecionado
  Widget _buildEventsList() {
    final eventsAsync = ref.watch(eventsOfDateProvider(_selectedDay));
    final churchSchedulesAsync = ref.watch(churchSchedulesOfDateProvider(_selectedDay));
    final holidays = ref.watch(holidaysOfDateProvider(_selectedDay));

    return eventsAsync.when(
      data: (events) {
        return churchSchedulesAsync.when(
          data: (churchSchedules) {
            if (events.isEmpty && churchSchedules.isEmpty && holidays.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum evento neste dia',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Feriados
                ...holidays.map((holiday) => _buildHolidayCard(holiday)),

                // Eventos
                ...events.map((event) => _buildEventCard(event)),

                // Agendas da Igreja
                ...churchSchedules.map((schedule) => _buildChurchScheduleCard(schedule)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Erro ao carregar agendas: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Erro ao carregar eventos: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  /// Card de feriado
  Widget _buildHolidayCard(Holiday holiday) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.amber.shade700,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Todo o dia',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de evento
  Widget _buildEventCard(Event event) {
    final timeFormat = DateFormat.Hm();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade700, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navegar para detalhes do evento
          context.push('/events/${event.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.event,
                color: Colors.green.shade700,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(event.startDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.green.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de agenda da igreja
  Widget _buildChurchScheduleCard(ChurchSchedule schedule) {
    final timeFormat = DateFormat.Hm();
    final scheduleType = ScheduleType.fromValue(schedule.scheduleType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.blue.shade700,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scheduleType.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(schedule.startDatetime)} - ${timeFormat.format(schedule.endDatetime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                  if (schedule.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule.location!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostrar bottom sheet com detalhes do dia
  void _showDayDetailsBottomSheet(DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailsBottomSheet(day: day),
    );
  }

  /// Mostra bottom sheet para selecionar mês e ano
  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MonthYearPickerBottomSheet(
        initialDate: _focusedDay,
        onDateSelected: (selectedDate) {
          setState(() {
            _focusedDay = selectedDate;
            _selectedDay = selectedDate;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // Variável para armazenar eventos (necessária para o markerBuilder)
  List<Event> events = [];
}

// =====================================================
// BOTTOM SHEET: SELETOR DE MÊS E ANO
// =====================================================

class _MonthYearPickerBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _MonthYearPickerBottomSheet({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_MonthYearPickerBottomSheet> createState() => _MonthYearPickerBottomSheetState();
}

class _MonthYearPickerBottomSheetState extends State<_MonthYearPickerBottomSheet> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            'Selecionar Mês e Ano',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Seletor de Ano
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    selectedYear--;
                  });
                },
              ),
              const SizedBox(width: 16),
              Text(
                selectedYear.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    selectedYear++;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Grid de Meses
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = month == selectedMonth && selectedYear == widget.initialDate.year;
              final isCurrentMonth = month == now.month && selectedYear == now.year;

              return InkWell(
                onTap: () {
                  final selectedDate = DateTime(selectedYear, month, 1);
                  widget.onDateSelected(selectedDate);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? Theme.of(context).colorScheme.primary
                        : isSelected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.MMM('pt_BR').format(DateTime(2000, month)).toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected || isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentMonth
                                ? Colors.white
                                : isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Botões
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botão "Hoje"
              OutlinedButton.icon(
                onPressed: () {
                  widget.onDateSelected(now);
                },
                icon: const Icon(Icons.today),
                label: const Text('HOJE'),
              ),
              // Botão "Fechar"
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('FECHAR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// BOTTOM SHEET: DETALHES DO DIA
// =====================================================

/// Bottom Sheet com detalhes do dia
class _DayDetailsBottomSheet extends ConsumerWidget {
  final DateTime day;

  const _DayDetailsBottomSheet({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsOfDateProvider(day));
    final churchSchedulesAsync = ref.watch(churchSchedulesOfDateProvider(day));
    final holidays = ref.watch(holidaysOfDateProvider(day));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day} ${_getWeekdayName(day.weekday)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d \'de\' MMM.', 'pt_BR').format(day),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Lista de eventos
          Flexible(
            child: eventsAsync.when(
              data: (events) {
                return churchSchedulesAsync.when(
                  data: (churchSchedules) {
                    if (events.isEmpty && holidays.isEmpty && churchSchedules.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum evento neste dia',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      children: [
                        // Feriados
                        ...holidays.map((holiday) => _buildHolidayCard(context, holiday)),

                        // Eventos
                        ...events.map((event) => _buildEventCard(context, event)),

                        // Agendas da Igreja
                        ...churchSchedules.map((schedule) => _buildChurchScheduleCard(context, schedule)),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao carregar agendas: $error',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Erro ao carregar eventos: $error',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o nome do dia da semana
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'segunda-feira';
      case 2:
        return 'terça-feira';
      case 3:
        return 'quarta-feira';
      case 4:
        return 'quinta-feira';
      case 5:
        return 'sexta-feira';
      case 6:
        return 'sábado';
      case 7:
        return 'domingo';
      default:
        return '';
    }
  }

  /// Card de feriado
  Widget _buildHolidayCard(BuildContext context, Holiday holiday) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.amber.shade700,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Todo o dia',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de evento
  Widget _buildEventCard(BuildContext context, Event event) {
    final timeFormat = DateFormat.Hm();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade700, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Fechar o bottom sheet
          Navigator.pop(context);
          // Navegar para detalhes do evento
          context.push('/events/${event.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.event,
                color: Colors.green.shade700,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(event.startDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.green.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de agenda da igreja
  Widget _buildChurchScheduleCard(BuildContext context, ChurchSchedule schedule) {
    final timeFormat = DateFormat.Hm();
    final scheduleType = ScheduleType.fromValue(schedule.scheduleType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.blue.shade700,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scheduleType.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(schedule.startDatetime)} - ${timeFormat.format(schedule.endDatetime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                  if (schedule.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule.location!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

