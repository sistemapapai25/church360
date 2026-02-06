import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/church_image.dart';
import '../providers/reading_plans_provider.dart';
import '../../domain/models/reading_plan.dart';
import '../../../../core/design/community_design.dart';

const double _pagePadding = 16;
const double _cardPadding = 16;
const double _cardRadius = 16;
const double _gap = 12;

/// Tela de Listagem de Planos de Leitura
class ReadingPlansListScreen extends ConsumerWidget {
  const ReadingPlansListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(activeReadingPlansProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: CommunityDesign.headerColor(context),
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Planos de Leitura',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  Text(
                    'Bíblia e Devocionais',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          toolbarHeight: 64,
        ),
        body: plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum plano disponível',
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 22,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Os planos de leitura aparecerão aqui',
                      style: CommunityDesign.contentStyle(context).copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeReadingPlansProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(_pagePadding),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return ReadingPlanCard(plan: plan);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erro ao carregar planos: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(activeReadingPlansProvider);
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de Plano de Leitura
class ReadingPlanCard extends StatelessWidget {
  final ReadingPlan plan;

  const ReadingPlanCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final hasImage = plan.imageUrl != null && plan.imageUrl!.isNotEmpty;
    final decoration = hasImage
        ? CommunityDesign.overlayDecoration(
            Theme.of(context).colorScheme,
          )
        : BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: [CommunityDesign.overlayBaseShadow()],
          );
    return Container(
      margin: const EdgeInsets.only(bottom: _pagePadding),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navegar para a tela de detalhes do plano
          context.push('/reading-plans/${plan.id}');
        },
        child: hasImage ? _buildWithImage(context) : _buildWithoutImage(context),
      ),
    );
  }

  Widget _buildWithImage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChurchImage(
          imageUrl: plan.imageUrl!,
          type: ChurchImageType.card,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.title,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _buildBadgesRow(context),
              const SizedBox(height: 12),
              if (plan.description != null && plan.description!.isNotEmpty)
                Text(
                  plan.description!,
                  style: CommunityDesign.contentStyle(context),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              _buildCta(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWithoutImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(_cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.menu_book,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  plan.title,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: _gap),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (plan.category != null) _buildCategoryBadge(context),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    plan.durationText,
                    style: CommunityDesign.contentStyle(context).copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: _gap),
            Text(
              plan.description!,
              style: CommunityDesign.contentStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: _gap),
          _buildCta(context),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context) {
    if (plan.category == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plan.categoryText,
        style: CommunityDesign.metaStyle(context).copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildBadgesRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (plan.category != null) _buildCategoryBadge(context),
        const SizedBox(width: 8),
        Icon(
          Icons.schedule,
          size: 16,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          plan.durationText,
          style: CommunityDesign.contentStyle(context).copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCta(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          context.push('/reading-plans/${plan.id}');
        },
        icon: const Icon(Icons.arrow_forward, size: 16),
        label: const Text('VER DETALHES'),
      ),
    );
  }
}
