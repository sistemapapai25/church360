import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/date_period_filter.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de listagem de visitantes
class VisitorsListScreen extends ConsumerStatefulWidget {
  const VisitorsListScreen({super.key});

  @override
  ConsumerState<VisitorsListScreen> createState() => _VisitorsListScreenState();
}

class _VisitorsListScreenState extends ConsumerState<VisitorsListScreen> {
  String _searchQuery = '';
  bool _showFilters = false;
  DatePeriodSelection _firstVisitFilter = const DatePeriodSelection();
  DatePeriodSelection _salvationFilter = const DatePeriodSelection();
  final Set<String> _followUpStatuses = <String>{};
  bool _onlyWantsContact = false;
  RangeValues? _ageRange; // null = sem filtro
  static const double _ageMin = 0;
  static const double _ageMax = 100;
  final _searchController = TextEditingController();

  int _activeFilterCount() {
    var count = 0;
    if (_firstVisitFilter.period != DatePeriod.all) count++;
    if (_salvationFilter.period != DatePeriod.all) count++;
    if (_followUpStatuses.isNotEmpty) count++;
    if (_onlyWantsContact) count++;
    if (_ageRange != null) count++;
    return count;
  }

  bool _matchesFilters(Visitor v) {
    if (!_firstVisitFilter.matches(v.firstVisitDate)) return false;
    if (_salvationFilter.period != DatePeriod.all) {
      if (!_salvationFilter.matches(v.salvationDate)) return false;
    }
    if (_followUpStatuses.isNotEmpty &&
        !_followUpStatuses.contains(v.followUpStatus)) {
      return false;
    }
    if (_onlyWantsContact && !v.wantsContact) return false;
    if (_ageRange != null) {
      final age = v.age;
      if (age == null) return false;
      if (age < _ageRange!.start.round() || age > _ageRange!.end.round()) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Buscar todos os visitantes
    final visitorsAsync = ref.watch(allVisitorsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Column(
        children: [
          // Header com título e botão de voltar
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
                        Icons.person_add,
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
                            'Gestão de Visitantes',
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Gerencie os visitantes da comunidade',
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Área de Busca e Filtros
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
                          'Buscar Visitantes',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                        icon: Icon(
                          _showFilters
                              ? Icons.expand_less
                              : Icons.filter_alt_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _showFilters
                              ? 'Ocultar filtros'
                              : (_activeFilterCount() == 0
                                    ? 'Mais filtros'
                                    : 'Filtros (${_activeFilterCount()})'),
                        ),
                      ),
                    ),
                    if (_showFilters) ...[
                      const SizedBox(height: 8),
                      DatePeriodFilter(
                        label: 'Primeira visita',
                        icon: Icons.door_front_door,
                        selection: _firstVisitFilter,
                        onChanged: (sel) =>
                            setState(() => _firstVisitFilter = sel),
                      ),
                      const SizedBox(height: 16),
                      DatePeriodFilter(
                        label: 'Decisão / salvação',
                        icon: Icons.favorite,
                        selection: _salvationFilter,
                        onChanged: (sel) =>
                            setState(() => _salvationFilter = sel),
                      ),
                      const SizedBox(height: 16),
                      _FollowUpFilter(
                        selected: _followUpStatuses,
                        onToggle: (status) {
                          setState(() {
                            if (_followUpStatuses.contains(status)) {
                              _followUpStatuses.remove(status);
                            } else {
                              _followUpStatuses.add(status);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Switch(
                            value: _onlyWantsContact,
                            onChanged: (v) =>
                                setState(() => _onlyWantsContact = v),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Somente quem deseja contato',
                              style: CommunityDesign.metaStyle(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _AgeRangeFilter(
                        range: _ageRange,
                        min: _ageMin,
                        max: _ageMax,
                        onChanged: (range) =>
                            setState(() => _ageRange = range),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Lista de visitantes
          Expanded(
            child: visitorsAsync.when(
              data: (visitors) {
                // Filtrar por pesquisa
                var filteredVisitors = visitors;
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredVisitors = visitors.where((visitor) {
                    return visitor.displayName.toLowerCase().contains(query) ||
                        (visitor.nickname?.toLowerCase().contains(query) ??
                            false);
                  }).toList();
                }

                // Filtros adicionais (Raízes)
                filteredVisitors =
                    filteredVisitors.where(_matchesFilters).toList();

                return _buildVisitorsList(context, filteredVisitors);
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
                        'Erro ao carregar visitantes',
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
                          ref.invalidate(allVisitorsProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
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
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: 'visitors.create',
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/members/new?status=visitor&type=visitante'),
          icon: const Icon(Icons.add),
          label: const Text('Novo Visitante'),
        ),
      ),
    );
  }

  Widget _buildVisitorsList(
    BuildContext context,
    List<Visitor> filteredVisitors,
  ) {
    if (filteredVisitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum visitante encontrado',
              style: CommunityDesign.titleStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      itemCount: filteredVisitors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final visitor = filteredVisitors[index];
        return _VisitorCard(visitor: visitor);
      },
    );
  }
}

/// Widget de card de visitante com design rico
class _VisitorCard extends ConsumerWidget {
  final Visitor visitor;

  const _VisitorCard({required this.visitor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Padding(
        padding: CommunityDesign.overlayPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Foto, Nome, Apelido e Status
            Row(
              children: [
                // Foto do visitante
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: visitor.photoUrl != null
                      ? NetworkImage(visitor.photoUrl!)
                      : null,
                  child: visitor.photoUrl == null
                      ? Text(
                          visitor.initials,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Nome e apelido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.displayName,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (visitor.nickname != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '"${visitor.nickname}"',
                              style: CommunityDesign.metaStyle(
                                context,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(width: 8),
                            CommunityDesign.badge(
                              context,
                              'Visitante',
                              Colors.blue,
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        CommunityDesign.badge(
                          context,
                          'Visitante',
                          Colors.blue,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            // Informações do visitante
            _buildInfoRow(
              context,
              Icons.phone,
              visitor.phone ?? 'Sem telefone',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.person,
              visitor.gender == 'male'
                  ? 'Masculino'
                  : visitor.gender == 'female'
                  ? 'Feminino'
                  : 'Não informado',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.cake,
              visitor.age != null
                  ? '${visitor.age} anos'
                  : 'Idade não informada',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.location_on, visitor.state ?? 'GO'),
            const SizedBox(height: 16),
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/members/${visitor.id}');
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
                      context.push('/members/${visitor.id}/edit');
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
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
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

class _FollowUpFilter extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _FollowUpFilter({required this.selected, required this.onToggle});

  static const _options = <_FollowUpOption>[
    _FollowUpOption('pending', 'Pendente'),
    _FollowUpOption('in_progress', 'Em andamento'),
    _FollowUpOption('completed', 'Concluído'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Acompanhamento',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options
              .map(
                (opt) => FilterChip(
                  label: Text(opt.label),
                  selected: selected.contains(opt.value),
                  onSelected: (_) => onToggle(opt.value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FollowUpOption {
  final String value;
  final String label;
  const _FollowUpOption(this.value, this.label);
}

class _AgeRangeFilter extends StatelessWidget {
  final RangeValues? range;
  final double min;
  final double max;
  final ValueChanged<RangeValues?> onChanged;

  const _AgeRangeFilter({
    required this.range,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = range ?? RangeValues(min, max);
    final isActive = range != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cake_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Faixa etária',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isActive)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text('Limpar'),
              ),
          ],
        ),
        Text(
          isActive
              ? '${current.start.round()} a ${current.end.round()} anos'
              : 'Todas as idades',
          style: CommunityDesign.metaStyle(context),
        ),
        RangeSlider(
          values: current,
          min: min,
          max: max,
          divisions: (max - min).round(),
          labels: RangeLabels(
            current.start.round().toString(),
            current.end.round().toString(),
          ),
          onChanged: (values) => onChanged(values),
        ),
      ],
    );
  }
}
