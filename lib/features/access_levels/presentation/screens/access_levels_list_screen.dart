// =====================================================
// CHURCH 360 - TELA DE LISTA DE NÍVEIS DE ACESSO
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/access_level.dart';
import '../providers/access_level_provider.dart';

class AccessLevelsListScreen extends ConsumerStatefulWidget {
  const AccessLevelsListScreen({super.key});

  @override
  ConsumerState<AccessLevelsListScreen> createState() =>
      _AccessLevelsListScreenState();
}

class _AccessLevelsListScreenState
    extends ConsumerState<AccessLevelsListScreen> {
  AccessLevelType? _filterLevel;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final accessLevelsAsync = ref.watch(allAccessLevelsProvider);
    final statsAsync = ref.watch(accessLevelStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Níveis de Acesso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de Promoções',
            onPressed: () => context.push('/access-levels/history'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Estatísticas
          statsAsync.when(
            data: (stats) => _buildStatsCards(stats),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const SizedBox.shrink(),
          ),

          // Filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Busca
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar usuário',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Filtro por nível
                DropdownMenu<AccessLevelType?>(
                  initialSelection: _filterLevel,
                  label: const Text('Filtrar por nível'),
                  dropdownMenuEntries: <DropdownMenuEntry<AccessLevelType?>>[
                    const DropdownMenuEntry<AccessLevelType?>(
                      value: null,
                      label: 'Todos os níveis',
                    ),
                    ...AccessLevelType.values.map((level) {
                      return DropdownMenuEntry<AccessLevelType?>(
                        value: level,
                        label: '${level.icon} ${level.displayName}',
                      );
                    }),
                  ],
                  onSelected: (value) {
                    setState(() {
                      _filterLevel = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Lista de usuários
          Expanded(
            child: accessLevelsAsync.when(
              data: (levels) {
                // Aplicar filtros
                var filteredLevels = levels;

                if (_filterLevel != null) {
                  filteredLevels = filteredLevels
                      .where((l) => l.accessLevel == _filterLevel)
                      .toList();
                }

                if (_searchQuery.isNotEmpty) {
                  filteredLevels = filteredLevels.where((l) {
                    // Aqui você pode adicionar busca por nome do usuário
                    // Por enquanto, vamos buscar pelo ID
                    return l.userId.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (filteredLevels.isEmpty) {
                  return const Center(
                    child: Text('Nenhum usuário encontrado'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredLevels.length,
                  itemBuilder: (context, index) {
                    final level = filteredLevels[index];
                    return _buildUserLevelCard(level);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Erro ao carregar níveis: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<AccessLevelType, int> stats) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        children: AccessLevelType.values.map((level) {
          final count = stats[level] ?? 0;
          return Card(
            margin: const EdgeInsets.only(right: 12),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    level.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserLevelCard(UserAccessLevel level) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getLevelColor(level.accessLevel),
          child: Text(
            level.accessLevel.icon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text('Usuário: ${level.userId.substring(0, 8)}...'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${level.accessLevel.displayName} (Nível ${level.accessLevelNumber})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (level.promotedAt != null)
              Text(
                'Promovido em: ${_formatDate(level.promotedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (level.promotionReason != null)
              Text(
                'Motivo: ${level.promotionReason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Ver histórico',
              onPressed: () {
                context.push('/access-levels/history/${level.userId}');
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar nível',
              onPressed: () {
                _showPromoteDialog(level);
              },
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getLevelColor(AccessLevelType level) {
    switch (level) {
      case AccessLevelType.visitor:
        return Colors.grey;
      case AccessLevelType.attendee:
        return Colors.green.shade200;
      case AccessLevelType.member:
        return Colors.blue;
      case AccessLevelType.leader:
        return Colors.orange;
      case AccessLevelType.coordinator:
        return Colors.purple;
      case AccessLevelType.admin:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showPromoteDialog(UserAccessLevel currentLevel) {
    AccessLevelType? newLevel = currentLevel.accessLevel;
    String? reason;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Nível de Acesso'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuário: ${currentLevel.userId.substring(0, 8)}...'),
              Text('Nível atual: ${currentLevel.accessLevel.displayName}'),
              const SizedBox(height: 16),
              DropdownMenu<AccessLevelType>(
                initialSelection: newLevel,
                label: const Text('Novo nível'),
                dropdownMenuEntries: AccessLevelType.values.map((level) {
                  return DropdownMenuEntry<AccessLevelType>(
                    value: level,
                    label: '${level.icon} ${level.displayName}',
                  );
                }).toList(),
                onSelected: (value) {
                  setState(() {
                    newLevel = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  reason = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (newLevel != null && newLevel != currentLevel.accessLevel) {
                try {
                  final actions = ref.read(accessLevelActionsProvider);
                  await actions.updateUserAccessLevel(
                    userId: currentLevel.userId,
                    newLevel: newLevel!,
                    reason: reason,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nível atualizado com sucesso!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
