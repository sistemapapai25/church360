import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_stats_provider.dart';

/// Tela de relatório de eventos
class EventsReportScreen extends ConsumerStatefulWidget {
  const EventsReportScreen({super.key});

  @override
  ConsumerState<EventsReportScreen> createState() => _EventsReportScreenState();
}

class _EventsReportScreenState extends ConsumerState<EventsReportScreen> {
  String _selectedFilter = 'upcoming'; // upcoming, all, past

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Eventos'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedFilter,
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upcoming',
                child: Text('Próximos Eventos'),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Text('Todos os Eventos'),
              ),
              const PopupMenuItem(
                value: 'past',
                child: Text('Eventos Passados'),
              ),
            ],
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_selectedFilter == 'upcoming') {
      return _buildUpcomingEvents();
    } else {
      return const Center(
        child: Text('Filtro em desenvolvimento'),
      );
    }
  }

  Widget _buildUpcomingEvents() {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(upcomingEventsProvider);
      },
      child: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Text('Nenhum evento próximo'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final title = event['title'] as String;
              final startDate = event['start_date'] as DateTime;
              final location = event['location'] as String?;
              final daysUntil = startDate.difference(DateTime.now()).inDays;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(startDate),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(startDate).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(startDate)),
                      if (location != null && location.isNotEmpty)
                        Text(
                          location,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: daysUntil == 0
                          ? Colors.orange[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      daysUntil == 0
                          ? 'HOJE'
                          : daysUntil == 1
                              ? 'AMANHÃ'
                              : 'EM $daysUntil DIAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: daysUntil == 0
                            ? Colors.orange[700]
                            : Colors.blue[700],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

