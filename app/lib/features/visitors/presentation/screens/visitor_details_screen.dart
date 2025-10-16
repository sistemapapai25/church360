import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';

/// Tela de detalhes do visitante
class VisitorDetailsScreen extends ConsumerWidget {
  final String visitorId;

  const VisitorDetailsScreen({super.key, required this.visitorId});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(VisitorStatus status) {
    switch (status) {
      case VisitorStatus.firstVisit:
        return Colors.blue;
      case VisitorStatus.returning:
        return Colors.orange;
      case VisitorStatus.regular:
        return Colors.green;
      case VisitorStatus.converted:
        return Colors.purple;
      case VisitorStatus.inactive:
        return Colors.grey;
    }
  }

  Future<void> _convertToMember(BuildContext context, WidgetRef ref, Visitor visitor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Converter em Membro'),
        content: Text(
          'Deseja converter ${visitor.fullName} em membro da igreja?\n\n'
          'Esta ação criará um novo membro com os dados do visitante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Converter'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Criar membro com os dados do visitante
        final memberData = {
          'first_name': visitor.firstName,
          'last_name': visitor.lastName,
          'email': visitor.email,
          'phone': visitor.phone,
          'birth_date': visitor.birthDate?.toIso8601String().split('T')[0],
          'address': visitor.address,
          'city': visitor.city,
          'state': visitor.state,
          'zip_code': visitor.zipCode,
          'membership_status': 'active',
          'join_date': DateTime.now().toIso8601String().split('T')[0],
        };

        final supabase = Supabase.instance.client;
        final memberResponse = await supabase
            .from('member')
            .insert(memberData)
            .select()
            .single();

        final memberId = memberResponse['id'] as String;

        // Atualizar visitante com status convertido
        await ref.read(visitorsRepositoryProvider).convertToMember(visitorId, memberId);

        ref.invalidate(visitorByIdProvider(visitorId));
        ref.invalidate(allVisitorsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitante convertido em membro com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao converter visitante: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitorAsync = ref.watch(visitorByIdProvider(visitorId));
    final visitsAsync = ref.watch(visitorVisitsProvider(visitorId));
    final followupsAsync = ref.watch(visitorFollowupsProvider(visitorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Visitante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/visitors/$visitorId/edit');
            },
            tooltip: 'Editar',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'convert') {
                visitorAsync.whenData((visitor) {
                  if (visitor != null) {
                    _convertToMember(context, ref, visitor);
                  }
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'convert',
                child: Row(
                  children: [
                    Icon(Icons.person_add),
                    SizedBox(width: 8),
                    Text('Converter em Membro'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: visitorAsync.when(
        data: (visitor) {
          if (visitor == null) {
            return const Center(
              child: Text('Visitante não encontrado'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _getStatusColor(visitor.status).withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: _getStatusColor(visitor.status),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        visitor.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(visitor.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          visitor.status.label,
                          style: TextStyle(
                            color: _getStatusColor(visitor.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Contact Info
              if (visitor.email != null || visitor.phone != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contato',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visitor.phone != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 20),
                              const SizedBox(width: 8),
                              Text(visitor.phone!),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (visitor.email != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.email, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(visitor.email!)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Visit Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informações da Visita',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Primeira Visita',
                        value: _formatDate(visitor.firstVisitDate),
                      ),
                      if (visitor.lastVisitDate != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.event,
                          label: 'Última Visita',
                          value: _formatDate(visitor.lastVisitDate!),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.repeat,
                        label: 'Total de Visitas',
                        value: '${visitor.totalVisits}',
                      ),
                      if (visitor.howFound != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.question_mark,
                          label: 'Como conheceu',
                          value: visitor.howFound!.label,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Prayer Request
              if (visitor.prayerRequest != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Pedido de Oração',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(visitor.prayerRequest!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Interests
              if (visitor.interests != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Interesses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(visitor.interests!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes
              if (visitor.notes != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.note),
                            SizedBox(width: 8),
                            Text(
                              'Observações',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(visitor.notes!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Visits History
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Histórico de Visitas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      visitsAsync.when(
                        data: (visits) {
                          if (visits.isEmpty) {
                            return const Text('Nenhuma visita registrada');
                          }
                          return Column(
                            children: visits.map((visit) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      visit.wasContacted
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      size: 16,
                                      color: visit.wasContacted
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_formatDate(visit.visitDate)),
                                    ),
                                    if (visit.wasContacted)
                                      const Text(
                                        'Contatado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, _) => Text('Erro: $error'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Follow-ups
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Follow-ups',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      followupsAsync.when(
                        data: (followups) {
                          if (followups.isEmpty) {
                            return const Text('Nenhum follow-up agendado');
                          }
                          return Column(
                            children: followups.map((followup) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: followup.completed
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            followup.completed
                                                ? Icons.check_circle
                                                : Icons.schedule,
                                            size: 16,
                                            color: followup.completed
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDate(followup.followupDate),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (followup.followupType != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                followup.followupType!,
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (followup.description != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          followup.description!,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, _) => Text('Erro: $error'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erro ao carregar visitante: $error'),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              context.push('/visitors/$visitorId/followup/new');
            },
            icon: const Icon(Icons.event),
            label: const Text('Follow-up'),
            heroTag: 'followup',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () {
              context.push('/visitors/$visitorId/visit/new');
            },
            icon: const Icon(Icons.add),
            label: const Text('Registrar Visita'),
            heroTag: 'visit',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

