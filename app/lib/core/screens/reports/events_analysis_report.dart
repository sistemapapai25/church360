import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/events/domain/models/event.dart';

/// Enum para períodos de filtro
enum EventAnalysisPeriod {
  last7Days('Últimos 7 dias'),
  last15Days('Últimos 15 dias'),
  last30Days('Últimos 30 dias'),
  last60Days('Últimos 60 dias'),
  last90Days('Últimos 90 dias'),
  custom('Personalizado');

  final String label;
  const EventAnalysisPeriod(this.label);
}

/// Enum para status de eventos
enum EventStatusFilter {
  all('Todos'),
  published('Publicados'),
  ongoing('Em Andamento'),
  completed('Finalizados'),
  cancelled('Cancelados'),
  draft('Rascunhos');

  final String label;
  const EventStatusFilter(this.label);

  String? get dbValue {
    switch (this) {
      case EventStatusFilter.all:
        return null;
      case EventStatusFilter.published:
        return 'published';
      case EventStatusFilter.ongoing:
        return 'ongoing';
      case EventStatusFilter.completed:
        return 'completed';
      case EventStatusFilter.cancelled:
        return 'cancelled';
      case EventStatusFilter.draft:
        return 'draft';
    }
  }
}

/// Provider para eventos com análise por período
final eventsAnalysisByPeriodProvider = FutureProvider.family<Map<String, dynamic>, (DateTime, DateTime, String?)>(
  (ref, params) async {
    final supabase = ref.watch(supabaseClientProvider);
    final (startDate, endDate, statusFilter) = params;

    // Query base
    var query = supabase
        .from('event')
        .select('''
          *,
          event_registration(
            id,
            user_id,
            checked_in_at,
            registered_at
          )
        ''')
        .gte('start_date', startDate.toIso8601String())
        .lte('start_date', endDate.toIso8601String());

    // Aplicar filtro de status se especificado (ANTES do order)
    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    // Aplicar ordenação por último
    final response = await query.order('start_date', ascending: false);

    // Processar eventos
    final events = (response as List).map((json) {
      final data = Map<String, dynamic>.from(json);
      
      // Processar registrations
      final registrations = data['event_registration'] as List?;
      int totalRegistrations = 0;
      int totalCheckedIn = 0;

      if (registrations != null) {
        totalRegistrations = registrations.length;
        totalCheckedIn = registrations.where((r) => r['checked_in_at'] != null).length;
      }

      data['registration_count'] = totalRegistrations;
      data['checked_in_count'] = totalCheckedIn;
      data['check_in_rate'] = totalRegistrations > 0 
          ? (totalCheckedIn / totalRegistrations * 100).toStringAsFixed(1)
          : '0.0';

      return Event.fromJson(data);
    }).toList();

    // Buscar visitantes do mesmo período
    final visitorsResponse = await supabase
        .from('visitor')
        .select('id, first_visit_date, last_visit_date, status')
        .gte('first_visit_date', startDate.toIso8601String().split('T')[0])
        .lte('first_visit_date', endDate.toIso8601String().split('T')[0])
        .neq('status', 'converted');

    final visitors = visitorsResponse as List;

    // Calcular estatísticas
    final totalEvents = events.length;
    final totalRegistrations = events.fold<int>(0, (sum, e) => sum + (e.registrationCount ?? 0));
    final totalVisitors = visitors.length;
    
    final eventsByStatus = <String, int>{};
    for (var event in events) {
      eventsByStatus[event.status] = (eventsByStatus[event.status] ?? 0) + 1;
    }

    return {
      'events': events,
      'visitors': visitors,
      'totalEvents': totalEvents,
      'totalRegistrations': totalRegistrations,
      'totalVisitors': totalVisitors,
      'eventsByStatus': eventsByStatus,
    };
  },
);

/// Tela de relatório de análise de eventos
class EventsAnalysisReportScreen extends ConsumerStatefulWidget {
  const EventsAnalysisReportScreen({super.key});

  @override
  ConsumerState<EventsAnalysisReportScreen> createState() =>
      _EventsAnalysisReportScreenState();
}

class _EventsAnalysisReportScreenState
    extends ConsumerState<EventsAnalysisReportScreen> {
  EventAnalysisPeriod _selectedPeriod = EventAnalysisPeriod.last30Days;
  EventStatusFilter _selectedStatus = EventStatusFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();
    final analysisAsync = ref.watch(
      eventsAnalysisByPeriodProvider((startDate, endDate, _selectedStatus.dbValue)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(eventsAnalysisByPeriodProvider);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _buildFilters(),

          // Conteúdo
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(eventsAnalysisByPeriodProvider);
              },
              child: analysisAsync.when(
                data: (data) {
                  final events = data['events'] as List<Event>;
                  final totalEvents = data['totalEvents'] as int;
                  final totalRegistrations = data['totalRegistrations'] as int;
                  final totalVisitors = data['totalVisitors'] as int;
                  final eventsByStatus = data['eventsByStatus'] as Map<String, int>;

                  if (events.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum evento encontrado',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Cards de Resumo
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total de Eventos',
                              '$totalEvents',
                              Icons.event,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Inscrições',
                              '$totalRegistrations',
                              Icons.how_to_reg,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Visitantes',
                              '$totalVisitors',
                              Icons.people,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Média/Evento',
                              totalEvents > 0 
                                  ? (totalRegistrations / totalEvents).toStringAsFixed(1)
                                  : '0',
                              Icons.analytics,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Gráfico de Eventos por Status
                      if (eventsByStatus.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Eventos por Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: _buildPieChart(eventsByStatus),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Top 5 Eventos com Mais Inscrições
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top 5 Eventos com Mais Inscrições',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTopEventsChart(events),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de Eventos
                      const Text(
                        'Todos os Eventos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...events.map((event) => _buildEventCard(event)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro: $error'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de resumo
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Gráfico de pizza (eventos por status)
  Widget _buildPieChart(Map<String, int> eventsByStatus) {
    final statusColors = {
      'published': Colors.blue,
      'ongoing': Colors.green,
      'completed': Colors.grey,
      'cancelled': Colors.red,
      'draft': Colors.orange,
    };

    final statusLabels = {
      'published': 'Publicados',
      'ongoing': 'Em Andamento',
      'completed': 'Finalizados',
      'cancelled': 'Cancelados',
      'draft': 'Rascunhos',
    };

    final sections = eventsByStatus.entries.map((entry) {
      final color = statusColors[entry.key] ?? Colors.grey;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: eventsByStatus.entries.map((entry) {
              final color = statusColors[entry.key] ?? Colors.grey;
              final label = statusLabels[entry.key] ?? entry.key;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Gráfico de barras (top eventos)
  Widget _buildTopEventsChart(List<Event> events) {
    // Ordenar por número de inscrições e pegar top 5
    final sortedEvents = List<Event>.from(events)
      ..sort((a, b) => (b.registrationCount ?? 0).compareTo(a.registrationCount ?? 0));
    
    final topEvents = sortedEvents.take(5).toList();

    if (topEvents.isEmpty) {
      return const Text('Nenhum evento com inscrições');
    }

    return Column(
      children: topEvents.map((event) {
        final registrations = event.registrationCount ?? 0;
        final maxRegistrations = topEvents.first.registrationCount ?? 1;
        final percentage = (registrations / maxRegistrations * 100).toInt();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$registrations inscrições',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Card de evento
  Widget _buildEventCard(Event event) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final registrations = event.registrationCount ?? 0;

    Color statusColor = Colors.grey;
    String statusText = event.statusText;

    switch (event.status) {
      case 'published':
        statusColor = Colors.blue;
        break;
      case 'ongoing':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = Colors.grey;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'draft':
        statusColor = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/events/${event.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    dateFormatter.format(event.startDate),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              if (event.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetricBadge(
                    Icons.how_to_reg,
                    '$registrations inscrições',
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  if (event.requiresRegistration && event.maxCapacity != null)
                    _buildMetricBadge(
                      Icons.people,
                      '${event.maxCapacity} vagas',
                      Colors.blue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Badge de métrica
  Widget _buildMetricBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o intervalo de datas
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriod) {
      case EventAnalysisPeriod.last7Days:
        return (today.subtract(const Duration(days: 6)), today);
      case EventAnalysisPeriod.last15Days:
        return (today.subtract(const Duration(days: 14)), today);
      case EventAnalysisPeriod.last30Days:
        return (today.subtract(const Duration(days: 29)), today);
      case EventAnalysisPeriod.last60Days:
        return (today.subtract(const Duration(days: 59)), today);
      case EventAnalysisPeriod.last90Days:
        return (today.subtract(const Duration(days: 89)), today);
      case EventAnalysisPeriod.custom:
        return (
          _customStartDate ?? today.subtract(const Duration(days: 29)),
          _customEndDate ?? today,
        );
    }
  }

  /// Filtros
  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EventAnalysisPeriod.values.map((period) {
                return FilterChip(
                  label: Text(period.label, style: const TextStyle(fontSize: 12)),
                  selected: _selectedPeriod == period,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == EventAnalysisPeriod.custom) {
                        _showCustomDatePicker();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EventStatusFilter.values.map((status) {
                return FilterChip(
                  label: Text(status.label, style: const TextStyle(fontSize: 12)),
                  selected: _selectedStatus == status,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Seletor de datas personalizado
  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final startDate = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? today.subtract(const Duration(days: 29)),
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Data Inicial',
    );

    if (startDate != null && mounted) {
      final endDate = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? today,
        firstDate: startDate,
        lastDate: today,
        helpText: 'Data Final',
      );

      if (endDate != null && mounted) {
        setState(() {
          _customStartDate = startDate;
          _customEndDate = endDate;
        });
      }
    }
  }
}
