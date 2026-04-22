import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/reading_plans_provider.dart';
import '../../domain/models/reading_plan.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

/// Tela de Detalhes do Plano de Leitura
class ReadingPlanDetailScreen extends ConsumerWidget {
  final String planId;

  const ReadingPlanDetailScreen({super.key, required this.planId});

  void _openModule(
    BuildContext context, {
    required ReadingPlan plan,
    required int day,
    required int totalModules,
  }) {
    final safeTotal = totalModules < 1 ? 1 : totalModules;
    final safeDay = day < 1 ? 1 : (day > safeTotal ? safeTotal : day);
    context.push('/reading-plans/${plan.id}/modules/$safeDay');
  }

  Future<void> _refreshProgress(
    WidgetRef ref, {
    required String planId,
    required String memberId,
  }) async {
    ref.invalidate(userActiveProgressProvider(memberId));
    ref.invalidate(
      userPlanProgressProvider((planId: planId, memberId: memberId)),
    );
    final _ = await ref.refresh(
      userPlanProgressProvider((planId: planId, memberId: memberId)).future,
    );
  }

  Future<void> _startPlan(
    BuildContext context,
    WidgetRef ref, {
    required ReadingPlan plan,
  }) async {
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para iniciar o plano')),
      );
      return;
    }

    try {
      final repo = ref.read(readingPlansRepositoryProvider);
      await repo.startPlan(plan.id, member.id);
      await _refreshProgress(ref, planId: plan.id, memberId: member.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plano iniciado! Módulo 1 liberado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.start_plan',
        fallbackMessage: 'Nao foi possivel iniciar o plano. Tente novamente.',
      );
    }
  }

  Future<void> _restartPlan(
    BuildContext context,
    WidgetRef ref, {
    required ReadingPlan plan,
  }) async {
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para reiniciar o plano')),
      );
      return;
    }

    try {
      final repo = ref.read(readingPlansRepositoryProvider);
      await repo.restartPlan(planId: plan.id, memberId: member.id);
      await _refreshProgress(ref, planId: plan.id, memberId: member.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plano reiniciado. Módulo 1 liberado novamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.restart_plan',
        fallbackMessage: 'Nao foi possivel reiniciar o plano. Tente novamente.',
      );
    }
  }

  ReadingPlanModule? _moduleForDay(ReadingPlan plan, int day) {
    if (!plan.hasModules) return null;
    final index = day - 1;
    if (index < 0 || index >= plan.modules.length) return null;
    return plan.modules[index];
  }

  String _moduleReference(
    ReadingPlan plan,
    int day, {
    ReadingPlanModule? module,
  }) {
    final explicitReference = module?.reference?.trim();
    if (explicitReference != null && explicitReference.isNotEmpty) {
      return explicitReference;
    }

    final normalizedDay = day < 1 ? 1 : day;
    final totalDays = plan.totalModules < 1 ? 1 : plan.totalModules;
    switch (plan.category) {
      case 'old_testament':
        const books = [
          'Gênesis',
          'Êxodo',
          'Levítico',
          'Números',
          'Deuteronômio',
        ];
        final index = ((normalizedDay - 1) * books.length ~/ totalDays).clamp(
          0,
          books.length - 1,
        );
        return books[index];
      case 'new_testament':
        const books = ['Mateus', 'Marcos', 'Lucas', 'João', 'Atos'];
        final index = ((normalizedDay - 1) * books.length ~/ totalDays).clamp(
          0,
          books.length - 1,
        );
        return books[index];
      case 'devotional':
        return 'Leitura devocional e aplicação prática';
      case 'complete_bible':
        return 'Leitura bíblica contínua (AT + NT)';
      default:
        return 'Conteúdo do plano';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(readingPlanByIdProvider(planId));
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
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

          final currentMember = currentMemberAsync.valueOrNull;
          final progressAsync = currentMember == null
              ? const AsyncValue<ReadingPlanProgress?>.data(null)
              : ref.watch(
                  userPlanProgressProvider((
                    planId: plan.id,
                    memberId: currentMember.id,
                  )),
                );
          final userProgress = progressAsync.valueOrNull;
          final hasStarted = userProgress != null;
          final isCompleted = userProgress?.isCompleted ?? false;
          final totalModules = plan.totalModules < 1 ? 1 : plan.totalModules;
          final rawCurrentDay = userProgress?.currentDay ?? 1;
          final currentDay = rawCurrentDay < 1
              ? 1
              : (rawCurrentDay > totalModules ? totalModules : rawCurrentDay);
          final completedModules = isCompleted
              ? totalModules
              : hasStarted
              ? (currentDay - 1 < 0 ? 0 : currentDay - 1)
              : 0;
          final progressFraction = totalModules <= 0
              ? 0.0
              : completedModules / totalModules;
          final currentModule = _moduleForDay(plan, currentDay);

          final userStatus = isCompleted
              ? 'Concluído'
              : hasStarted
              ? 'Em andamento (módulo $currentDay/$totalModules)'
              : (plan.isActive ? 'Disponível para iniciar' : 'Inativo');

          final actionIcon = isCompleted
              ? Icons.restart_alt
              : hasStarted
              ? Icons.play_circle_fill
              : Icons.play_arrow;
          final actionLabel = isCompleted
              ? 'REINICIAR PLANO'
              : hasStarted
              ? 'ABRIR MÓDULO $currentDay'
              : 'INICIAR PLANO';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: CommunityDesign.headerColor(context),
                elevation: 0,
                scrolledUnderElevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                expandedHeight: 250,
                pinned: true,
                centerTitle: false,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    plan.title,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                                style: CommunityDesign.metaStyle(context)
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          const SizedBox(width: 12),
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
                                  style: CommunityDesign.contentStyle(context)
                                      .copyWith(
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
                      if (plan.description != null &&
                          plan.description!.isNotEmpty) ...[
                        Text(
                          'Sobre o Plano',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          plan.description!,
                          style: CommunityDesign.contentStyle(context),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (hasStarted && !isCompleted) ...[
                        Container(
                          decoration: CommunityDesign.feedCardDecoration(
                            Theme.of(context).colorScheme,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Módulo Atual',
                                  style: CommunityDesign.titleStyle(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currentModule?.title ?? 'Módulo $currentDay',
                                  style: CommunityDesign.contentStyle(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dia $currentDay de $totalModules',
                                  style: CommunityDesign.contentStyle(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                  ),
                                  child: Text(
                                    _moduleReference(
                                      plan,
                                      currentDay,
                                      module: currentModule,
                                    ),
                                    style: CommunityDesign.metaStyle(context)
                                        .copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Abra o módulo para ver o conteúdo e marcar como lido.',
                                  style: CommunityDesign.metaStyle(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        decoration: CommunityDesign.feedCardDecoration(
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
                                icon: Icons.view_list,
                                label: 'Módulos',
                                value: '$totalModules',
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
                                value: userStatus,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: CommunityDesign.feedCardDecoration(
                          Theme.of(context).colorScheme,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progresso do Plano',
                                style: CommunityDesign.titleStyle(
                                  context,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: progressFraction,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$completedModules de $totalModules módulos concluídos',
                                style: CommunityDesign.contentStyle(context),
                              ),
                              if (hasStarted && !isCompleted) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Módulo atual: $currentDay',
                                  style: CommunityDesign.metaStyle(context),
                                ),
                              ],
                              if (isCompleted) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Plano finalizado. Você pode reiniciar e começar novamente.',
                                  style: CommunityDesign.metaStyle(context),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: CommunityDesign.feedCardDecoration(
                          Theme.of(context).colorScheme,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulos do Plano',
                                style: CommunityDesign.titleStyle(
                                  context,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Complete os módulos em sequência para concluir o plano.',
                                style: CommunityDesign.metaStyle(context),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 280,
                                child: ListView.separated(
                                  itemCount: totalModules,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final moduleDay = index + 1;
                                    final module = _moduleForDay(
                                      plan,
                                      moduleDay,
                                    );
                                    final done =
                                        hasStarted &&
                                        (isCompleted || moduleDay < currentDay);
                                    final isCurrent =
                                        (!hasStarted &&
                                            plan.isActive &&
                                            moduleDay == 1) ||
                                        (hasStarted &&
                                            !isCompleted &&
                                            moduleDay == currentDay);
                                    final canOpen = done || isCurrent;
                                    return _ReadingModuleRow(
                                      day: moduleDay,
                                      title:
                                          module?.title ?? 'Módulo $moduleDay',
                                      isDone: done,
                                      isCurrent: isCurrent,
                                      onTap: canOpen
                                          ? () => _openModule(
                                              context,
                                              plan: plan,
                                              day: moduleDay,
                                              totalModules: totalModules,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (!plan.isActive && !hasStarted)
                              ? null
                              : () async {
                                  if (!hasStarted) {
                                    await _startPlan(context, ref, plan: plan);
                                    return;
                                  }

                                  if (!isCompleted) {
                                    _openModule(
                                      context,
                                      plan: plan,
                                      day: currentDay,
                                      totalModules: totalModules,
                                    );
                                    return;
                                  }

                                  await _restartPlan(context, ref, plan: plan);
                                },
                          icon: Icon(actionIcon),
                          label: Text(actionLabel),
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
              Text(
                AppErrorHandler.userMessage(
                  error,
                  feature: 'reading_plans.load_plan',
                ),
              ),
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

class _ReadingModuleRow extends StatelessWidget {
  final int day;
  final String title;
  final bool isDone;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _ReadingModuleRow({
    required this.day,
    required this.title,
    required this.isDone,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = isDone
        ? Icons.check_circle
        : isCurrent
        ? Icons.play_circle_fill
        : Icons.lock_outline;
    final iconColor = isDone
        ? Colors.green
        : isCurrent
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.35);
    final statusLabel = isDone
        ? 'Concluído'
        : isCurrent
        ? 'Disponível para leitura'
        : 'Aguardando módulo anterior';

    final borderRadius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: isCurrent
                ? cs.primary.withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CommunityDesign.contentStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: cs.primaryContainer.withValues(alpha: 0.55),
                ),
                child: Text(
                  'Dia $day',
                  style: CommunityDesign.metaStyle(context).copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
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
