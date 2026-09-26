import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/courses_provider.dart';

/// Destino de `/study-groups` (a antiga central de grupos): a aba Turmas
/// de Formação. Mantém o `from=dashboard` de quem veio do Dashboard.
String studyGroupsListRedirect(Uri uri) {
  final fromDashboard = uri.queryParameters['from'] == 'dashboard';
  return fromDashboard
      ? '/courses?tab=turmas&from=dashboard'
      : '/courses?tab=turmas';
}

/// `/study-groups/:id` de antes da Etapa 6 (links compartilhados, jornada
/// da Home, favoritos).
///
/// Turma com curso troca para a rota canônica
/// `/courses/:courseId/turmas/:id` (decisão 23). Sem curso, ou quando a RLS
/// não mostra a turma (visitante sem login do link público), fica na tela
/// antiga — que tem a própria guarda.
class LegacyStudyGroupRedirect extends ConsumerWidget {
  final String studyGroupId;
  final Widget fallback;

  const LegacyStudyGroupRedirect({
    super.key,
    required this.studyGroupId,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turmaAsync = ref.watch(turmaByIdProvider(studyGroupId));

    return turmaAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => fallback,
      data: (turma) {
        final courseId = turma?.courseId;
        if (courseId == null) return fallback;
        final target = '/courses/$courseId/turmas/$studyGroupId';
        // Troca depois do frame: navegar dentro do build é proibido. O
        // scheduleFrame garante que o callback rode mesmo com a tela parada.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) GoRouter.of(context).replace(target);
        });
        SchedulerBinding.instance.scheduleFrame();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
