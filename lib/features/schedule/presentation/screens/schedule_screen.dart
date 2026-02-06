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
import '../../../../core/design/community_design.dart';

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
    final churchSchedulesAsync = ref.watch(
      churchSchedulesOfMonthProvider(_focusedDay),
    );
    final holidays = ref.watch(holidaysOfMonthProvider(_focusedDay));

    final content = SingleChildScrollView(
      child: Column(
        children: [
          // Calendário
          eventsAsync.when(
            data: (events) {
              return churchSchedulesAsync.when(
                data: (churchSchedules) =>
                    _buildCalendar(events, churchSchedules, holidays),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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

          // Lista de eventos do dia selecionado
          _buildEventsList(),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Voltar para a tela Home ao invés de sair do app
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(
          toolbarHeight: 60,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          backgroundColor: const Color(0xFFF5F9FD),
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Agenda', style: CommunityDesign.titleStyle(context)),
                  Text(
                    'Sua programação',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: content,
      ),
    );
  }

  /// Constrói o calendário
  Widget _buildCalendar(
    List<Event> events,
    List<ChurchSchedule> churchSchedules,
    List<Holiday> holidays,
  ) {
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

        // Lista embaixo do calendário já mostra os eventos do dia
        // _showDayDetailsBottomSheet(selectedDay);
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
          final month = DateFormat.MMM(locale).format(date).toUpperCase();
          return month.endsWith('.')
              ? '$month ${date.year}'
              : '$month. ${date.year}';
        },
        titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: Theme.of(context).colorScheme.primary,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary,
        ),
        headerPadding: const EdgeInsets.symmetric(vertical: 20),
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
        weekendTextStyle: TextStyle(color: Colors.red.shade700),

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
          final hasChurchSchedule = _hasChurchScheduleOnDay(
            day,
            churchSchedules,
          );

          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasHoliday)
                  Container(
                    width: 8,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800), // Laranja
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (hasEvent)
                  Container(
                    width: 8,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D6E45), // Verde
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (hasChurchSchedule)
                  Container(
                    width: 8,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary, // Azul primário
                      borderRadius: BorderRadius.circular(2),
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
  List<dynamic> _getEventsForDay(
    DateTime day,
    List<Event> events,
    List<ChurchSchedule> churchSchedules,
    List<Holiday> holidays,
  ) {
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
  bool _hasChurchScheduleOnDay(
    DateTime day,
    List<ChurchSchedule> churchSchedules,
  ) {
    return churchSchedules.any(
      (schedule) => isSameDay(schedule.startDatetime, day),
    );
  }

  /// Lista de eventos do dia selecionado
  Widget _buildEventsList() {
    final eventsAsync = ref.watch(eventsOfDateProvider(_selectedDay));
    final churchSchedulesAsync = ref.watch(
      churchSchedulesOfDateProvider(_selectedDay),
    );
    final holidays = ref.watch(holidaysOfDateProvider(_selectedDay));

    return eventsAsync.when(
      data: (events) {
        return churchSchedulesAsync.when(
          data: (churchSchedules) {
            final hasEvents =
                events.isNotEmpty ||
                churchSchedules.isNotEmpty ||
                holidays.isNotEmpty;

            if (!hasEvents) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nenhum evento neste dia',
                      style: CommunityDesign.titleStyle(context).copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aproveite o tempo para descansar\nou se conectar com a comunidade.',
                      textAlign: TextAlign.center,
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 4),
                    child: Text(
                      'PROGRAMAÇÃO DO DIA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  // Feriados
                  ...holidays.map((holiday) => _buildHolidayCard(holiday)),

                  // Eventos
                  ...events.map((event) => _buildEventCard(event)),

                  // Agendas da Igreja
                  ...churchSchedules.map(
                    (schedule) => _buildChurchScheduleCard(schedule),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
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
    const holidayColor = Color(0xFFFF9800); // Laranja

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: holidayColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.celebration, color: holidayColor, size: 24),
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
                        holiday.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    CommunityDesign.badge(context, 'Feriado', holidayColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Todo o dia',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card de evento
  Widget _buildEventCard(Event event) {
    final timeFormat = DateFormat.Hm();
    const eventColor = Color(0xFF1D6E45); // Verde (mesma cor de Oração)

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.push('/events/${event.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event, color: eventColor, size: 24),
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
                            event.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        CommunityDesign.badge(context, 'Evento', eventColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(event.startDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final agendaColor = Theme.of(context).colorScheme.primary; // Azul primário

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: agendaColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.church, color: agendaColor, size: 24),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    CommunityDesign.badge(
                      context,
                      scheduleType.label,
                      agendaColor,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${timeFormat.format(schedule.startDatetime)} - ${timeFormat.format(schedule.endDatetime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (schedule.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          schedule.location!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
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
  State<_MonthYearPickerBottomSheet> createState() =>
      _MonthYearPickerBottomSheetState();
}

class _MonthYearPickerBottomSheetState
    extends State<_MonthYearPickerBottomSheet> {
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Título
          Text(
            'SELECIONAR DATA',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: cs.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),

          // Seletor de Ano
          Container(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: cs.primary),
                  onPressed: () => setState(() => selectedYear--),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    selectedYear.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: cs.primary),
                  onPressed: () => setState(() => selectedYear++),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Grid de Meses
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected =
                  month == selectedMonth &&
                  selectedYear == widget.initialDate.year;
              final isCurrentMonth =
                  month == now.month && selectedYear == now.year;

              return InkWell(
                onTap: () {
                  final selectedDate = DateTime(selectedYear, month, 1);
                  widget.onDateSelected(selectedDate);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? cs.primary
                        : (isSelected
                              ? cs.primary.withValues(alpha: 0.1)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.MMMM(
                        'pt_BR',
                      ).format(DateTime(2000, month)).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: isSelected || isCurrentMonth
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCurrentMonth
                            ? Colors.white
                            : (isSelected ? cs.primary : cs.onSurface),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Botões de Ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onDateSelected(now),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('IR PARA HOJE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('FECHAR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
