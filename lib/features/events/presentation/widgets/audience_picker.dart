import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/event_audience.dart';

/// Tipos de alvo que o seletor pode oferecer. Quem abre o picker escolhe o
/// conjunto: Responsáveis usam Pessoas/Ministérios (default), enquanto
/// Visibilidade e Elegibilidade de Inscrição passam a lista SEM
/// [AudienceTargetTab.people] — pessoa avulsa não é alvo desses dois
/// controles (decisão D-03 da Fase 3).
enum AudienceTargetTab { people, groups, ministries, roles }

/// Abre o bottom sheet de seleção combinável de alvos de audiência.
/// Retorna `null` se o usuário fechar sem concluir.
///
/// Os três parâmetros novos ([role], [title], [tabs]) têm default
/// retrocompatível: sem eles o seletor se comporta exatamente como a seção
/// "Responsáveis" entregue na Fase 1 — `role: 'responsible'`,
/// `title: 'Adicionar responsável'` e
/// `tabs: [AudienceTargetTab.people, AudienceTargetTab.ministries]`.
/// Grupos e Cargos só aparecem para quem pedir `tabs:` explicitamente.
Future<List<EventAudience>?> showAudiencePicker(
  BuildContext context, {
  required String eventId,
  required List<EventAudience> initialSelection,
  String role = 'responsible',
  String title = 'Adicionar responsável',
  List<AudienceTargetTab> tabs = const [
    AudienceTargetTab.people,
    AudienceTargetTab.ministries,
  ],
}) {
  return showModalBottomSheet<List<EventAudience>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AudiencePicker(
      eventId: eventId,
      initialSelection: initialSelection,
      role: role,
      title: title,
      tabs: tabs,
    ),
  );
}

class AudiencePicker extends ConsumerStatefulWidget {
  final String eventId;
  final List<EventAudience> initialSelection;

  /// Papel da linha de audiência gravada (`responsible`, `visibility` ou
  /// `registration`) — não confundir com o cargo RBAC da aba "Cargos".
  final String role;
  final String title;
  final List<AudienceTargetTab> tabs;

  const AudiencePicker({
    super.key,
    required this.eventId,
    required this.initialSelection,
    this.role = 'responsible',
    this.title = 'Adicionar responsável',
    this.tabs = const [
      AudienceTargetTab.people,
      AudienceTargetTab.ministries,
    ],
  });

  @override
  ConsumerState<AudiencePicker> createState() => _AudiencePickerState();
}

class _AudiencePickerState extends ConsumerState<AudiencePicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  // Selecionado em todas as abas, chave namespaced por tipo para não colidir
  // entre os espaços de id (pessoa/grupo/ministério/cargo).
  final Map<String, EventAudience> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _searchController.clear();
        _query = '';
      });
    });
    for (final target in widget.initialSelection) {
      _selected[_keyFor(target)] = target;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _keyFor(EventAudience target) {
    return '${target.targetKind.name}:${target.targetId}';
  }

  void _toggle(EventAudience target) {
    setState(() {
      final key = _keyFor(target);
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = target;
      }
    });
  }

  String _labelFor(AudienceTargetTab tab) {
    switch (tab) {
      case AudienceTargetTab.people:
        return 'Pessoas';
      case AudienceTargetTab.groups:
        return 'Grupos';
      case AudienceTargetTab.ministries:
        return 'Ministérios';
      case AudienceTargetTab.roles:
        return 'Cargos';
    }
  }

  Widget _viewFor(AudienceTargetTab tab) {
    switch (tab) {
      case AudienceTargetTab.people:
        return _PeopleTab(
          eventId: widget.eventId,
          role: widget.role,
          query: _query,
          selected: _selected,
          keyFor: _keyFor,
          onToggle: _toggle,
        );
      case AudienceTargetTab.groups:
        return _GroupsTab(
          eventId: widget.eventId,
          role: widget.role,
          query: _query,
          selected: _selected,
          keyFor: _keyFor,
          onToggle: _toggle,
        );
      case AudienceTargetTab.ministries:
        return _MinistriesTab(
          eventId: widget.eventId,
          role: widget.role,
          query: _query,
          selected: _selected,
          keyFor: _keyFor,
          onToggle: _toggle,
        );
      case AudienceTargetTab.roles:
        return _RolesTab(
          eventId: widget.eventId,
          role: widget.role,
          query: _query,
          selected: _selected,
          keyFor: _keyFor,
          onToggle: _toggle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: SizedBox(
        height: mediaHeight * 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                isScrollable: widget.tabs.length > 3,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                tabs: [
                  for (final tab in widget.tabs) Tab(text: _labelFor(tab)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar...',
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _query = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final tab in widget.tabs) _viewFor(tab),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '${_selected.length} selecionados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, _selected.values.toList()),
                        child: const Text('Concluir'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final String query;

  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Nenhum resultado para "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confira a grafia ou tente buscar pelo apelido.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista vazia por ausência de cadastro (não por busca sem resultado).
/// Existe porque há tenants sem nenhum cargo cadastrado: a aba precisa
/// explicar o vazio em vez de mostrar uma lista em branco.
class _NoDataState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _NoDataState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _PeopleTab extends ConsumerWidget {
  final String eventId;
  final String role;
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _PeopleTab({
    required this.eventId,
    required this.role,
    required this.query,
    required this.selected,
    required this.keyFor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final directoryAsync = ref.watch(memberDirectoryProvider);

    return directoryAsync.when(
      data: (people) {
        var filtered = people;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          filtered = filtered.where((m) {
            return m.displayName.toLowerCase().contains(q) ||
                ((m.nickname?.toLowerCase().contains(q)) ?? false);
          }).toList();
        }

        if (filtered.isEmpty && query.isNotEmpty) {
          return _SearchEmptyState(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final person = filtered[index];
            final target = EventAudience(
              eventId: eventId,
              role: role,
              userId: person.id,
              displayName: person.displayName,
            );
            final isSelected = selected.containsKey(keyFor(target));
            return CheckboxListTile(
              value: isSelected,
              activeColor: colorScheme.primary,
              secondary: CircleAvatar(
                backgroundImage: (person.avatarUrl != null &&
                        person.avatarUrl!.trim().isNotEmpty)
                    ? NetworkImage(person.avatarUrl!)
                    : null,
                child: (person.avatarUrl == null ||
                        person.avatarUrl!.trim().isEmpty)
                    ? Text(person.initials)
                    : null,
              ),
              title: Text(person.displayName),
              onChanged: (_) => onToggle(target),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _LoadErrorState(
        message: 'Não foi possível carregar a lista de membros.',
        onRetry: () => ref.invalidate(memberDirectoryProvider),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  final String eventId;
  final String role;
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _GroupsTab({
    required this.eventId,
    required this.role,
    required this.query,
    required this.selected,
    required this.keyFor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupsAsync = ref.watch(allGroupsProvider);

    return groupsAsync.when(
      data: (groups) {
        var filtered = groups;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          filtered =
              filtered.where((g) => g.name.toLowerCase().contains(q)).toList();
        }

        if (filtered.isEmpty && query.isNotEmpty) {
          return _SearchEmptyState(query: query);
        }

        if (filtered.isEmpty) {
          return const _NoDataState(
            icon: Icons.group_off,
            title: 'Nenhum grupo cadastrado',
            description:
                'Cadastre grupos em Grupos para poder usá-los como alvo aqui.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final group = filtered[index];
            final target = EventAudience(
              eventId: eventId,
              role: role,
              groupId: group.id,
              displayName: group.name,
            );
            final isSelected = selected.containsKey(keyFor(target));
            return CheckboxListTile(
              value: isSelected,
              activeColor: colorScheme.primary,
              secondary: Icon(Icons.group, color: colorScheme.onSurfaceVariant),
              title: Text(group.name),
              onChanged: (_) => onToggle(target),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _LoadErrorState(
        message: 'Não foi possível carregar os grupos.',
        onRetry: () => ref.invalidate(allGroupsProvider),
      ),
    );
  }
}

class _MinistriesTab extends ConsumerWidget {
  final String eventId;
  final String role;
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _MinistriesTab({
    required this.eventId,
    required this.role,
    required this.query,
    required this.selected,
    required this.keyFor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ministriesAsync = ref.watch(allMinistriesProvider);

    return ministriesAsync.when(
      data: (ministries) {
        var filtered = ministries;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          filtered = filtered.where((m) => m.name.toLowerCase().contains(q)).toList();
        }

        if (filtered.isEmpty && query.isNotEmpty) {
          return _SearchEmptyState(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final ministry = filtered[index];
            final target = EventAudience(
              eventId: eventId,
              role: role,
              ministryId: ministry.id,
              displayName: ministry.name,
            );
            final isSelected = selected.containsKey(keyFor(target));
            return CheckboxListTile(
              value: isSelected,
              activeColor: colorScheme.primary,
              secondary: Icon(Icons.church, color: colorScheme.onSurfaceVariant),
              title: Text(ministry.name),
              onChanged: (_) => onToggle(target),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _LoadErrorState(
        message: 'Não foi possível carregar os grupos e ministérios.',
        onRetry: () => ref.invalidate(allMinistriesProvider),
      ),
    );
  }
}

/// Aba de cargos RBAC (`public.roles`, tela Permissões > Cargos).
///
/// `allRolesProvider` já devolve SOMENTE cargos com `is_active = true`,
/// ordenados por nome — é exatamente o que a decisão D-07 pede para NOVAS
/// seleções. Não "consertar" removendo esse filtro: oferecer cargo inativo
/// para nova escolha é o comportamento que D-07 proíbe.
class _RolesTab extends ConsumerWidget {
  final String eventId;
  final String role;
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _RolesTab({
    required this.eventId,
    required this.role,
    required this.query,
    required this.selected,
    required this.keyFor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final rolesAsync = ref.watch(allRolesProvider);

    return rolesAsync.when(
      data: (roles) {
        var filtered = roles;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          filtered =
              filtered.where((r) => r.name.toLowerCase().contains(q)).toList();
        }

        // D-07: cargo já escolhido que foi desativado depois continua valendo
        // como alvo. Como ele não vem mais de allRolesProvider, é renderizado
        // aqui no topo, marcado e diferenciado — some da lista só se o
        // usuário desmarcar de propósito, nunca sozinho.
        final idsAtivos = roles.map((r) => r.id).toSet();
        final desativadosSelecionados = selected.values
            .where(
              (t) =>
                  t.targetKind == EventAudienceTargetKind.role &&
                  !idsAtivos.contains(t.targetId),
            )
            .toList();

        if (filtered.isEmpty &&
            desativadosSelecionados.isEmpty &&
            query.isNotEmpty) {
          return _SearchEmptyState(query: query);
        }

        if (filtered.isEmpty && desativadosSelecionados.isEmpty) {
          return const _NoDataState(
            icon: Icons.badge_outlined,
            title: 'Nenhum cargo cadastrado',
            description:
                'Cadastre cargos em Permissões > Cargos para poder restringir '
                'o evento por cargo.',
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount:
                    desativadosSelecionados.length + filtered.length,
                itemBuilder: (context, index) {
                  if (index < desativadosSelecionados.length) {
                    final inativo = desativadosSelecionados[index];
                    return CheckboxListTile(
                      value: true,
                      activeColor: colorScheme.primary,
                      secondary: Icon(
                        Icons.badge,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        '${inativo.displayName ?? inativo.targetId} (cargo desativado)',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      onChanged: (_) => onToggle(inativo),
                    );
                  }

                  final cargo = filtered[index - desativadosSelecionados.length];
                  final target = EventAudience(
                    eventId: eventId,
                    role: role,
                    rbacRoleId: cargo.id,
                    displayName: cargo.name,
                  );
                  final isSelected = selected.containsKey(keyFor(target));
                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: colorScheme.primary,
                    secondary: Icon(
                      Icons.badge,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(cargo.name),
                    onChanged: (_) => onToggle(target),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Restringir por cargo alcança apenas membros com conta de acesso.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _LoadErrorState(
        message: 'Não foi possível carregar os cargos.',
        onRetry: () => ref.invalidate(allRolesProvider),
      ),
    );
  }
}
