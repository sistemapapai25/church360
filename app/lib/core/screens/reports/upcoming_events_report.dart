import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/events/domain/models/event.dart';
import '../../constants/supabase_constants.dart';

/// Enum para períodos de filtro
enum EventPeriod {
  next7Days('Próximos 7 dias'),
  next15Days('Próximos 15 dias'),
  next30Days('Próximos 30 dias'),
  next60Days('Próximos 60 dias'),
  next90Days('Próximos 90 dias'),
  custom('Personalizado');

  final String label;
  const EventPeriod(this.label);
}

/// Provider para eventos futuros com filtro de período
final upcomingEventsByPeriodProvider = FutureProvider.family<List<Event>, (DateTime, DateTime)>(
  (ref, dates) async {
    final supabase = ref.watch(supabaseClientProvider);
    final (startDate, endDate) = dates;

    final response = await supabase
        .from('event')
        .select('''
          *,
          event_registration(count)
        ''')
        .eq('status', 'published')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .gte('start_date', startDate.toIso8601String())
        .lte('start_date', endDate.toIso8601String())
        .order('start_date', ascending: true);

    return (response as List).map((json) {
      final data = Map<String, dynamic>.from(json);
      
      // Processar contagem de inscrições
      if (data['event_registration'] != null) {
        final registrations = data['event_registration'];
        if (registrations is List && registrations.isNotEmpty) {
          data['registration_count'] = registrations[0]['count'];
        } else {
          data['registration_count'] = 0;
        }
      }
      
      return Event.fromJson(data);
    }).toList();
  },
);

/// Tela de relatório de próximos eventos
class UpcomingEventsReportScreen extends ConsumerStatefulWidget {
  const UpcomingEventsReportScreen({super.key});

  @override
  ConsumerState<UpcomingEventsReportScreen> createState() =>
      _UpcomingEventsReportScreenState();
}

class _UpcomingEventsReportScreenState
    extends ConsumerState<UpcomingEventsReportScreen> {
  EventPeriod _selectedPeriod = EventPeriod.next7Days;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();
    final eventsAsync = ref.watch(upcomingEventsByPeriodProvider((startDate, endDate)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximos Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(upcomingEventsByPeriodProvider);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de Período
          _buildPeriodFilter(),

          // Lista de Eventos
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(upcomingEventsByPeriodProvider);
              },
              child: eventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum evento agendado',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Não há eventos publicados neste período',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Card de Resumo
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${events.length}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  Text(
                                    events.length == 1 ? 'Evento' : 'Eventos',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              Container(
                                height: 50,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${events.where((e) => e.requiresRegistration).length}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  Text(
                                    'Com Inscrição',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              Container(
                                height: 50,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${events.where((e) => e.isFree).length}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                  Text(
                                    'Gratuitos',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de Eventos
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

  /// Construir card de evento
  Widget _buildEventCard(Event event) {
    final now = DateTime.now();
    final daysUntil = event.startDate.difference(now).inDays;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;
    final isThisWeek = daysUntil <= 7 && daysUntil > 1;

    Color statusColor = Colors.blue;
    String statusText = 'Em $daysUntil dias';

    if (isToday) {
      statusColor = Colors.orange;
      statusText = 'HOJE';
    } else if (isTomorrow) {
      statusColor = Colors.amber;
      statusText = 'AMANHÃ';
    } else if (isThisWeek) {
      statusColor = Colors.green;
      statusText = 'Esta semana';
    }

    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
              // Cabeçalho com título e status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 18,
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Informações do evento
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    dateFormatter.format(event.startDate),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              if (event.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Badges de informações
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Badge de preço
                  _buildBadge(
                    icon: Icons.attach_money,
                    label: event.isFree ? 'Gratuito' : formatter.format(event.price),
                    color: event.isFree ? Colors.green : Colors.orange,
                  ),

                  // Badge de inscrição
                  if (event.requiresRegistration)
                    _buildBadge(
                      icon: Icons.how_to_reg,
                      label: event.maxCapacity != null
                          ? '${event.registrationCount ?? 0}/${event.maxCapacity}'
                          : '${event.registrationCount ?? 0} inscritos',
                      color: Colors.blue,
                    ),

                  // Badge de tipo
                  if (event.eventType != null)
                    _buildBadge(
                      icon: Icons.category,
                      label: event.eventType!,
                      color: Colors.purple,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construir badge de informação
  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o intervalo de datas baseado no período selecionado
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case EventPeriod.next7Days:
        return (now, now.add(const Duration(days: 7)));
      case EventPeriod.next15Days:
        return (now, now.add(const Duration(days: 15)));
      case EventPeriod.next30Days:
        return (now, now.add(const Duration(days: 30)));
      case EventPeriod.next60Days:
        return (now, now.add(const Duration(days: 60)));
      case EventPeriod.next90Days:
        return (now, now.add(const Duration(days: 90)));
      case EventPeriod.custom:
        return (
          _customStartDate ?? now,
          _customEndDate ?? now.add(const Duration(days: 7)),
        );
    }
  }

  /// Filtro de período
  Widget _buildPeriodFilter() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EventPeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == EventPeriod.custom) {
                        _showCustomDatePicker();
                      }
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

  /// Mostrar seletor de datas personalizado
  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Data Inicial',
    );

    if (startDate != null && mounted) {
      final endDate = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? startDate.add(const Duration(days: 7)),
        firstDate: startDate,
        lastDate: DateTime(now.year + 2),
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
