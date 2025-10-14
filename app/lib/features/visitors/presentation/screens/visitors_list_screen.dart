import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../data/visitors_repository.dart';

/// Tela de listagem de visitantes
class VisitorsListScreen extends ConsumerStatefulWidget {
  const VisitorsListScreen({super.key});

  @override
  ConsumerState<VisitorsListScreen> createState() => _VisitorsListScreenState();
}

class _VisitorsListScreenState extends ConsumerState<VisitorsListScreen> {
  String _searchQuery = '';
  VisitorStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(allVisitorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitantes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              // TODO: Navegar para estatísticas
            },
            tooltip: 'Estatísticas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar visitante...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: _filterStatus == null,
                        onSelected: (selected) {
                          setState(() {
                            _filterStatus = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...VisitorStatus.values.map((status) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status.label),
                            selected: _filterStatus == status,
                            onSelected: (selected) {
                              setState(() {
                                _filterStatus = selected ? status : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Visitors list
          Expanded(
            child: visitorsAsync.when(
              data: (visitors) {
                // Apply filters
                var filteredVisitors = visitors;

                if (_searchQuery.isNotEmpty) {
                  filteredVisitors = filteredVisitors.where((visitor) {
                    return visitor.fullName.toLowerCase().contains(_searchQuery) ||
                        (visitor.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (visitor.phone?.contains(_searchQuery) ?? false);
                  }).toList();
                }

                if (_filterStatus != null) {
                  filteredVisitors = filteredVisitors
                      .where((visitor) => visitor.status == _filterStatus)
                      .toList();
                }

                if (filteredVisitors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterStatus != null
                              ? 'Nenhum visitante encontrado'
                              : 'Nenhum visitante cadastrado',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isEmpty && _filterStatus == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Clique no botão + para adicionar',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredVisitors.length,
                  itemBuilder: (context, index) {
                    final visitor = filteredVisitors[index];
                    return _VisitorCard(visitor: visitor);
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
                    Text('Erro ao carregar visitantes: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(allVisitorsProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/visitors/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Visitante'),
      ),
    );
  }
}

/// Card de visitante
class _VisitorCard extends ConsumerWidget {
  final Visitor visitor;

  const _VisitorCard({required this.visitor});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _deleteVisitor(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Visitante'),
        content: Text(
          'Tem certeza que deseja excluir ${visitor.fullName}? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(visitorsRepositoryProvider).deleteVisitor(visitor.id);
        ref.invalidate(allVisitorsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitante excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir visitante: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/visitors/${visitor.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(visitor.status).withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person,
                      color: _getStatusColor(visitor.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visitor.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(visitor.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            visitor.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(visitor.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push('/visitors/${visitor.id}/edit');
                      } else if (value == 'delete') {
                        _deleteVisitor(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact info
              if (visitor.phone != null) ...[
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      visitor.phone!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              if (visitor.email != null) ...[
                Row(
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      visitor.email!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Primeira visita: ${_formatDate(visitor.firstVisitDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${visitor.totalVisits} visita${visitor.totalVisits != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
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
}

