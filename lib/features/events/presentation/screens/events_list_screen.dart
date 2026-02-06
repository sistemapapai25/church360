import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';

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
      backgroundColor: const Color(0xFFF5F9FD),
      appBar: widget.showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 64,
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              backgroundColor: const Color(0xFFF5F9FD),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              leadingWidth: 54,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  tooltip: 'Voltar',
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              title: Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
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
                        Icons.event,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Eventos',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222B3A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fique por dentro da programação',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A8A9A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                    const PopupMenuItem(value: 'active', child: Text('Ativos')),
                    const PopupMenuItem(value: 'all', child: Text('Todos')),
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
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: CommunityDesign.overlayDecoration(
                    cs,
                    hovered: true,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 64,
                        color: cs.primary.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum evento encontrado',
                        style: CommunityDesign.titleStyle(context),
                      ),
                      if (widget.enableCrud) ...[
                        const SizedBox(height: 16),
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
                ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: CommunityDesign.overlayDecoration(
                    Theme.of(context).colorScheme,
                    hovered: true,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CommunityDesign.radius),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EventDetailScreen(eventId: event.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header com nome e status
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.name,
                                      style: CommunityDesign.titleStyle(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusChip(event: event),
                                ],
                              ),

                              if (event.description != null &&
                                  event.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  event.description!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 10),

                              // Informações do evento
                              Row(
                                children: [
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(event.startDate),
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('HH:mm').format(event.startDate),
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                                ],
                              ),

                              if (event.location != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        event.location!,
                                        style: CommunityDesign.metaStyle(
                                          context,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (event.requiresRegistration) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 6),
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
                                        style: CommunityDesign.metaStyle(
                                          context,
                                        ),
                                      ),
                                      if (event.isFull) ...[
                                        const SizedBox(width: 8),
                                        CommunityDesign.badge(
                                          context,
                                          'LOTADO',
                                          Colors.red,
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
  ConsumerState<EventTypesManageScreen> createState() =>
      _EventTypesManageScreenState();
}

class _EventTypesManageScreenState
    extends ConsumerState<EventTypesManageScreen> {
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
          _error =
              'Catálogo não encontrado; incluído localmente (não persistido).';
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
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Salvar'),
            ),
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
          _types = _types
              .map(
                (t) =>
                    t['code'] == code ? {'code': code, 'label': newLabel} : t,
              )
              .toList();
          _error =
              'Catálogo não encontrado; alterado localmente (não persistido).';
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
      appBar: AppBar(title: const Text('Gerenciar Tipos de Evento')),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nome exibido',
                    ),
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
                              IconButton(
                                onPressed: () => _editLabel(code, label),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () => _delete(code),
                                icon: const Icon(Icons.delete_outline),
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
    );
  }
}

/// Chip de status do evento
class _StatusChip extends StatelessWidget {
  final dynamic event;

  const _StatusChip({required this.event});

  @override
  Widget build(BuildContext context) {
    String label = event.statusText ?? '';
    Color color;

    if (event.status == 'cancelled') {
      color = Colors.red;
    } else if (event.status == 'completed' || event.isPast) {
      color = Colors.grey.shade700;
    } else if (event.isOngoing) {
      color = Colors.green.shade700;
    } else if (event.isUpcoming) {
      color = Colors.blue.shade700;
    } else {
      color = Colors.orange.shade700;
    }

    return CommunityDesign.badge(context, label.toUpperCase(), color);
  }
}
