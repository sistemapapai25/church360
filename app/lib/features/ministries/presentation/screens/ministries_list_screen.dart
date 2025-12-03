import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';

import '../providers/ministries_provider.dart';
import '../../domain/models/ministry.dart';

/// Tela de listagem de ministérios
class MinistriesListScreen extends ConsumerStatefulWidget {
  const MinistriesListScreen({super.key});

  @override
  ConsumerState<MinistriesListScreen> createState() => _MinistriesListScreenState();
}

class _MinistriesListScreenState extends ConsumerState<MinistriesListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    final ministriesAsync = isAdminAsync.when(
      data: (isAdmin) {
        if (isAdmin) return ref.watch(allMinistriesProvider);
        if (currentUserId == null) return const AsyncValue<List<Ministry>>.data([]);
        return ref.watch(memberMinistriesProvider(currentUserId));
      },
      loading: () => const AsyncValue<List<Ministry>>.loading(),
      error: (_, __) => const AsyncValue<List<Ministry>>.data([]),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ministérios'),
        actions: [
          isAdminAsync.maybeWhen(
            data: (isAdmin) => isAdmin
                ? IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      context.push('/ministries/new');
                    },
                    tooltip: 'Novo Ministério',
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ministriesAsync.when(
        data: (ministries) {
          final filtered = ministries.where((m) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            final name = m.name.toLowerCase();
            final desc = (m.description ?? '').toLowerCase();
            return name.contains(q) || desc.contains(q);
          }).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (ministries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.church_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  isAdminAsync.maybeWhen(
                    data: (isAdmin) => Text(
                      isAdmin ? 'Nenhum ministério cadastrado' : 'Você não possui ministérios vinculados',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    orElse: () => Text(
                      'Carregando...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  isAdminAsync.maybeWhen(
                    data: (isAdmin) => isAdmin
                        ? FilledButton.icon(
                            onPressed: () {
                              context.push('/ministries/new');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Primeiro Ministério'),
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
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar ministério...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ministry = filtered[index];
                    return _MinistryCard(ministry: ministry);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar ministérios: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(allMinistriesProvider);
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isAdminAsync.maybeWhen(
        data: (isAdmin) => isAdmin
            ? ministriesAsync.maybeWhen(
                data: (ministries) => ministries.isNotEmpty
                    ? FloatingActionButton(
                        onPressed: () {
                          context.push('/ministries/new');
                        },
                        child: const Icon(Icons.add),
                      )
                    : null,
                orElse: () => null,
              )
            : null,
        orElse: () => null,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/ministries/${ministry.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!ministry.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Inativo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (ministry.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            ministry.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    );
                  }

                  final leaders = members.where((m) => m.role == MinistryRole.leader).length;

                  return Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${members.length} ${members.length == 1 ? 'membro' : 'membros'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (leaders > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '$leaders ${leaders == 1 ? 'líder' : 'líderes'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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
