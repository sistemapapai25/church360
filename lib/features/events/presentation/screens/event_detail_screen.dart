import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/domain/models/ministry.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/community_design.dart';

/// Tela de detalhes do evento
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

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
          backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            backgroundColor: CommunityDesign.headerColor(context),
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            titleSpacing: 0,
            leadingWidth: 54,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                tooltip: 'Voltar',
                onPressed: () => _handleBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            title: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Detalhes do evento',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
}

/// Tab de informações do evento
class _InfoTab extends StatelessWidget {
  final Event event;

  const _InfoTab({required this.event});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do evento
          if (event.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                event.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Status
          _StatusChip(event: event),
          const SizedBox(height: 24),

          // Nome
          Text(
            event.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
              value:
                  '${event.registrationCount ?? 0}${event.maxCapacity != null ? ' / ${event.maxCapacity}' : ''}',
            ),
            if (event.isFull)
              Container(
                padding: const EdgeInsets.all(20),
                decoration:
                    CommunityDesign.overlayDecoration(
                      Theme.of(context).colorScheme,
                    ).copyWith(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                child: const Row(
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
          ],

          // Botão de inscrição
          if (event.requiresRegistration && !event.isPast) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: event.isFull
                    ? null
                    : () => context.push('/events/${event.id}/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: event.isFree
                      ? const Color(0xFF38A169)
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  event.isFree
                      ? Icons.card_giftcard
                      : Icons.confirmation_number,
                ),
                label: Text(
                  event.isFull
                      ? 'EVENTO LOTADO'
                      : event.isFree
                      ? 'INSCREVER-SE GRATUITAMENTE'
                      : 'COMPRAR INGRESSO',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      padding: const EdgeInsets.all(20),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
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
    final colorScheme = Theme.of(context).colorScheme;
    String label = event.statusText;
    Color color;

    if (event.status == 'cancelled') {
      color = colorScheme.error;
    } else if (event.status == 'completed' || event.isPast) {
      color = colorScheme.onSurfaceVariant;
    } else if (event.isOngoing) {
      color = const Color(0xFF38A169); // Verde sucesso
    } else if (event.isUpcoming) {
      color = colorScheme.primary;
    } else {
      color = colorScheme.tertiary;
    }

    return CommunityDesign.badge(context, label.toUpperCase(), color);
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      _showAddRegistrationDialog(context, ref, event),
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
                padding: const EdgeInsets.all(20),
                itemCount: registrations.length,
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: CommunityDesign.overlayDecoration(
                      Theme.of(context).colorScheme,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          registration.memberName
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              '?',
                        ),
                      ),
                      title: Text(
                        registration.memberName ?? 'Membro desconhecido',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inscrito em: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.registeredAt)}',
                          ),
                          if (registration.isCheckedIn)
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
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
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () => _doCheckIn(
                                context,
                                ref,
                                event.id,
                                registration.memberId,
                              ),
                              tooltip: 'Fazer check-in',
                            )
                          else
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.orange,
                              ),
                              onPressed: () => _cancelCheckIn(
                                context,
                                ref,
                                event.id,
                                registration.memberId,
                              ),
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
                onPressed: () =>
                    _showAddRegistrationDialog(context, ref, event),
                child: const Icon(Icons.person_add),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Erro ao carregar inscritos: $error')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao fazer check-in: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Check-in cancelado!')));
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
        await ref
            .read(eventsRepositoryProvider)
            .removeRegistration(eventId, memberId);
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
  ConsumerState<_AddRegistrationDialog> createState() =>
      _AddRegistrationDialogState();
}

class _AddRegistrationDialogState
    extends ConsumerState<_AddRegistrationDialog> {
  String? _selectedMemberId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMembersAsync = ref.watch(allMembersProvider);
    final registrationsAsync = ref.watch(
      eventRegistrationsProvider(widget.eventId),
    );

    return AlertDialog(
      title: const Text('Adicionar Inscrito'),
      content: SizedBox(
        width: double.maxFinite,
        child: allMembersAsync.when(
          data: (allMembers) {
            return registrationsAsync.when(
              data: (registrations) {
                // Filtrar membros que já estão inscritos
                final registeredMemberIds = registrations
                    .map((r) => r.memberId)
                    .toSet();
                final availableMembers = allMembers
                    .where((m) => !registeredMemberIds.contains(m.id))
                    .toList();

                if (availableMembers.isEmpty) {
                  return const Text(
                    'Todos os membros já estão inscritos neste evento.',
                  );
                }

                // Garantir que o valor selecionado está na lista
                if (_selectedMemberId != null &&
                    !availableMembers.any((m) => m.id == _selectedMemberId)) {
                  _selectedMemberId = null;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar membro...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: Builder(
                        builder: (context) {
                          var filtered = availableMembers;
                          if (_searchQuery.isNotEmpty) {
                            final q = _searchQuery.toLowerCase();
                            filtered = filtered.where((m) {
                              return m.displayName.toLowerCase().contains(q) ||
                                  ((m.nickname?.toLowerCase().contains(q)) ??
                                      false);
                            }).toList();
                          }

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Nenhum membro disponível'
                                    : 'Nenhum resultado para "$_searchQuery"',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final m = filtered[index];
                              final isSelected = _selectedMemberId == m.id;
                              return ListTile(
                                leading: CircleAvatar(child: Text(m.initials)),
                                title: Text(m.displayName),
                                subtitle: Text(m.email),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() => _selectedMemberId = m.id);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
      await ref
          .read(eventsRepositoryProvider)
          .addRegistration(widget.eventId, _selectedMemberId!);
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

        Widget buildMinistryCard({
          required String ministryId,
          required String ministryName,
          required List<MinistrySchedule> ministrySchedules,
        }) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: CommunityDesign.overlayDecoration(
              Theme.of(context).colorScheme,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(CommunityDesign.radius),
                      topRight: Radius.circular(CommunityDesign.radius),
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
                PermissionBuilder(
                  permission: 'ministries.manage_schedule',
                  builder: (context, hasPermission) {
                    if (!hasPermission) return const SizedBox.shrink();
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.blue,
                          ),
                          title: const Text('Adicionar membro'),
                          subtitle: const Text(
                            'Adicionar/ajustar escala deste ministério',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _openMinistryAutoScheduler(
                            context,
                            ministryId,
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.2),
                        ),
                      ],
                    );
                  },
                ),
                if (ministrySchedules.isNotEmpty)
                  ...ministrySchedules.map((schedule) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(schedule.memberName),
                      subtitle:
                          schedule.notes != null ? Text(schedule.notes!) : null,
                    );
                  }),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Lista de escalas agrupadas por ministério
            if (schedulesByMinistry.isEmpty)
              _EmptySchedulesContent(
                buildMinistryCard: buildMinistryCard,
              )
            else
              ...schedulesByMinistry.entries.map((entry) {
                final ministrySchedules = entry.value;
                final ministryName = ministrySchedules.first.ministryName;

                return buildMinistryCard(
                  ministryId: entry.key,
                  ministryName: ministryName,
                  ministrySchedules: ministrySchedules,
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  void _openMinistryAutoScheduler(BuildContext context, String ministryId) {
    context.push('/ministries/$ministryId/auto-scheduler');
  }
}

class _EmptySchedulesContent extends ConsumerWidget {
  final Widget Function({
    required String ministryId,
    required String ministryName,
    required List<MinistrySchedule> ministrySchedules,
  }) buildMinistryCard;

  const _EmptySchedulesContent({required this.buildMinistryCard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);

    return Column(
      children: [
        Container(
          decoration: CommunityDesign.overlayDecoration(
            Theme.of(context).colorScheme,
          ),
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
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione um ministério abaixo para adicionar membros',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ministriesAsync.when(
          data: (ministries) {
            if (ministries.isEmpty) {
              return Container(
                decoration: CommunityDesign.overlayDecoration(
                  Theme.of(context).colorScheme,
                ),
                padding: const EdgeInsets.all(16),
                child: const Text('Nenhum ministério ativo disponível'),
              );
            }

            return Column(
              children: [
                for (final m in ministries)
                  buildMinistryCard(
                    ministryId: m.id,
                    ministryName: m.name,
                    ministrySchedules: const [],
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        ),
      ],
    );
  }
}
