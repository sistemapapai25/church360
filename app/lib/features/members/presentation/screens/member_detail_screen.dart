import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/permission_widget.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';
import '../../../tags/presentation/providers/tags_provider.dart';
import '../../../tags/data/tags_repository.dart';

/// Tela de detalhes do membro
class MemberDetailScreen extends ConsumerWidget {
  final String memberId;

  const MemberDetailScreen({
    super.key,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberByIdProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Membro'),
        actions: [
          // Botão de editar (apenas Líderes+)
          LeaderOnlyWidget(
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/members/$memberId/edit');
              },
            ),
          ),
          // Botão de deletar (apenas Coordenadores+)
          CoordinatorOnlyWidget(
            child: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(context, ref),
            ),
          ),
        ],
      ),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(
              child: Text('Membro não encontrado'),
            );
          }
          return _MemberDetailContent(member: member);
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
              Text('Erro ao carregar membro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(memberByIdProvider(memberId)),
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
        title: const Text('Deletar Membro'),
        content: const Text(
          'Tem certeza que deseja deletar este membro?\n\n'
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
              await _deleteMember(context, ref);
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

  Future<void> _deleteMember(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(membersRepositoryProvider);
      await repo.deleteMember(memberId);

      if (context.mounted) {
        // Invalida a lista de membros para atualizar
        ref.invalidate(allMembersProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Volta para a lista
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar membro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Conteúdo da tela de detalhes
class _MemberDetailContent extends ConsumerWidget {
  final Member member;

  const _MemberDetailContent({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header com foto e nome
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                // Foto
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    member.firstName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nome
                Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Status
                _StatusChip(status: member.status),
              ],
            ),
          ),

          // Informações
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informações de Contato
                _SectionTitle(title: 'Contato'),
                const SizedBox(height: 12),
                if (member.email != null)
                  _InfoTile(
                    icon: Icons.email,
                    label: 'Email',
                    value: member.email!,
                  ),
                if (member.phone != null)
                  _InfoTile(
                    icon: Icons.phone,
                    label: 'Telefone',
                    value: member.phone!,
                  ),

                const SizedBox(height: 24),

                // Tags
                _TagsSection(memberId: member.id),

                const SizedBox(height: 24),

                // Informações Pessoais
                _SectionTitle(title: 'Informações Pessoais'),
                const SizedBox(height: 12),
                if (member.birthdate != null)
                  _InfoTile(
                    icon: Icons.cake,
                    label: 'Data de Nascimento',
                    value: DateFormat('dd/MM/yyyy').format(member.birthdate!),
                    trailing: member.age != null ? '${member.age} anos' : null,
                  ),
                if (member.gender != null)
                  _InfoTile(
                    icon: Icons.person,
                    label: 'Gênero',
                    value: member.gender == 'male' ? 'Masculino' : 'Feminino',
                  ),
                if (member.maritalStatus != null)
                  _InfoTile(
                    icon: Icons.favorite,
                    label: 'Estado Civil',
                    value: _getMaritalStatusLabel(member.maritalStatus!),
                  ),
                
                const SizedBox(height: 24),
                
                // Endereço
                if (member.address != null) ...[
                  _SectionTitle(title: 'Endereço'),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.location_on,
                    label: 'Endereço',
                    value: member.address!,
                  ),
                  if (member.city != null && member.state != null)
                    _InfoTile(
                      icon: Icons.location_city,
                      label: 'Cidade/Estado',
                      value: '${member.city}, ${member.state}',
                    ),
                  if (member.zipCode != null)
                    _InfoTile(
                      icon: Icons.pin_drop,
                      label: 'CEP',
                      value: member.zipCode!,
                    ),
                  const SizedBox(height: 24),
                ],
                
                // Datas Importantes
                _SectionTitle(title: 'Datas Importantes'),
                const SizedBox(height: 12),
                if (member.membershipDate != null)
                  _InfoTile(
                    icon: Icons.event,
                    label: 'Membro desde',
                    value: DateFormat('dd/MM/yyyy').format(member.membershipDate!),
                  ),
                if (member.conversionDate != null)
                  _InfoTile(
                    icon: Icons.auto_awesome,
                    label: 'Data de Conversão',
                    value: DateFormat('dd/MM/yyyy').format(member.conversionDate!),
                  ),
                if (member.baptismDate != null)
                  _InfoTile(
                    icon: Icons.water_drop,
                    label: 'Data de Batismo',
                    value: DateFormat('dd/MM/yyyy').format(member.baptismDate!),
                  ),
                
                const SizedBox(height: 24),
                
                // Notas
                if (member.notes != null && member.notes!.isNotEmpty) ...[
                  _SectionTitle(title: 'Observações'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(member.notes!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMaritalStatusLabel(String status) {
    switch (status) {
      case 'single':
        return 'Solteiro(a)';
      case 'married':
        return 'Casado(a)';
      case 'divorced':
        return 'Divorciado(a)';
      case 'widowed':
        return 'Viúvo(a)';
      default:
        return status;
    }
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
  final String? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
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
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Chip de status
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
        label = 'Membro Ativo';
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
        label = 'Membro Inativo';
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
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
    );
  }
}

/// Seção de Tags do Membro
class _TagsSection extends ConsumerWidget {
  final String memberId;

  const _TagsSection({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberTagsAsync = ref.watch(memberTagsProvider(memberId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Tags'),
            TextButton.icon(
              onPressed: () => _showAddTagDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        memberTagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return const Text(
                'Nenhuma tag atribuída',
                style: TextStyle(color: Colors.grey),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Chip(
                  label: Text(tag.name),
                  backgroundColor: tag.colorValue.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: tag.colorValue,
                    fontWeight: FontWeight.bold,
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 18,
                    color: tag.colorValue,
                  ),
                  onDeleted: () => _removeTag(context, ref, tag.id, tag.name),
                );
              }).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text('Erro: $error'),
        ),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddTagDialog(memberId: memberId),
    );
  }

  Future<void> _removeTag(
    BuildContext context,
    WidgetRef ref,
    String tagId,
    String tagName,
  ) async {
    try {
      await ref.read(tagsRepositoryProvider).removeTagFromMember(memberId, tagId);
      ref.invalidate(memberTagsProvider(memberId));
      ref.invalidate(allMembersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tag "$tagName" removida com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover tag: $e')),
        );
      }
    }
  }
}

/// Dialog para adicionar tag ao membro
class _AddTagDialog extends ConsumerStatefulWidget {
  final String memberId;

  const _AddTagDialog({required this.memberId});

  @override
  ConsumerState<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends ConsumerState<_AddTagDialog> {
  String? _selectedTagId;

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final memberTagsAsync = ref.watch(memberTagsProvider(widget.memberId));

    return AlertDialog(
      title: const Text('Adicionar Tag'),
      content: allTagsAsync.when(
        data: (allTags) {
          return memberTagsAsync.when(
            data: (memberTags) {
              // Filtrar tags que o membro já possui
              final memberTagIds = memberTags.map((t) => t.id).toSet();
              final availableTags = allTags.where((t) => !memberTagIds.contains(t.id)).toList();

              if (availableTags.isEmpty) {
                return const Text('Todas as tags já foram atribuídas a este membro.');
              }

              return DropdownButtonFormField<String>(
                initialValue: _selectedTagId,
                decoration: const InputDecoration(
                  labelText: 'Selecione uma tag',
                  border: OutlineInputBorder(),
                ),
                items: availableTags.map((tag) {
                  return DropdownMenuItem(
                    value: tag.id,
                    child: Row(
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
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedTagId = value);
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Erro: $error'),
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (error, _) => Text('Erro: $error'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedTagId == null ? null : _addTag,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addTag() async {
    if (_selectedTagId == null) return;

    try {
      await ref.read(tagsRepositoryProvider).addTagToMember(widget.memberId, _selectedTagId!);
      ref.invalidate(memberTagsProvider(widget.memberId));
      ref.invalidate(allMembersProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag adicionada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar tag: $e')),
        );
      }
    }
  }
}

