import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/visitor_recommendation.dart';
import '../providers/raizes_dashboard_provider.dart';
import '../providers/raizes_recommendations_provider.dart';

/// Tela de Indicações de Padrinhos do Raízes (Lote MR4C.2).
///
/// Lista as sugestões geradas pela RPC `generate_visitor_recommendations`
/// agrupadas por visitante (ordem de score DESC dentro de cada grupo).
/// Permite filtrar por status (default: Pendentes) e regerar sugestões
/// via FAB que chama a RPC.
class RaizesRecommendationsScreen extends ConsumerWidget {
  final String ministryId;

  const RaizesRecommendationsScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'raizes.manage_recommendations',
      submoduleLabel: 'Indicações de Padrinhos',
      builder: (context) => _RecommendationsContent(ministryId: ministryId),
    );
  }
}

class _RecommendationsContent extends ConsumerStatefulWidget {
  final String ministryId;

  const _RecommendationsContent({required this.ministryId});

  @override
  ConsumerState<_RecommendationsContent> createState() =>
      _RecommendationsContentState();
}

class _RecommendationsContentState
    extends ConsumerState<_RecommendationsContent> {
  VisitorRecommendationStatus _statusFilter =
      VisitorRecommendationStatus.pending;
  bool _generating = false;

  Future<void> _generateRecommendations() async {
    setState(() => _generating = true);
    try {
      final repo = ref.read(raizesRepositoryProvider);
      final count = await repo.generateRecommendations(widget.ministryId);
      if (!mounted) return;
      ref.invalidate(raizesRecommendationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Nenhum match encontrado. Cadastre padrinhos com critérios.'
                : '$count sugestão${count == 1 ? '' : 'ões'} avaliada'
                    '${count == 1 ? '' : 's'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar sugestões: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _accept(VisitorRecommendation rec) async {
    try {
      final repo = ref.read(raizesRepositoryProvider);
      final ok = await repo.acceptRecommendation(rec.id);
      if (!mounted) return;
      if (ok) {
        ref.invalidate(raizesRecommendationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${rec.sponsorDisplayName} agora é padrinho/madrinha de '
              '${rec.visitorDisplayName}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError('Não foi possível aceitar (sem tenant ou recomendação inválida).');
      }
    } catch (e) {
      _showError('Erro ao aceitar: $e');
    }
  }

  Future<void> _reject(VisitorRecommendation rec) async {
    try {
      final repo = ref.read(raizesRepositoryProvider);
      await repo.rejectRecommendation(recommendationId: rec.id);
      if (!mounted) return;
      ref.invalidate(raizesRecommendationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indicação recusada.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _showError('Erro ao recusar: $e');
    }
  }

  Future<void> _archive(VisitorRecommendation rec) async {
    try {
      final repo = ref.read(raizesRepositoryProvider);
      await repo.archiveRecommendation(rec.id);
      if (!mounted) return;
      ref.invalidate(raizesRecommendationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indicação arquivada.')),
      );
    } catch (e) {
      _showError('Erro ao arquivar: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = RaizesRecommendationsArgs(
      ministryId: widget.ministryId,
      status: _statusFilter,
    );
    final recsAsync = ref.watch(raizesRecommendationsProvider(args));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Indicações de Padrinhos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generating ? null : _generateRecommendations,
        icon: _generating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_generating ? 'Gerando...' : 'Gerar sugestões'),
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _statusFilter,
            onChanged: (s) => setState(() => _statusFilter = s),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(raizesRecommendationsProvider);
                await ref.read(raizesRecommendationsProvider(args).future);
              },
              child: recsAsync.when(
                data: (recs) {
                  if (recs.isEmpty) {
                    return _EmptyState(filter: _statusFilter);
                  }
                  final groups = _groupByVisitor(recs);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      return _VisitorGroupCard(
                        group: group,
                        onAccept: _accept,
                        onReject: _reject,
                        onArchive: _archive,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(raizesRecommendationsProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Agrupa as recomendações por visitante e ordena cada grupo por score DESC.
  List<_VisitorGroup> _groupByVisitor(List<VisitorRecommendation> recs) {
    final byId = <String, List<VisitorRecommendation>>{};
    for (final r in recs) {
      byId.putIfAbsent(r.visitorId, () => <VisitorRecommendation>[]).add(r);
    }
    final groups = byId.entries.map((e) {
      final sorted = [...e.value]..sort((a, b) => b.score.compareTo(a.score));
      return _VisitorGroup(
        visitorId: e.key,
        recommendations: sorted,
      );
    }).toList();
    // Ordem entre grupos: maior score do top-1 primeiro.
    groups.sort((a, b) =>
        b.recommendations.first.score.compareTo(a.recommendations.first.score));
    return groups;
  }
}

class _VisitorGroup {
  final String visitorId;
  final List<VisitorRecommendation> recommendations;
  const _VisitorGroup({
    required this.visitorId,
    required this.recommendations,
  });
}

// =====================================================
// Componentes
// =====================================================

class _FilterBar extends StatelessWidget {
  final VisitorRecommendationStatus current;
  final ValueChanged<VisitorRecommendationStatus> onChanged;

  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: VisitorRecommendationStatus.values.map((s) {
            final selected = current == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s.label),
                selected: selected,
                onSelected: (_) => onChanged(s),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _VisitorGroupCard extends StatelessWidget {
  final _VisitorGroup group;
  final void Function(VisitorRecommendation) onAccept;
  final void Function(VisitorRecommendation) onReject;
  final void Function(VisitorRecommendation) onArchive;

  const _VisitorGroupCard({
    required this.group,
    required this.onAccept,
    required this.onReject,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = group.recommendations.first;
    final visitorPhoto = (first.visitorPhotoUrl ?? '').trim();
    final initial = (first.visitorFirstName ?? '?').trim().isNotEmpty
        ? first.visitorFirstName!.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CommunityDesign.overlayDecoration(cs),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                backgroundImage: visitorPhoto.isNotEmpty
                    ? NetworkImage(visitorPhoto)
                    : null,
                child: visitorPhoto.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.visitorDisplayName,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${group.recommendations.length} sugestão'
                      '${group.recommendations.length == 1 ? '' : 'ões'}',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group.recommendations.map((r) => _MatchTile(
                rec: r,
                onAccept: () => onAccept(r),
                onReject: () => onReject(r),
                onArchive: () => onArchive(r),
              )),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final VisitorRecommendation rec;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onArchive;

  const _MatchTile({
    required this.rec,
    required this.onAccept,
    required this.onReject,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _statusColor(rec.status, cs);
    final pending = rec.status == VisitorRecommendationStatus.pending;
    final sponsorPhoto = (rec.sponsorPhotoUrl ?? '').trim();
    final initial = (rec.sponsorFirstName ?? '?').trim().isNotEmpty
        ? rec.sponsorFirstName!.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.secondary.withValues(alpha: 0.15),
                backgroundImage: sponsorPhoto.isNotEmpty
                    ? NetworkImage(sponsorPhoto)
                    : null,
                child: sponsorPhoto.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: cs.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.sponsorDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (!pending) ...[
                      const SizedBox(height: 2),
                      Text(
                        rec.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _ScoreBadge(score: rec.score),
            ],
          ),
          if (rec.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...rec.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatRecommendationReason(r),
                        style: CommunityDesign.metaStyle(context)
                            .copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aceitar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Recusar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Arquivar',
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(VisitorRecommendationStatus s, ColorScheme cs) {
    switch (s) {
      case VisitorRecommendationStatus.pending:
        return cs.primary;
      case VisitorRecommendationStatus.accepted:
        return Colors.green;
      case VisitorRecommendationStatus.rejected:
        return cs.error;
      case VisitorRecommendationStatus.archived:
        return Colors.grey;
    }
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 60
        ? Colors.green
        : score >= 30
            ? Colors.orange
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VisitorRecommendationStatus filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isPending = filter == VisitorRecommendationStatus.pending;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        Center(
          child: Icon(
            isPending ? Icons.auto_awesome : Icons.inbox_outlined,
            size: 56,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isPending ? 'Nenhuma indicação pendente' : 'Lista vazia',
          textAlign: TextAlign.center,
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPending
              ? 'Toque em "Gerar sugestões" para avaliar visitantes contra os padrinhos cadastrados.'
              : 'Não há indicações com status "${filter.label.toLowerCase()}".',
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const Center(
          child: Icon(Icons.error_outline, size: 56, color: Colors.red),
        ),
        const SizedBox(height: 16),
        Text(
          'Erro ao carregar indicações',
          textAlign: TextAlign.center,
          style: CommunityDesign.titleStyle(context),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }
}
