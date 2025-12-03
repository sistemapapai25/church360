import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/events_provider.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// Tela de listagem de eventos
class EventsListScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final bool enableCrud;

  const EventsListScreen({
    super.key,
    this.showAppBar = true,
    this.enableCrud = true,
  });

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
      appBar: widget.showAppBar
          ? AppBar(
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
                IconButton(
                  tooltip: 'Gerenciar Tipos',
                  icon: const Icon(Icons.category),
                  onPressed: () {
                    context.push('/events/types');
                  },
                ),
              ],
            )
          : null,
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
                  if (widget.enableCrud) ...[
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
      floatingActionButton: widget.enableCrud
          ? FloatingActionButton.extended(
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
            )
          : null,
    );
  }
}

class EventTypesManageScreen extends ConsumerStatefulWidget {
  const EventTypesManageScreen({super.key});
  @override
  ConsumerState<EventTypesManageScreen> createState() => _EventTypesManageScreenState();
}

class _EventTypesManageScreenState extends ConsumerState<EventTypesManageScreen> {
  List<Map<String, String>> _types = [];
  bool _loading = false;
  String? _error;
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final catalog = await repo.getEventTypesCatalog();
      setState(() => _types = catalog);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final lbl = _labelController.text.trim();
    var code = '';
    if (lbl.isEmpty) {
      setState(() => _error = 'Informe um nome');
      return;
    }
    code = lbl.toLowerCase().replaceAll(' ', '_');
    try {
      final repo = ref.read(eventsRepositoryProvider);
      await repo.upsertEventType(code, lbl);
      _labelController.clear();
      setState(() => _error = '');
      await _load();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('code: 404')) {
        setState(() {
          _types.add({'code': code, 'label': lbl});
          _error = 'Catálogo não encontrado; incluído localmente (não persistido).';
        });
      } else {
        setState(() => _error = msg);
      }
    }
  }

  Future<void> _editLabel(String code, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Tipo'),
          content: TextField(controller: controller),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Salvar')),
          ],
        );
      },
    );
    if (newLabel == null || newLabel.isEmpty) return;
    try {
      final repo = ref.read(eventsRepositoryProvider);
      await repo.upsertEventType(code, newLabel);
      await _load();
      setState(() => _error = '');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('code: 404')) {
        setState(() {
          _types = _types.map((t) => t['code'] == code ? {'code': code, 'label': newLabel} : t).toList();
          _error = 'Catálogo não encontrado; alterado localmente (não persistido).';
        });
      } else {
        setState(() => _error = msg);
      }
    }
  }

  Future<void> _delete(String code) async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final used = await repo.getEventsCountByType(code);
      if (used > 0) {
        setState(() => _error = 'Tipo em uso por $used evento(s)');
        return;
      }
      await repo.deleteEventType(code);
      await _load();
      setState(() => _error = '');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Tipos de Evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null && _error!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome exibido'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Incluir')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _types.length,
                      itemBuilder: (context, index) {
                        final item = _types[index];
                        final code = item['code'] ?? '';
                        final label = item['label'] ?? code;
                        return ListTile(
                          title: Text(label),
                          subtitle: Text(code),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(onPressed: () => _editLabel(code, label), icon: const Icon(Icons.edit)),
                              IconButton(onPressed: () => _delete(code), icon: const Icon(Icons.delete_outline)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
