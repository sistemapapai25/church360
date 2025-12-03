import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/church_schedule.dart';
import '../providers/church_schedule_provider.dart';
import 'church_schedule_form_screen.dart';

/// Tela de listagem de agendas da igreja
class ChurchScheduleListScreen extends ConsumerStatefulWidget {
  const ChurchScheduleListScreen({super.key});

  @override
  ConsumerState<ChurchScheduleListScreen> createState() => _ChurchScheduleListScreenState();
}

class _ChurchScheduleListScreenState extends ConsumerState<ChurchScheduleListScreen> {
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = _showInactive
        ? ref.watch(allChurchSchedulesProvider)
        : ref.watch(activeChurchSchedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda da Igreja'),
        actions: [
          IconButton(
            icon: Icon(
              _showInactive ? Icons.visibility : Icons.visibility_off,
              color: _showInactive ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: _showInactive ? 'Ocultar inativos' : 'Mostrar inativos',
            onPressed: () {
              setState(() {
                _showInactive = !_showInactive;
              });
            },
          ),
        ],
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma agenda encontrada',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie a primeira agenda da igreja',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeChurchSchedulesProvider);
              ref.invalidate(allChurchSchedulesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return _ScheduleCard(
                  schedule: schedule,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChurchScheduleFormScreen(scheduleId: schedule.id),
                      ),
                    );
                  },
                  onDelete: () => _confirmDelete(context, schedule),
                  onToggleActive: () => _toggleActive(schedule),
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
              Text('Erro ao carregar agendas: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(activeChurchSchedulesProvider);
                  ref.invalidate(allChurchSchedulesProvider);
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
              builder: (context) => const ChurchScheduleFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Agenda'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ChurchSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir "${schedule.title}"?'),
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(deleteChurchScheduleProvider)(schedule.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agenda excluída com sucesso')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir agenda: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(ChurchSchedule schedule) async {
    try {
      await ref.read(toggleChurchScheduleActiveProvider)(
        schedule.id,
        !schedule.isActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              schedule.isActive
                  ? 'Agenda desativada'
                  : 'Agenda ativada',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar status: $e')),
        );
      }
    }
  }
}

/// Card de agenda
class _ScheduleCard extends StatelessWidget {
  final ChurchSchedule schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleType = ScheduleType.fromValue(schedule.scheduleType);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Opacity(
      opacity: schedule.isActive ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título e tipo
              Row(
                children: [
                  Expanded(
                    child: Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      scheduleType.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),

              if (schedule.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  schedule.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Data e hora
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(schedule.startDatetime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${timeFormat.format(schedule.startDatetime)} - ${timeFormat.format(schedule.endDatetime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              if (schedule.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.location!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(
                      schedule.isActive ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(schedule.isActive ? 'Desativar' : 'Ativar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
