import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';
import '../../../tags/presentation/providers/tags_provider.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../access_levels/domain/models/access_level.dart';

/// Tela de listagem de membros
class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, visitor
  String? _selectedTagId; // null = sem filtro de tag

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
          // Botão de filtro por tag
          IconButton(
            icon: Icon(
              Icons.label,
              color: _selectedTagId != null ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filtrar por tag',
            onPressed: () => _showTagFilterDialog(context),
          ),
          // Botão de filtro por status
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
                var filteredMembers = _searchQuery.isEmpty
                    ? members
                    : members.where((member) {
                        final query = _searchQuery.toLowerCase();
                        return member.fullName.toLowerCase().contains(query) ||
                            (member.email?.toLowerCase().contains(query) ?? false);
                      }).toList();

                // Filtrar por tag (se selecionada)
                if (_selectedTagId != null) {
                  final tagMembersAsync = ref.watch(tagMembersProvider(_selectedTagId!));
                  return tagMembersAsync.when(
                    data: (tagMemberIds) {
                      filteredMembers = filteredMembers
                          .where((member) => tagMemberIds.contains(member.id))
                          .toList();

                      return _buildMembersList(context, filteredMembers);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Erro: $error')),
                  );
                }

                return _buildMembersList(context, filteredMembers);
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
      floatingActionButton: LeaderOnlyWidget(
        child: FloatingActionButton(
          onPressed: () {
            context.push('/members/new');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, List<Member> filteredMembers) {
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
  }

  void _showTagFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TagFilterDialog(
        selectedTagId: _selectedTagId,
        onTagSelected: (tagId) {
          setState(() {
            _selectedTagId = tagId;
          });
        },
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

/// Dialog para filtrar membros por tag
class _TagFilterDialog extends ConsumerWidget {
  final String? selectedTagId;
  final Function(String?) onTagSelected;

  const _TagFilterDialog({
    required this.selectedTagId,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTagsAsync = ref.watch(allTagsProvider);

    return AlertDialog(
      title: const Text('Filtrar por Tag'),
      content: allTagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Text('Nenhuma tag disponível.');
          }

          return SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // Opção "Todas" (sem filtro)
                ListTile(
                  leading: Icon(
                    selectedTagId == null ? Icons.check_circle : Icons.circle_outlined,
                    color: selectedTagId == null ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: const Text('Todas (sem filtro)'),
                  onTap: () {
                    onTagSelected(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                // Lista de tags
                ...tags.map((tag) {
                  final isSelected = selectedTagId == tag.id;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? tag.colorValue : null,
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: tag.colorValue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(tag.name),
                      ],
                    ),
                    subtitle: tag.memberCount != null
                        ? Text('${tag.memberCount} membros')
                        : null,
                    onTap: () {
                      onTagSelected(tag.id);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('Erro: $error'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
