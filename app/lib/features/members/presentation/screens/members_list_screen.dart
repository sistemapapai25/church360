import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';
import '../../../tags/presentation/providers/tags_provider.dart';

/// Tela de listagem de membros
class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, visitor

  @override
  Widget build(BuildContext context) {
    // Buscar membros baseado no filtro
    final membersAsync = _selectedFilter == 'member_active'
        ? ref.watch(activeMembersProvider)
        : _selectedFilter == 'visitor'
            ? ref.watch(visitorsProvider)
            : ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membros'),
        actions: [
          // Botão de filtro
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Todos'),
              ),
              const PopupMenuItem(
                value: 'member_active',
                child: Text('Ativos'),
              ),
              const PopupMenuItem(
                value: 'visitor',
                child: Text('Visitantes'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de pesquisa
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar membros...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Lista de membros
          Expanded(
            child: membersAsync.when(
              data: (members) {
                // Filtrar por pesquisa
                final filteredMembers = _searchQuery.isEmpty
                    ? members
                    : members.where((member) {
                        final query = _searchQuery.toLowerCase();
                        return member.fullName.toLowerCase().contains(query) ||
                            (member.email?.toLowerCase().contains(query) ?? false);
                      }).toList();

                if (filteredMembers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum membro encontrado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return _MemberListTile(member: member);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar membros',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(allMembersProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/members/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget de item da lista de membros
class _MemberListTile extends ConsumerWidget {
  final Member member;

  const _MemberListTile({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberTagsAsync = ref.watch(memberTagsProvider(member.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            member.firstName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      member.email!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (member.phone != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    member.phone!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
            if (member.age != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.cake, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${member.age} anos',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
            // Tags do membro
            memberTagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tag.colorValue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tag.colorValue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tag.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: tag.colorValue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        trailing: _StatusChip(status: member.status),
        onTap: () {
          context.push('/members/${member.id}');
        },
      ),
    );
  }
}

/// Chip de status do membro
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'member_active':
        color = Colors.green;
        label = 'Ativo';
        break;
      case 'visitor':
        color = Colors.blue;
        label = 'Visitante';
        break;
      case 'new_convert':
        color = Colors.purple;
        label = 'Novo Convertido';
        break;
      case 'member_inactive':
        color = Colors.grey;
        label = 'Inativo';
        break;
      case 'transferred':
        color = Colors.orange;
        label = 'Transferido';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

