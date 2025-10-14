import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
import '../../data/events_repository.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/domain/models/ministry.dart';
import 'event_form_screen.dart';

/// Tela de detalhes do evento
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Evento não encontrado')),
            body: const Center(child: Text('Evento não encontrado')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(event.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventFormScreen(eventId: event.id),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, event),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Informações'),
                Tab(
                  text: event.requiresRegistration
                      ? 'Inscritos (${event.registrationCount ?? 0})'
                      : 'Inscritos',
                ),
                const Tab(text: 'Escalas'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _InfoTab(event: event),
              _RegistrationsTab(event: event),
              _SchedulesTab(eventId: event.id),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro ao carregar evento: $error')),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o evento "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(eventsRepositoryProvider).deleteEvent(widget.eventId);
        ref.invalidate(allEventsProvider);
        ref.invalidate(activeEventsProvider);
        ref.invalidate(upcomingEventsProvider);
        
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento excluído com sucesso!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir evento: $e')),
          );
        }
      }
    }
  }
}

/// Tab de informações do evento
class _InfoTab extends StatelessWidget {
  final Event event;

  const _InfoTab({required this.event});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          _StatusChip(event: event),
          const SizedBox(height: 24),

          // Nome
          Text(
            event.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Descrição
          if (event.description != null && event.description!.isNotEmpty) ...[
            Text(
              event.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
          ],

          // Informações
          _InfoCard(
            icon: Icons.calendar_today,
            title: 'Data de Início',
            value: DateFormat('dd/MM/yyyy').format(event.startDate),
          ),
          _InfoCard(
            icon: Icons.access_time,
            title: 'Horário de Início',
            value: DateFormat('HH:mm').format(event.startDate),
          ),
          if (event.endDate != null)
            _InfoCard(
              icon: Icons.event_available,
              title: 'Data de Término',
              value: DateFormat('dd/MM/yyyy HH:mm').format(event.endDate!),
            ),
          if (event.location != null)
            _InfoCard(
              icon: Icons.location_on,
              title: 'Local',
              value: event.location!,
            ),
          if (event.eventType != null)
            _InfoCard(
              icon: Icons.category,
              title: 'Tipo',
              value: event.eventType!,
            ),
          if (event.maxCapacity != null)
            _InfoCard(
              icon: Icons.people,
              title: 'Capacidade Máxima',
              value: '${event.maxCapacity} pessoas',
            ),
          _InfoCard(
            icon: Icons.app_registration,
            title: 'Requer Inscrição',
            value: event.requiresRegistration ? 'Sim' : 'Não',
          ),
          if (event.requiresRegistration) ...[
            _InfoCard(
              icon: Icons.how_to_reg,
              title: 'Inscritos',
              value: '${event.registrationCount ?? 0}${event.maxCapacity != null ? ' / ${event.maxCapacity}' : ''}',
            ),
            if (event.isFull)
              const Card(
                color: Colors.red,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'EVENTO LOTADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Card de informação
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
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
}

/// Chip de status do evento
class _StatusChip extends StatelessWidget {
  final Event event;

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
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

/// Tab de inscritos do evento
class _RegistrationsTab extends ConsumerWidget {
  final Event event;

  const _RegistrationsTab({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!event.requiresRegistration) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Este evento não requer inscrição'),
          ],
        ),
      );
    }

    final registrationsAsync = ref.watch(eventRegistrationsProvider(event.id));

    return registrationsAsync.when(
      data: (registrations) {
        if (registrations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Nenhum inscrito ainda',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showAddRegistrationDialog(context, ref, event),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Adicionar Primeiro Inscrito'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(eventRegistrationsProvider(event.id));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: registrations.length,
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          registration.memberName?.substring(0, 1).toUpperCase() ?? '?',
                        ),
                      ),
                      title: Text(registration.memberName ?? 'Membro desconhecido'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inscrito em: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.registeredAt)}',
                          ),
                          if (registration.isCheckedIn)
                            Row(
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Check-in: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.checkedInAt!)}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botão de check-in
                          if (!registration.isCheckedIn)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              onPressed: () => _doCheckIn(context, ref, event.id, registration.memberId),
                              tooltip: 'Fazer check-in',
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.orange),
                              onPressed: () => _cancelCheckIn(context, ref, event.id, registration.memberId),
                              tooltip: 'Cancelar check-in',
                            ),
                          // Botão de remover
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmRemoveRegistration(
                              context,
                              ref,
                              event.id,
                              registration.memberId,
                              registration.memberName ?? 'este membro',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // FAB para adicionar inscrito
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddRegistrationDialog(context, ref, event),
                child: const Icon(Icons.person_add),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar inscritos: $error'),
      ),
    );
  }

  Future<void> _showAddRegistrationDialog(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => _AddRegistrationDialog(eventId: event.id),
    );
  }

  Future<void> _doCheckIn(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
  ) async {
    try {
      await ref.read(eventsRepositoryProvider).checkIn(eventId, memberId);
      ref.invalidate(eventRegistrationsProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in realizado com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer check-in: $e')),
        );
      }
    }
  }

  Future<void> _cancelCheckIn(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
  ) async {
    try {
      await ref.read(eventsRepositoryProvider).cancelCheckIn(eventId, memberId);
      ref.invalidate(eventRegistrationsProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in cancelado!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar check-in: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemoveRegistration(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
    String memberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar remoção'),
        content: Text('Deseja remover $memberName deste evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(eventsRepositoryProvider).removeRegistration(eventId, memberId);
        ref.invalidate(eventRegistrationsProvider(eventId));
        ref.invalidate(eventByIdProvider(eventId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inscrito removido com sucesso!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao remover inscrito: $e')),
          );
        }
      }
    }
  }
}

/// Dialog para adicionar inscrito
class _AddRegistrationDialog extends ConsumerStatefulWidget {
  final String eventId;

  const _AddRegistrationDialog({required this.eventId});

  @override
  ConsumerState<_AddRegistrationDialog> createState() => _AddRegistrationDialogState();
}

class _AddRegistrationDialogState extends ConsumerState<_AddRegistrationDialog> {
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final allMembersAsync = ref.watch(allMembersProvider);
    final registrationsAsync = ref.watch(eventRegistrationsProvider(widget.eventId));

    return AlertDialog(
      title: const Text('Adicionar Inscrito'),
      content: SizedBox(
        width: double.maxFinite,
        child: allMembersAsync.when(
          data: (allMembers) {
            return registrationsAsync.when(
              data: (registrations) {
                // Filtrar membros que já estão inscritos
                final registeredMemberIds = registrations.map((r) => r.memberId).toSet();
                final availableMembers = allMembers
                    .where((m) => !registeredMemberIds.contains(m.id))
                    .toList();

                if (availableMembers.isEmpty) {
                  return const Text('Todos os membros já estão inscritos neste evento.');
                }

                // Garantir que o valor selecionado está na lista
                if (_selectedMemberId != null &&
                    !availableMembers.any((m) => m.id == _selectedMemberId)) {
                  _selectedMemberId = null;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Selecione um membro',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: availableMembers.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.fullName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedMemberId = value);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Erro: $error'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Erro: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedMemberId == null
              ? null
              : () => _addRegistration(context),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addRegistration(BuildContext context) async {
    if (_selectedMemberId == null) return;

    try {
      await ref.read(eventsRepositoryProvider).addRegistration(
            widget.eventId,
            _selectedMemberId!,
          );
      ref.invalidate(eventRegistrationsProvider(widget.eventId));
      ref.invalidate(eventByIdProvider(widget.eventId));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscrito adicionado com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar inscrito: $e')),
        );
      }
    }
  }
}

/// Tab de escalas de ministérios
class _SchedulesTab extends ConsumerWidget {
  final String eventId;

  const _SchedulesTab({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(eventSchedulesProvider(eventId));

    return schedulesAsync.when(
      data: (schedules) {
        // Agrupar escalas por ministério
        final Map<String, List<MinistrySchedule>> schedulesByMinistry = {};
        for (final schedule in schedules) {
          if (!schedulesByMinistry.containsKey(schedule.ministryId)) {
            schedulesByMinistry[schedule.ministryId] = [];
          }
          schedulesByMinistry[schedule.ministryId]!.add(schedule);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Botão para adicionar escala
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.blue),
                title: const Text('Adicionar Membro à Escala'),
                subtitle: const Text('Escale membros de ministérios para este evento'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showAddScheduleDialog(context, ref),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de escalas agrupadas por ministério
            if (schedulesByMinistry.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum membro escalado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Adicione membros de ministérios para servir neste evento',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...schedulesByMinistry.entries.map((entry) {
                final ministrySchedules = entry.value;
                final ministryName = ministrySchedules.first.ministryName;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header do ministério
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.church, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ministryName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${ministrySchedules.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista de membros escalados
                      ...ministrySchedules.map((schedule) {
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(schedule.memberName),
                          subtitle: schedule.notes != null
                              ? Text(schedule.notes!)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmRemoveSchedule(
                              context,
                              ref,
                              schedule,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  void _showAddScheduleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddScheduleDialog(eventId: eventId),
    );
  }

  Future<void> _confirmRemoveSchedule(
    BuildContext context,
    WidgetRef ref,
    MinistrySchedule schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Tem certeza que deseja remover ${schedule.memberName} da escala?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.removeSchedule(schedule.id);

        ref.invalidate(eventSchedulesProvider(eventId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membro removido da escala com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover da escala: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Diálogo para adicionar membro à escala
class _AddScheduleDialog extends ConsumerStatefulWidget {
  final String eventId;

  const _AddScheduleDialog({required this.eventId});

  @override
  ConsumerState<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends ConsumerState<_AddScheduleDialog> {
  String? _selectedMinistryId;
  String? _selectedMemberId;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);

    return AlertDialog(
      title: const Text('Adicionar à Escala'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seletor de ministério
              ministriesAsync.when(
                data: (ministries) {
                  if (ministries.isEmpty) {
                    return const Text('Nenhum ministério ativo disponível');
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedMinistryId,
                    decoration: const InputDecoration(
                      labelText: 'Selecione o Ministério',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.church),
                    ),
                    items: ministries.map((ministry) {
                      return DropdownMenuItem(
                        value: ministry.id,
                        child: Text(ministry.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMinistryId = value;
                        _selectedMemberId = null; // Reset member selection
                      });
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Erro: $error'),
              ),
              const SizedBox(height: 16),

              // Seletor de membro (só aparece se ministério foi selecionado)
              if (_selectedMinistryId != null) _buildMemberSelector(),

              const SizedBox(height: 16),

              // Notas
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _addSchedule,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Widget _buildMemberSelector() {
    final membersAsync = ref.watch(ministryMembersProvider(_selectedMinistryId!));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const Text('Nenhum membro neste ministério');
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedMemberId,
          decoration: const InputDecoration(
            labelText: 'Selecione o Membro',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          items: members.map((member) {
            return DropdownMenuItem(
              value: member.memberId,
              child: Text(member.memberName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedMemberId = value;
            });
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Erro: $error'),
    );
  }

  Future<void> _addSchedule() async {
    if (_selectedMinistryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um ministério'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um membro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(ministriesRepositoryProvider);
      await repository.addSchedule({
        'event_id': widget.eventId,
        'ministry_id': _selectedMinistryId,
        'member_id': _selectedMemberId,
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      });

      ref.invalidate(eventSchedulesProvider(widget.eventId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro adicionado à escala com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar à escala: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

