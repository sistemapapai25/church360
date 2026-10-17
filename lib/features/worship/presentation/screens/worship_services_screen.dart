import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../providers/worship_provider.dart';
import '../../domain/models/worship_service.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/layout/responsive_grid.dart';

/// Tela de listagem de cultos
class WorshipServicesScreen extends ConsumerWidget {
  const WorshipServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(allWorshipServicesProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Cultos',
          style: CommunityDesign.titleStyle(context),
        ),
        actions: [
          PermissionGate(
            permission: 'worship.view_statistics',
            showLoading: false,
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                context.push('/worship-statistics');
              },
              tooltip: 'Estatísticas',
            ),
          ),
        ],
      ),
      body: servicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.church,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum culto na Agenda',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os cultos vêm da Agenda (eventos do tipo Culto).',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ResponsiveGridList(
            rowGap: 0,
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return _WorshipServiceCard(service: service);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar cultos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(allWorshipServicesProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: PermissionGate(
        permission: 'events.create',
        child: PearlFab(
          onPressed: () {
            context.push('/events/new');
          },
          icon: Icons.add,
          label: 'Novo culto na Agenda',
        ),
      ),
    );
  }
}

/// Card de culto
class _WorshipServiceCard extends ConsumerWidget {
  final WorshipService service;

  const _WorshipServiceCard({required this.service});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref
        .watch(currentUserHasPermissionProvider('events.edit'))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final canAttend = ref
        .watch(currentUserHasPermissionProvider('worship.attendance'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canAttend
            ? () => context.push('/worship-services/${service.id}/attendance')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com data e tipo
              Row(
                children: [
                  // Ícone do tipo de culto
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(service.serviceType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(service.serviceType),
                    color: _getTypeColor(service.serviceType),
                    size: 24,
                  ),
                  ),
                  const SizedBox(width: 12),
                  // Data e tipo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(service.serviceDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          service.serviceType.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Horário
                  if (service.serviceTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            service.serviceTime!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Menu de opções
                  // Editar e excluir são pela Agenda.
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: 'Editar na Agenda',
                      onPressed: () => context.push('/events/${service.id}/edit'),
                    ),
                ],
              ),
              
              // Tema
              if (service.theme != null) ...[
                const SizedBox(height: 12),
                Text(
                  service.theme!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              // Pregador
              if (service.speaker != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      service.speaker!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Footer com presença
              Row(
                children: [
                  Icon(Icons.groups, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${service.totalAttendance} presente${service.totalAttendance != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (canAttend)
                    TextButton.icon(
                    onPressed: () {
                      context.push('/worship-services/${service.id}/attendance');
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Check-in'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(WorshipType type) {
    switch (type) {
      case WorshipType.sunday:
        return Colors.orange;
      case WorshipType.wednesday:
        return Colors.blue;
      case WorshipType.communion:
        return Colors.red;
      case WorshipType.drops:
        return Colors.purple;
      case WorshipType.other:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(WorshipType type) {
    switch (type) {
      case WorshipType.sunday:
        return Icons.wb_sunny;
      case WorshipType.wednesday:
        return Icons.menu_book;
      case WorshipType.communion:
        return Icons.local_drink;
      case WorshipType.drops:
        return Icons.water_drop;
      case WorshipType.other:
        return Icons.church;
    }
  }
}
