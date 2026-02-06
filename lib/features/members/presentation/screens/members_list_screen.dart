import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';
import '../../../tags/presentation/providers/tags_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design/community_design.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Buscar todos os membros
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Column(
        children: [
          // Header com título e botão de novo membro
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
            decoration: BoxDecoration(
              color: CommunityDesign.headerColor(context),
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.people,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestão de Membros',
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Gerencie os membros da comunidade',
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: 'members.create',
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/members/new?status=member_active&type=membro'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo'),
                        style: CommunityDesign.pillButtonStyle(
                          context,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: CommunityDesign.overlayDecoration(
                Theme.of(context).colorScheme,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.search, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Buscar Membros',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText: 'Digite o nome ou apelido...',
                              hintStyle: CommunityDesign.metaStyle(context),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.trim().isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _showInactive,
                          onChanged: (value) =>
                              setState(() => _showInactive = value),
                          activeThumbColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Inativos',
                          style: CommunityDesign.metaStyle(context),
                        ),
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
                var baseMembers = members
                    .where((m) => m.status != 'visitor')
                    .toList();
                var filteredMembers = _showInactive
                    ? baseMembers
                    : baseMembers
                          .where(
                            (m) =>
                                m.status == 'member_active' ||
                                m.status == 'new_convert',
                          )
                          .toList();

                // Filtrar por pesquisa
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredMembers = filteredMembers.where((member) {
                    return member.displayName.toLowerCase().contains(query) ||
                        (member.nickname?.toLowerCase().contains(query) ??
                            false);
                  }).toList();
                }

                // Filtrar por tag (se selecionada)
                if (_selectedTagId != null) {
                  final tagMembersAsync = ref.watch(
                    tagMembersProvider(_selectedTagId!),
                  );
                  return tagMembersAsync.when(
                    data: (tagMemberIds) {
                      filteredMembers = filteredMembers
                          .where((member) => tagMemberIds.contains(member.id))
                          .toList();

                      return _buildMembersGrid(context, filteredMembers);
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Erro ao carregar tags: $error',
                          style: CommunityDesign.metaStyle(
                            context,
                          ).copyWith(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }

                return _buildMembersGrid(context, filteredMembers);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
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
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: CommunityDesign.metaStyle(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(allMembersProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                      style: CommunityDesign.pillButtonStyle(
                        context,
                        Theme.of(context).colorScheme.primary,
                      ),
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
          children: [
            const Icon(Icons.people_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Nenhum membro encontrado',
              style: CommunityDesign.titleStyle(context),
            ),
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

  const _MemberCard({
    required this.member,
    required this.expanded,
    required this.onToggle,
  });

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
        decoration: CommunityDesign.overlayDecoration(
          Theme.of(context).colorScheme,
          hovered: _hovering,
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
                    Builder(
                      builder: (context) {
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
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
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
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            member.displayName,
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                crossFadeState: widget.expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
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
                    _buildInfoRow(
                      Icons.cake,
                      member.age != null
                          ? '${member.age} anos'
                          : 'Idade não informada',
                    ),
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
                        final relsAsync = ref.watch(
                          familyRelationshipsProvider(member.id),
                        );
                        return relsAsync.when(
                          data: (rels) {
                            if (rels.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.family_restroom, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Familiares',
                                      style: CommunityDesign.titleStyle(context)
                                          .copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...rels.map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 24),
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${r.parenteNome ?? r.parenteId} (${r.tipo})',
                                            style:
                                                CommunityDesign.metaStyle(
                                                  context,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                              context.push('/members/${member.id}');
                            },
                            icon: const Icon(Icons.person, size: 18),
                            label: const Text('Ver Perfil'),
                            style: CommunityDesign.pillButtonStyle(
                              context,
                              Theme.of(context).colorScheme.primary,
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
                            style: CommunityDesign.pillButtonStyle(
                              context,
                              Theme.of(context).colorScheme.outline,
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
        Icon(
          icon,
          size: 16,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(text, style: CommunityDesign.metaStyle(context)),
      ],
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
    switch (status) {
      case 'member_active':
        color = Colors.green;
        break;
      case 'visitor':
        color = Colors.blue;
        break;
      case 'new_convert':
        color = Colors.orange;
        break;
      case 'member_inactive':
        color = Colors.grey;
        break;
      case 'transferred':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    String label = status;
    if (status == 'member_active') label = 'Ativo';
    if (status == 'visitor') label = 'Visitante';
    if (status == 'new_convert') label = 'Novo Converte';
    if (status == 'member_inactive') label = 'Inativo';
    if (status == 'transferred') label = 'Transferido';

    return CommunityDesign.badge(context, label, color);
  }
}
