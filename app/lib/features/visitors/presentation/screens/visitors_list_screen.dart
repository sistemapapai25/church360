import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../../core/design/community_design.dart';

/// Tela de listagem de visitantes
class VisitorsListScreen extends ConsumerStatefulWidget {
  const VisitorsListScreen({super.key});

  @override
  ConsumerState<VisitorsListScreen> createState() => _VisitorsListScreenState();
}

class _VisitorsListScreenState extends ConsumerState<VisitorsListScreen> {
  String _searchQuery = '';

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
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Digite o nome ou apelido...',
                        hintStyle: CommunityDesign.metaStyle(context),
                        prefixIcon: const Icon(Icons.search, size: 20),
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
      floatingActionButton: LeaderOnlyWidget(
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/members/new?status=visitor'),
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
