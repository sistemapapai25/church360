import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/design/community_design.dart';
import '../../../permissions/providers/permissions_providers.dart';

import '../providers/ministries_provider.dart';
import '../../domain/models/ministry.dart';

/// Tela de listagem de ministérios
class MinistriesListScreen extends ConsumerStatefulWidget {
  const MinistriesListScreen({super.key});

  @override
  ConsumerState<MinistriesListScreen> createState() =>
      _MinistriesListScreenState();
}

class _MinistriesListScreenState extends ConsumerState<MinistriesListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreateAsync = ref.watch(currentUserHasPermissionProvider('ministries.create'));
    final canEditAsync = ref.watch(currentUserHasPermissionProvider('ministries.edit'));
    final canDeleteAsync = ref.watch(currentUserHasPermissionProvider('ministries.delete'));

    final canSeeAll = canCreateAsync.maybeWhen(data: (v) => v, orElse: () => false) ||
        canEditAsync.maybeWhen(data: (v) => v, orElse: () => false) ||
        canDeleteAsync.maybeWhen(data: (v) => v, orElse: () => false);

    final ministriesAsync = canSeeAll
        ? ref.watch(allMinistriesProvider)
        : ref.watch(currentMemberMinistriesProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Column(
        children: [
          // Header com título e botão de novo ministério
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
                        Icons.church,
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
                            'Ministérios',
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Gerencie os ministérios da comunidade',
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ],
                      ),
                    ),
                    canCreateAsync.maybeWhen(
                      data: (canCreate) => canCreate
                          ? ElevatedButton.icon(
                              onPressed: () => context.push('/ministries/new'),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Novo'),
                              style: CommunityDesign.pillButtonStyle(
                                context,
                                Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ministriesAsync.when(
              data: (ministries) {
                final filtered = ministries.where((m) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  final name = m.name.toLowerCase();
                  final desc = (m.description ?? '').toLowerCase();
                  return name.contains(q) || desc.contains(q);
                }).toList()..sort((a, b) => a.name.compareTo(b.name));

                if (ministries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.church_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          canSeeAll
                              ? 'Nenhum ministério cadastrado'
                              : 'Você não possui ministérios vinculados',
                          style: CommunityDesign.titleStyle(context),
                        ),
                        const SizedBox(height: 24),
                        canCreateAsync.maybeWhen(
                          data: (canCreate) => canCreate
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/ministries/new');
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text(
                                    'Criar Primeiro Ministério',
                                  ),
                                  style: CommunityDesign.pillButtonStyle(
                                    context,
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
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
                                    'Buscar Ministérios',
                                    style: CommunityDesign.titleStyle(context)
                                        .copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Digite o nome ou descrição...',
                                  hintStyle: CommunityDesign.metaStyle(context),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 0,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final ministry = filtered[index];
                          return _MinistryCard(ministry: ministry);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar ministérios',
                        style: CommunityDesign.titleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: CommunityDesign.metaStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(allMinistriesProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tentar Novamente'),
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
          ),
        ],
      ),
    );
  }
}

/// Card de ministério
class _MinistryCard extends ConsumerWidget {
  final Ministry ministry;

  const _MinistryCard({required this.ministry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Converter cor hexadecimal para Color
    final colorHex = ministry.color.replaceAll('#', '');
    final colorValue = int.tryParse('FF$colorHex', radix: 16) ?? 0xFF2196F3;
    final color = Color(colorValue);
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));

    // Mapear ícone Font Awesome
    final icon = _getIconData(ministry.icon);

    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: InkWell(
        onTap: () {
          context.push('/ministries/${ministry.id}');
        },
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        child: Padding(
          padding: CommunityDesign.overlayPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícone colorido
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),

                  // Nome e descrição
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ministry.name,
                                style: CommunityDesign.titleStyle(context)
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                              ),
                            ),
                            if (!ministry.isActive)
                              CommunityDesign.badge(
                                context,
                                'Inativo',
                                Colors.grey,
                              ),
                          ],
                        ),
                        if (ministry.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            ministry.description!,
                            style: CommunityDesign.metaStyle(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Seta
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              // Contagem de membros
              const SizedBox(height: 12),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return Text(
                      'Nenhum membro',
                      style: CommunityDesign.metaStyle(context),
                    );
                  }

                  final leaders = members
                      .where((m) => m.role == MinistryRole.leader)
                      .length;
                  final sortedNames = members
                      .map((m) => m.memberName)
                      .where((n) => n.trim().isNotEmpty)
                      .toList()
                    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final visibleNames = sortedNames.take(8).toList();
                  final overflow = sortedNames.length - visibleNames.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${members.length} ${members.length == 1 ? 'membro' : 'membros'}',
                            style: CommunityDesign.metaStyle(
                              context,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                          if (leaders > 0) ...[
                            const SizedBox(width: 12),
                            Text(
                              '$leaders ${leaders == 1 ? 'líder' : 'líderes'}',
                              style: CommunityDesign.metaStyle(context),
                            ),
                          ],
                        ],
                      ),
                      if (visibleNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          overflow > 0
                              ? '${visibleNames.join(', ')} (+$overflow)'
                              : visibleNames.join(', '),
                          style: CommunityDesign.metaStyle(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mapear nome do ícone para IconData do Font Awesome
  IconData _getIconData(String? iconName) {
    if (iconName == null) return FontAwesomeIcons.church;

    final iconMap = {
      // ADORAÇÃO & ENSINO
      'music': FontAwesomeIcons.music,
      'hands-praying': FontAwesomeIcons.handsPraying,
      'book-bible': FontAwesomeIcons.bookBible,
      'book-open': FontAwesomeIcons.bookOpen,
      'people-arrows': FontAwesomeIcons.peopleArrows,
      'masks-theater': FontAwesomeIcons.masksTheater,
      'person-running': FontAwesomeIcons.personRunning,

      // EVANGELISMO & MISSÕES
      'bullhorn': FontAwesomeIcons.bullhorn,
      'earth-americas': FontAwesomeIcons.earthAmericas,
      'house-heart': FontAwesomeIcons.house,
      'house-user': FontAwesomeIcons.houseUser,
      'people-group': FontAwesomeIcons.peopleGroup,

      // FAIXAS ETÁRIAS
      'child': FontAwesomeIcons.child,
      'child-reaching': FontAwesomeIcons.child,
      'person-cane': FontAwesomeIcons.personCane,

      // GRUPOS ESPECÍFICOS
      'user-graduate': FontAwesomeIcons.userGraduate,
      'users-between-lines': FontAwesomeIcons.users,
      'users-rays': FontAwesomeIcons.users,
      'users': FontAwesomeIcons.users,
      'heart': FontAwesomeIcons.heart,
      'person': FontAwesomeIcons.person,
      'person-dress': FontAwesomeIcons.personDress,

      // SERVIÇOS & APOIO
      'hand-holding-heart': FontAwesomeIcons.handHoldingHeart,
      'handshake': FontAwesomeIcons.handshake,
      'video': FontAwesomeIcons.video,
      'comments': FontAwesomeIcons.comments,
      'shield-halved': FontAwesomeIcons.shieldHalved,
      'car': FontAwesomeIcons.car,
      'broom': FontAwesomeIcons.broom,
      'utensils': FontAwesomeIcons.utensils,
    };

    return iconMap[iconName] ?? FontAwesomeIcons.church;
  }
}
