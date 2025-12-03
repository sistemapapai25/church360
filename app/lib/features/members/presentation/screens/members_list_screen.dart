import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';
import '../../../tags/presentation/providers/tags_provider.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de listagem de membros
class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  String _searchQuery = '';
  bool _showInactive = false; // Toggle para mostrar inativos/desligados
  String? _selectedTagId; // null = sem filtro de tag
  String? _expandedMemberId; // controla qual card está expandido

  @override
  Widget build(BuildContext context) {
    // Buscar todos os membros
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header com título e botão de novo membro
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Gestão de Membros',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    LeaderOnlyWidget(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/members/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo Membro'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gerencie os membros da comunidade',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.gradientCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppTheme.shadowMd],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.search, size: 20),
                        SizedBox(width: 8),
                        Text('Buscar Membros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Digite o nome ou apelido...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              filled: true,
                              fillColor: AppTheme.input,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.border),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _showInactive,
                          onChanged: (value) => setState(() => _showInactive = value),
                          activeThumbColor: AppTheme.primary,
                          activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 8),
                        const Text('Exibir membros inativos'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),


          // Lista de membros
          Expanded(
            child: membersAsync.when(
              data: (members) {
                // Filtrar por status (mostrar/ocultar inativos)
                var filteredMembers = _showInactive
                    ? members
                    : members.where((member) {
                        return member.status == 'member_active' ||
                            member.status == 'visitor' ||
                            member.status == 'new_convert';
                      }).toList();

                // Filtrar por pesquisa
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredMembers = filteredMembers.where((member) {
                    return member.displayName.toLowerCase().contains(query) ||
                        (member.nickname?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                // Filtrar por tag (se selecionada)
                if (_selectedTagId != null) {
                  final tagMembersAsync = ref.watch(tagMembersProvider(_selectedTagId!));
                  return tagMembersAsync.when(
                    data: (tagMemberIds) {
                      filteredMembers = filteredMembers
                          .where((member) => tagMemberIds.contains(member.id))
                          .toList();

                      return _buildMembersGrid(context, filteredMembers);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Erro: $error')),
                  );
                }

                return _buildMembersGrid(context, filteredMembers);
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
    );
  }

  Widget _buildMembersGrid(BuildContext context, List<Member> filteredMembers) {
    if (filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.people_outline, size: 64),
            SizedBox(height: 16),
            Text('Nenhum membro encontrado'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: filteredMembers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final member = filteredMembers[index];
        return _MemberCard(
          member: member,
          expanded: _expandedMemberId == member.id,
          onToggle: (id) {
            setState(() {
              _expandedMemberId = _expandedMemberId == id ? null : id;
            });
          },
        );
      },
    );
  }

}

/// Widget de card de membro com design rico
class _MemberCard extends ConsumerStatefulWidget {
  final Member member;
  final bool expanded;
  final ValueChanged<String> onToggle;

  const _MemberCard({required this.member, required this.expanded, required this.onToggle});

  @override
  ConsumerState<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends ConsumerState<_MemberCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: AppTheme.gradientCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            _hovering ? AppTheme.shadowPrimary : AppTheme.shadowMd,
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onToggle(widget.member.id),
                child: Row(
                  children: [
                    Builder(builder: (context) {
                      final rawUrl = member.photoUrl;
                      String? resolvedUrl;
                      if (rawUrl != null && rawUrl.isNotEmpty) {
                        final parsed = Uri.tryParse(rawUrl);
                        if (parsed != null && parsed.hasScheme) {
                          resolvedUrl = rawUrl;
                        } else {
                          resolvedUrl = Supabase.instance.client.storage
                              .from('member-photos')
                              .getPublicUrl(rawUrl);
                        }
                      }

                      return CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: resolvedUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  resolvedUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      member.initials,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                member.initials,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                      );
                    }),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            member.displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          _StatusBadge(status: member.status),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: widget.expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: widget.expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, member.email),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.phone, member.phone ?? 'Sem telefone'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.person,
                      member.gender == 'male'
                          ? 'Masculino'
                          : member.gender == 'female'
                              ? 'Feminino'
                              : 'Não informado',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.cake, member.age != null ? '${member.age} anos' : 'Idade não informada'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.location_on,
                      member.city != null
                          ? '${member.city}${member.state != null ? ' - ${member.state}' : ''}'
                          : (member.state ?? 'Não informado'),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        final relsAsync = ref.watch(familyRelationshipsProvider(member.id));
                        return relsAsync.when(
                          data: (rels) {
                            if (rels.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.family_restroom, size: 16),
                                    SizedBox(width: 8),
                                    Text('Familiares', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...rels.map((r) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 24),
                                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${r.parenteNome ?? r.parenteId} (${r.tipo})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showMemberDialog(context, ref, member);
                            },
                            icon: const Icon(Icons.person, size: 18),
                            label: const Text('Ver Perfil'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.primaryForeground,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.push('/members/${member.id}/edit');
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Editar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.foreground,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _showMemberDialog(BuildContext context, WidgetRef ref, Member member) {
    showDialog(
      context: context,
      builder: (context) => _MemberDetailDialog(member: member),
    );
  }
}

/// Badge de status do membro (pequeno)
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

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
        color = Colors.orange;
        label = 'Membro';
        break;
      case 'member_inactive':
        color = Colors.grey;
        label = 'Inativo';
        break;
      case 'transferred':
        color = Colors.purple;
        label = 'Transferido';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Dialog de detalhes do membro (PASSO 2)
class _MemberDetailDialog extends ConsumerWidget {
  final Member member;

  const _MemberDetailDialog({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com foto, nome e status
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF5B4FC0).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Foto
                  Builder(builder: (context) {
                    final rawUrl = member.photoUrl;
                    String? resolvedUrl;
                    if (rawUrl != null && rawUrl.isNotEmpty) {
                      final parsed = Uri.tryParse(rawUrl);
                      if (parsed != null && parsed.hasScheme) {
                        resolvedUrl = rawUrl;
                      } else {
                        resolvedUrl = Supabase.instance.client.storage
                            .from('member-photos')
                            .getPublicUrl(rawUrl);
                      }
                    }

                    return CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: resolvedUrl != null
                          ? ClipOval(
                              child: Image.network(
                                resolvedUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    member.initials,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5B4FC0),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              member.initials,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B4FC0),
                              ),
                            ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Nome
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Apelido
                  if (member.nickname != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${member.nickname}"',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Status
                  _StatusBadge(status: member.status),
                ],
              ),
            ),
            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações Pessoais
                    _buildSectionTitle('Informações Pessoais'),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.phone,
                      'Telefone',
                      member.phone ?? 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.cake,
                      'Data de Nascimento',
                      member.birthdate != null
                          ? '${member.birthdate!.day.toString().padLeft(2, '0')}/${member.birthdate!.month.toString().padLeft(2, '0')}/${member.birthdate!.year}${member.age != null ? ' (${member.age} anos)' : ''}'
                          : 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.person,
                      'Gênero',
                      member.gender == 'male'
                          ? 'Masculino'
                          : member.gender == 'female'
                              ? 'Feminino'
                              : 'Não informado',
                    ),
                    Builder(
                      builder: (_) {
                        if (member.profession == null) {
                          return _buildInfoItem(Icons.work, 'Profissão', 'Não informado');
                        }
                        final labelAsync = ref.watch(professionLabelProvider(member.profession!));
                        return labelAsync.when(
                          data: (label) => _buildInfoItem(Icons.work, 'Profissão', label ?? member.profession!),
                          loading: () => _buildInfoItem(Icons.work, 'Profissão', 'Carregando...'),
                          error: (_, __) => _buildInfoItem(Icons.work, 'Profissão', member.profession!),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Endereço
                    _buildSectionTitle('Endereço'),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.pin_drop,
                      'CEP',
                      member.zipCode ?? 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.location_on,
                      'Endereço',
                      member.address != null
                          ? '${member.address}${member.neighborhood != null ? ', ${member.neighborhood}' : ''}'
                          : 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.location_city,
                      'Cidade/UF',
                      member.city != null && member.state != null
                          ? '${member.city} - ${member.state}'
                          : member.state ?? 'Não informado',
                    ),
                    // Link Google Maps
                    if (member.address != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final address = Uri.encodeComponent(
                            '${member.address}, ${member.city ?? ''}, ${member.state ?? ''}',
                          );
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Row(
                          children: [
                            const SizedBox(width: 32),
                            Icon(Icons.map, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Ver no Google Maps',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Familiares
                    if (member.householdId != null) ...[
                      const SizedBox(height: 24),
                      _buildFamilySection(ref, member.householdId!),
                    ],
                  ],
                ),
              ),
            ),
            // Botões de ação
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/members/${member.id}/profile');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Perfil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Fechar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilySection(WidgetRef ref, String householdId) {
    final householdMembersAsync = ref.watch(householdMembersProvider(householdId));

    return householdMembersAsync.when(
      data: (familyMembers) {
        // Remover o próprio membro da lista
        final otherMembers = familyMembers.where((m) => m.id != member.id).toList();

        if (otherMembers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Familiares'),
            const SizedBox(height: 12),
            ...otherMembers.map((familyMember) {
              // Determinar relacionamento baseado em idade/gênero
              String relationship = 'Familiar';
              if (familyMember.age != null && member.age != null) {
                if (familyMember.age! > member.age! + 15) {
                  relationship = familyMember.gender == 'male' ? 'Pai' : 'Mãe';
                } else if (familyMember.age! < member.age! - 15) {
                  relationship = familyMember.gender == 'male' ? 'Filho' : 'Filha';
                } else {
                  relationship = 'Cônjuge';
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${familyMember.displayName} ($relationship)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
