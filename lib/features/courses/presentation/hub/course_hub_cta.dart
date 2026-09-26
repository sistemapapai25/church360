import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import 'course_enroll_sheet.dart';
import 'course_hub.dart';

/// Chamada por estado da tela do curso (decisão 24).
///
/// Carrega à parte, como a seção Turmas: erro aqui some com o botão, não
/// com a tela. Quem decide o acesso de verdade é a RLS; isto só escolhe o
/// caminho mais curto para cada um.
class CourseHubCta extends ConsumerWidget {
  final String courseId;

  /// Rola até a seção Turmas ("Ver turmas / Gerenciar").
  final VoidCallback onManage;

  const CourseHubCta({
    super.key,
    required this.courseId,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(courseHubProvider(courseId)).valueOrNull;
    if (hub == null) return const SizedBox.shrink();

    final Widget primary;
    switch (hub.primary) {
      case CourseCta.none:
        return const SizedBox.shrink();
      case CourseCta.myTurma:
        primary = FilledButton.icon(
          onPressed: () => _openMyTurma(context, hub.myTurmas),
          icon: const Icon(Icons.school_outlined),
          label: const Text('Acessar minha turma'),
        );
      case CourseCta.manage:
        primary = FilledButton.icon(
          onPressed: onManage,
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Ver turmas / Gerenciar'),
        );
      case CourseCta.enroll:
        primary = FilledButton.icon(
          onPressed: () => _enroll(context, ref, hub),
          icon: const Icon(Icons.how_to_reg_outlined),
          label: const Text('Inscrever-se'),
        );
      case CourseCta.closed:
        primary = const FilledButton(
          onPressed: null,
          child: Text('Inscrições fechadas'),
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 48, child: primary),
          if (hub.showManageSecondary) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: onManage,
                child: const Text('Gerenciar'),
              ),
            ),
          ],
          if (hub.primary == CourseCta.closed) ...[
            const SizedBox(height: 8),
            Text(
              'Nenhuma turma está aceitando inscrição agora. Fale com a '
              'liderança para saber quando a próxima começa.',
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ],
      ),
    );
  }

  void _openMyTurma(BuildContext context, List<CourseTurma> turmas) {
    if (turmas.length == 1) {
      context.push(turmas.single.routeWithin(courseId));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suas turmas',
              style: CommunityDesign.titleStyle(
                sheetContext,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final turma in turmas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push(turma.routeWithin(courseId));
                  },
                  child: Text(
                    turma.name,
                    style: CommunityDesign.titleStyle(
                      sheetContext,
                    ).copyWith(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enroll(
    BuildContext context,
    WidgetRef ref,
    CourseHubState hub,
  ) async {
    final ministryId = hub.ministryId;
    if (ministryId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final result = await showCourseEnrollSheet(
      context,
      ministryId: ministryId,
      turmas: hub.openTurmas,
    );
    if (result != CourseEnrollResult.enrolled) return;

    invalidateAfterCourseEnroll(ref, ministryId);
    ref.invalidate(courseStudyGroupsProvider(courseId));
    ref.invalidate(courseHubProvider(courseId));

    var linked = false;
    try {
      linked = (await ref.read(courseHubProvider(courseId).future)).isStudent;
    } catch (_) {}

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          linked
              ? 'Inscrição feita! Sua turma já está liberada aqui no curso.'
              : 'Inscrição feita! Quando a liderança ligar a inscrição ao '
                    'seu cadastro, sua turma aparece aqui.',
        ),
      ),
    );
  }
}
