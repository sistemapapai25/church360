import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/reading_plans_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/community_design.dart';

/// Tela de Detalhes do Plano de Leitura
class ReadingPlanDetailScreen extends ConsumerWidget {
  final String planId;

  const ReadingPlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(readingPlanByIdProvider(planId));

    return Scaffold(
      backgroundColor: CommunityDesign.backgroundColor,
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Plano não encontrado'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // App Bar com imagem
              SliverAppBar(
                backgroundColor: CommunityDesign.headerColor(context),
                elevation: 0,
                scrolledUnderElevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                expandedHeight: 250,
                pinned: true,
                centerTitle: false,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    plan.title,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  background: plan.imageUrl != null && plan.imageUrl!.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              plan.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.menu_book,
                                    size: 80,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                );
                              },
                            ),
                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.menu_book,
                            size: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),

              // Conteúdo
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categoria e Duração
                      Row(
                        children: [
                          // Categoria
                          if (plan.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                plan.categoryText,
                                style: CommunityDesign.metaStyle(
                                  context,
                                ).copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),

                          // Duração
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  plan.durationText,
                                  style: CommunityDesign.contentStyle(
                                    context,
                                  ).copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Descrição
                      if (plan.description != null &&
                          plan.description!.isNotEmpty) ...[
                        Text(
                          'Sobre o Plano',
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          plan.description!,
                          style: CommunityDesign.contentStyle(context),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Informações adicionais
                      Container(
                        decoration: CommunityDesign.overlayDecoration(
                          Theme.of(context).colorScheme,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informações',
                                style: CommunityDesign.titleStyle(
                                  context,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                icon: Icons.calendar_today,
                                label: 'Duração',
                                value: '${plan.durationDays} dias',
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.category,
                                label: 'Categoria',
                                value: plan.categoryText,
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.check_circle,
                                label: 'Status',
                                value: plan.isActive ? 'Ativo' : 'Inativo',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botão "Iniciar Plano"
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final member = await ref.read(
                              currentMemberProvider.future,
                            );
                            if (member == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Faça login para iniciar o plano',
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              final repo = ref.read(
                                readingPlansRepositoryProvider,
                              );
                              await repo.startPlan(plan.id, member.id);

                              ref.invalidate(
                                userActiveProgressProvider(member.id),
                              );
                              ref.invalidate(
                                userPlanProgressProvider((
                                  planId: plan.id,
                                  memberId: member.id,
                                )),
                              );

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Plano iniciado! Bom estudo 📖',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao iniciar plano: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('INICIAR PLANO'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar plano: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(readingPlanByIdProvider(planId));
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de linha de informação
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: CommunityDesign.contentStyle(
            context,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: CommunityDesign.contentStyle(context),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
