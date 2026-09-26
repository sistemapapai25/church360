import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../domain/models/course_turma.dart';
import '../hub/course_hub.dart';
import '../providers/courses_provider.dart';

/// Tom do selo de situação da turma (card do curso e cabeçalho da turma).
AppStatusTone courseTurmaStatusTone(StudyGroupStatus status) {
  return switch (status) {
    StudyGroupStatus.active => AppStatusTone.active,
    StudyGroupStatus.completed => AppStatusTone.done,
    StudyGroupStatus.paused ||
    StudyGroupStatus.cancelled => AppStatusTone.dropped,
  };
}

/// Seção "Turmas" da tela do curso.
///
/// Carrega sozinha, com provider próprio: erro ou lentidão aqui não pode
/// derrubar o resto da tela (capa, informações e aulas continuam de pé).
///
/// Contextual (Etapa 6): a gestão vê todas as turmas que a RLS entrega; o
/// aluno só a dele; quem não é nenhum dos dois não vê a seção — o caminho
/// dele é a chamada do curso ("Inscrever-se"). Enquanto o papel não chega,
/// vale a lista da RLS, que já é a autoridade.
class CourseTurmasSection extends ConsumerWidget {
  final String courseId;

  const CourseTurmasSection({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turmasAsync = ref.watch(courseStudyGroupsProvider(courseId));
    final hub = ref.watch(courseHubProvider(courseId)).valueOrNull;
    final contextual = hub != null && !hub.management;

    if (contextual) {
      final all = turmasAsync.valueOrNull ?? const <CourseTurma>[];
      if (!all.any(hub.showsTurma)) return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            context,
            contextual
                ? turmasAsync.valueOrNull?.where(hub.showsTurma).length
                : turmasAsync.asData?.value.length,
            title: contextual ? 'Minha turma' : 'Turmas',
          ),
          const SizedBox(height: 16),
          turmasAsync.when(
            data: (all) {
              final turmas = contextual
                  ? all.where(hub.showsTurma).toList()
                  : all;
              if (turmas.isEmpty) return _buildEmpty(context);
              // Column e não ListView: a seção vive dentro do scroll da
              // tela, e poucas turmas por curso não pedem construção lazy.
              return Column(
                children: [
                  for (final turma in turmas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TurmaCard(turma: turma, courseId: courseId),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _buildError(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int? count, {
    required String title,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: CommunityDesign.metaStyle(context).copyWith(
                color: cs.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Icon(
            AppIcons.study,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma turma neste curso ainda.',
              style: CommunityDesign.contentStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Erro contido na seção, com retry. O detalhe técnico fica fora da
  /// tela: quem vê é aluno, não quem depura.
  Widget _buildError(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Icon(AppIcons.error, size: 20, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Não foi possível carregar as turmas.',
              style: CommunityDesign.contentStyle(context),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.invalidate(courseStudyGroupsProvider(courseId)),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class _TurmaCard extends StatelessWidget {
  final CourseTurma turma;
  final String courseId;

  const _TurmaCard({required this.turma, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = courseTurmaStatusTone(turma.status);
    final toneColor = tone.color(context);
    final dates = turma.periodLabel;

    return GlassCard(
      onTap: () => context.push(turma.routeWithin(courseId)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: toneColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppIcons.study, size: 20, color: toneColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turma.name,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dates != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        AppIcons.calendar,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dates,
                          style: CommunityDesign.metaStyle(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: turma.status.displayName, tone: tone),
        ],
      ),
    );
  }
}
