import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/reading_plan.dart';
import '../providers/reading_plans_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

class ReadingPlanModuleScreen extends ConsumerStatefulWidget {
  final String planId;
  final int moduleDay;

  const ReadingPlanModuleScreen({
    super.key,
    required this.planId,
    required this.moduleDay,
  });

  @override
  ConsumerState<ReadingPlanModuleScreen> createState() =>
      _ReadingPlanModuleScreenState();
}

class _ReadingPlanModuleScreenState
    extends ConsumerState<ReadingPlanModuleScreen> {
  bool _isSaving = false;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.go('/reading-plans/${widget.planId}');
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

  String _moduleContent(
    ReadingPlan plan,
    int day, {
    ReadingPlanModule? module,
  }) {
    final explicitContent = module?.content?.trim();
    if (explicitContent != null && explicitContent.isNotEmpty) {
      return explicitContent;
    }

    final intro = plan.description?.trim().isNotEmpty == true
        ? plan.description!.trim()
        : 'Siga a jornada proposta para este plano.';
    return '$intro\n\nObjetivo do dia $day: leia o conteúdo indicado, reflita e registre um aprendizado.';
  }

  Future<void> _ensureStartedIfPossible({
    required ReadingPlan plan,
    required String memberId,
  }) async {
    final repo = ref.read(readingPlansRepositoryProvider);
    await repo.startPlan(plan.id, memberId);
    await _refreshProgress(ref, planId: plan.id, memberId: memberId);
  }

  Future<void> _markModuleAsRead({
    required ReadingPlan plan,
    required int totalModules,
    required int moduleDay,
    required int currentDay,
    required bool hasStarted,
    required bool isCompleted,
  }) async {
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para registrar progresso')),
      );
      return;
    }

    if (isCompleted || moduleDay != currentDay) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este módulo não está disponível para concluir'),
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);
      if (!hasStarted) {
        await _ensureStartedIfPossible(plan: plan, memberId: member.id);
      }

      final repo = ref.read(readingPlansRepositoryProvider);
      final updated = await repo.markCurrentDayAsRead(
        planId: plan.id,
        memberId: member.id,
        totalDays: totalModules,
      );

      await _refreshProgress(ref, planId: plan.id, memberId: member.id);

      if (!mounted) return;
      final finished = updated.isCompleted;
      final message = finished
          ? 'Último módulo concluído! Plano finalizado.'
          : 'Módulo $moduleDay concluído. Próximo módulo: ${updated.currentDay}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.mark_module_read',
        fallbackMessage:
            'Nao foi possivel registrar este modulo como lido. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final planAsync = ref.watch(readingPlanByIdProvider(widget.planId));
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        titleSpacing: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dia ${widget.moduleDay}',
              style: CommunityDesign.titleStyle(context),
            ),
            Text(
              'Módulo do Plano de Leitura',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
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
                    onPressed: _handleBack,
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          final member = currentMemberAsync.valueOrNull;
          final progressAsync = member == null
              ? const AsyncValue<ReadingPlanProgress?>.data(null)
              : ref.watch(
                  userPlanProgressProvider((
                    planId: plan.id,
                    memberId: member.id,
                  )),
                );
          final progress = progressAsync.valueOrNull;
          final hasStarted = progress != null;
          final isCompleted = progress?.isCompleted ?? false;

          final totalModules = plan.totalModules < 1 ? 1 : plan.totalModules;
          final moduleDay = widget.moduleDay < 1
              ? 1
              : (widget.moduleDay > totalModules
                    ? totalModules
                    : widget.moduleDay);
          final rawCurrentDay = progress?.currentDay ?? 1;
          final currentDay = rawCurrentDay < 1
              ? 1
              : (rawCurrentDay > totalModules ? totalModules : rawCurrentDay);

          final module = _moduleForDay(plan, moduleDay);
          final isDone = isCompleted || (hasStarted && moduleDay < currentDay);
          final isCurrent = !isCompleted && moduleDay == currentDay;
          final isLocked = hasStarted && !isCompleted && moduleDay > currentDay;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: CommunityDesign.feedCardDecoration(cs),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: cs.primaryContainer,
                          ),
                          child: Text(
                            _moduleReference(plan, moduleDay, module: module),
                            style: CommunityDesign.metaStyle(context).copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isDone)
                          _StatusChip(label: 'Concluído', color: Colors.green)
                        else if (isLocked)
                          _StatusChip(
                            label: 'Bloqueado',
                            color: cs.onSurface.withValues(alpha: 0.45),
                          )
                        else if (isCurrent)
                          _StatusChip(label: 'Disponível', color: cs.primary),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      module?.title ?? 'Módulo $moduleDay',
                      style: CommunityDesign.contentStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _moduleContent(plan, moduleDay, module: module),
                      style: CommunityDesign.contentStyle(context),
                    ),
                  ],
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
                  feature: 'reading_plans.load_module',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(readingPlanByIdProvider(widget.planId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: planAsync.when(
        data: (plan) {
          if (plan == null) return null;
          final member = currentMemberAsync.valueOrNull;
          final progressAsync = member == null
              ? const AsyncValue<ReadingPlanProgress?>.data(null)
              : ref.watch(
                  userPlanProgressProvider((
                    planId: plan.id,
                    memberId: member.id,
                  )),
                );
          final progress = progressAsync.valueOrNull;

          final totalModules = plan.totalModules < 1 ? 1 : plan.totalModules;
          final moduleDay = widget.moduleDay < 1
              ? 1
              : (widget.moduleDay > totalModules
                    ? totalModules
                    : widget.moduleDay);

          final hasStarted = progress != null;
          final isCompleted = progress?.isCompleted ?? false;
          final rawCurrentDay = progress?.currentDay ?? 1;
          final currentDay = rawCurrentDay < 1
              ? 1
              : (rawCurrentDay > totalModules ? totalModules : rawCurrentDay);

          final isDone = isCompleted || (hasStarted && moduleDay < currentDay);
          final isCurrent = !isCompleted && moduleDay == currentDay;
          final isLocked = hasStarted && !isCompleted && moduleDay > currentDay;

          final canConclude =
              member != null &&
              !_isSaving &&
              (isCurrent || (!hasStarted && moduleDay == 1));
          final buttonLabel = _isSaving
              ? 'Salvando...'
              : isDone
              ? 'Módulo já concluído'
              : isLocked
              ? 'Módulo bloqueado'
              : 'Marcar como lido';

          return Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Center(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                    disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                  ),
                  onPressed: canConclude && !isDone && !isLocked
                      ? () async {
                          await _markModuleAsRead(
                            plan: plan,
                            totalModules: totalModules,
                            moduleDay: moduleDay,
                            currentDay: currentDay,
                            hasStarted: hasStarted,
                            isCompleted: isCompleted,
                          );
                        }
                      : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isDone ? Icons.check_circle : Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: Text(
                    member == null ? 'Faça login para concluir' : buttonLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: CommunityDesign.metaStyle(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
