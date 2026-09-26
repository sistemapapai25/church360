import 'package:flutter/material.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';

/// Estado das abas Alunos e Presença quando a turma travada
/// (`lockedTurmaId`) não é deste ministério — ou sumiu.
///
/// Fail-closed: a aba não mostra nada, nem "todas as turmas" nem a
/// primeira da lista. Em uso normal não aparece, porque a tela da turma tira
/// ministério e turma da mesma linha de `study_groups`; existe para o dia
/// em que isso deixar de ser verdade.
class BaptismLockedTurmaUnavailable extends StatelessWidget {
  const BaptismLockedTurmaUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('baptism-locked-turma-unavailable'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.lock,
              size: 40,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Esta turma não está disponível neste ministério.',
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}
