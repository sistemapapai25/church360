import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/events_provider.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// Tela de listagem de eventos
class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  String _filter = 'upcoming'; // 'all', 'upcoming', 'active'

  @override
  Widget build(BuildContext context) {
    final eventsAsync = _filter == 'upcoming'
        ? ref.watch(upcomingEventsProvider)
        : _filter == 'active'
            ? ref.watch(activeEventsProvider)
            : ref.watch(allEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _filter,
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upcoming',
                child: Text('Próximos'),
              ),
              const PopupMenuItem(
                value: 'active',
                child: Text('Ativos'),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Text('Todos'),
              ),
            ],
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum evento encontrado',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EventFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Primeiro Evento'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allEventsProvider);
              ref.invalidate(activeEventsProvider);
              ref.invalidate(upcomingEventsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(eventId: event.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header com nome e status
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              _StatusChip(event: event),
                            ],
                          ),
                          
                          if (event.description != null && event.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              event.description!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          
                          // Informações do evento
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(event.startDate),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(event.startDate),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          
                          if (event.location != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          if (event.requiresRegistration) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.people, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '${event.registrationCount ?? 0} inscritos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (event.maxCapacity != null) ...[
                                  Text(
                                    ' / ${event.maxCapacity}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (event.isFull) ...[
                                    const SizedBox(width: 8),
                                    const Chip(
                                      label: Text('LOTADO', style: TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar eventos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allEventsProvider);
                  ref.invalidate(activeEventsProvider);
                  ref.invalidate(upcomingEventsProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Evento'),
      ),
    );
  }
}

/// Chip de status do evento
class _StatusChip extends StatelessWidget {
  final dynamic event;

  const _StatusChip({required this.event});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String label = event.statusText;

    if (event.status == 'cancelled') {
      backgroundColor = Colors.red;
    } else if (event.status == 'completed' || event.isPast) {
      backgroundColor = Colors.grey;
    } else if (event.isOngoing) {
      backgroundColor = Colors.green;
    } else if (event.isUpcoming) {
      backgroundColor = Colors.blue;
    } else {
      backgroundColor = Colors.orange;
    }

    return Chip(
      label: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
  }
}

