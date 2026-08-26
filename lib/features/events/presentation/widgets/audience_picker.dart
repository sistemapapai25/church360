import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../domain/models/event_audience.dart';

/// Abre o bottom sheet de seleção combinável de responsáveis (Pessoas,
/// Ministérios). Retorna `null` se o usuário fechar sem concluir.
Future<List<EventAudience>?> showAudiencePicker(
  BuildContext context, {
  required String eventId,
  required List<EventAudience> initialSelection,
}) {
  return showModalBottomSheet<List<EventAudience>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AudiencePicker(
      eventId: eventId,
      initialSelection: initialSelection,
    ),
  );
}

class AudiencePicker extends ConsumerStatefulWidget {
  final String eventId;
  final List<EventAudience> initialSelection;

  const AudiencePicker({
    super.key,
    required this.eventId,
    required this.initialSelection,
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
  // entre os dois espaços de id (pessoa/ministério).
  final Map<String, EventAudience> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                'Adicionar responsável',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                tabs: const [
                  Tab(text: 'Pessoas'),
                  Tab(text: 'Ministérios'),
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
                    _PeopleTab(
                      eventId: widget.eventId,
                      query: _query,
                      selected: _selected,
                      keyFor: _keyFor,
                      onToggle: (target) => setState(() {
                        final key = _keyFor(target);
                        if (_selected.containsKey(key)) {
                          _selected.remove(key);
                        } else {
                          _selected[key] = target;
                        }
                      }),
                    ),
                    _MinistriesTab(
                      eventId: widget.eventId,
                      query: _query,
                      selected: _selected,
                      keyFor: _keyFor,
                      onToggle: (target) => setState(() {
                        final key = _keyFor(target);
                        if (_selected.containsKey(key)) {
                          _selected.remove(key);
                        } else {
                          _selected[key] = target;
                        }
                      }),
                    ),
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
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _PeopleTab({
    required this.eventId,
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
              role: 'responsible',
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

class _MinistriesTab extends ConsumerWidget {
  final String eventId;
  final String query;
  final Map<String, EventAudience> selected;
  final String Function(EventAudience) keyFor;
  final void Function(EventAudience) onToggle;

  const _MinistriesTab({
    required this.eventId,
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
              role: 'responsible',
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
