import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/groups_provider.dart';
import '../../domain/models/group.dart';

/// Tela de detalhes do grupo
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Grupo'),
        actions: [
          // Botão de editar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navegar para tela de edição
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Editar - Em breve!')),
              );
            },
          ),
          // Botão de deletar
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(
              child: Text('Grupo não encontrado'),
            );
          }
          return _GroupDetailContent(group: group);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar grupo: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupByIdProvider(groupId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Grupo'),
        content: const Text(
          'Tem certeza que deseja deletar este grupo?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(groupsRepositoryProvider);
      await repo.deleteGroup(groupId);

      if (context.mounted) {
        ref.invalidate(allGroupsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupo deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar grupo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Conteúdo da tela de detalhes
class _GroupDetailContent extends ConsumerWidget {
  final Group group;

  const _GroupDetailContent({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header com informações do grupo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                // Ícone
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(
                    Icons.group,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nome
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Status
                if (!group.isActive)
                  Chip(
                    label: const Text(
                      'Inativo',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.grey,
                  ),
                
                const SizedBox(height: 16),
                
                // Contagem de membros
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.memberCount ?? 0} membros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            tabs: const [
              Tab(text: 'Informações', icon: Icon(Icons.info_outline)),
              Tab(text: 'Membros', icon: Icon(Icons.people_outline)),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                _InfoTab(group: group),
                _MembersTab(groupId: group.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab de informações
class _InfoTab extends StatelessWidget {
  final Group group;

  const _InfoTab({required this.group});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descrição
          if (group.description != null && group.description!.isNotEmpty) ...[
            _SectionTitle(title: 'Descrição'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(group.description!),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Líder
          if (group.leaderName != null) ...[
            _SectionTitle(title: 'Liderança'),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.person,
              label: 'Líder',
              value: group.leaderName!,
            ),
            const SizedBox(height: 24),
          ],
          
          // Informações de Reunião
          _SectionTitle(title: 'Reuniões'),
          const SizedBox(height: 12),
          if (group.meetingDayName != null)
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Dia da Semana',
              value: group.meetingDayName!,
            ),
          if (group.meetingTime != null)
            _InfoTile(
              icon: Icons.access_time,
              label: 'Horário',
              value: group.meetingTime!,
            ),
          if (group.meetingAddress != null)
            _InfoTile(
              icon: Icons.location_on,
              label: 'Local',
              value: group.meetingAddress!,
            ),
        ],
      ),
    );
  }
}

/// Tab de membros
class _MembersTab extends ConsumerWidget {
  final String groupId;

  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
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
                  'Nenhum membro neste grupo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.memberName?.substring(0, 1).toUpperCase() ?? '?',
                  ),
                ),
                title: Text(member.memberName ?? 'Nome não disponível'),
                subtitle: member.role != null && member.role != 'member'
                    ? Text(
                        member.role == 'leader' ? 'Líder' : member.role!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      )
                    : null,
                trailing: Text(
                  'Desde ${DateFormat('dd/MM/yyyy').format(member.joinedDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar membros: $error'),
      ),
    );
  }
}

/// Título de seção
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

/// Tile de informação
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

