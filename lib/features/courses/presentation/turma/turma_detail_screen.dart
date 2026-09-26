import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_turmas_section.dart';
import 'adapters/turma_surfaces.dart';
import 'tabs/turma_aulas_tab.dart';
import 'tabs/turma_materiais_tab.dart';
import 'turma_access.dart';
import 'turma_origin.dart';
import 'turma_tabs.dart';

/// Tela da turma, rota canônica `/courses/:courseId/turmas/:studyGroupId`
/// (decisão 23 do ROADMAP-FORMACAO).
///
/// Uma turma, uma tela: Batismo e turma genérica abrem aqui. O que varia
/// vem de dois lugares separados — a origem (`turmaOriginProvider`) e o
/// papel de quem abriu ([turmaAccessProvider]). Fora do
/// `MinistryWorkspaceShell` de propósito: não é tela de ministério.
///
/// Sem guard no router, como `/courses/:id/view`. Quem não enxerga o grupo
/// pela RLS, quem não tem papel nele e quem chega por um `:courseId` que não
/// é o da turma recebem a mesma resposta, sem distinguir "não existe" de
/// "não pode".
class TurmaDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String studyGroupId;

  const TurmaDetailScreen({
    super.key,
    required this.courseId,
    required this.studyGroupId,
  });

  @override
  ConsumerState<TurmaDetailScreen> createState() => _TurmaDetailScreenState();
}

class _TurmaDetailScreenState extends ConsumerState<TurmaDetailScreen> {
  int _selected = 0;

  void _retry() {
    ref.invalidate(turmaByIdProvider(widget.studyGroupId));
    ref.invalidate(turmaAccessProvider(widget.studyGroupId));
  }

  /// Aulas e Materiais são iguais para qualquer turma; Alunos, Presença e
  /// Minha frequência vêm da origem ([turmaSurfacesFor]).
  Widget _buildTab(TurmaTabId tab, TurmaOrigin origin, TurmaAccess access) {
    final surfaces = turmaSurfacesFor(origin, access);
    return switch (tab) {
      TurmaTabId.aulas => TurmaAulasTab(
        studyGroupId: widget.studyGroupId,
        access: access,
        lessonAttendance: surfaces.lessonAttendance,
      ),
      TurmaTabId.materiais => TurmaMateriaisTab(
        studyGroupId: widget.studyGroupId,
        access: access,
      ),
      TurmaTabId.alunos => surfaces.alunos(),
      TurmaTabId.presenca => surfaces.presenca(),
      TurmaTabId.minhaFrequencia => surfaces.minhaFrequencia(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final turmaAsync = ref.watch(turmaByIdProvider(widget.studyGroupId));
    final accessAsync = ref.watch(turmaAccessProvider(widget.studyGroupId));

    if (turmaAsync.isLoading || accessAsync.isLoading) {
      return const _TurmaMessageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (turmaAsync.hasError || accessAsync.hasError) {
      return _TurmaMessageScaffold(
        child: _TurmaMessage(
          icon: AppIcons.info,
          message: 'Não foi possível abrir a turma. Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: _retry,
        ),
      );
    }

    final turma = turmaAsync.value;
    final access = accessAsync.value ?? TurmaAccess.none;
    // Já carregada: o acesso depende da origem.
    final origin = ref.watch(turmaOriginProvider(widget.studyGroupId)).value;
    if (turma == null ||
        origin == null ||
        turma.courseId != widget.courseId ||
        !access.hasAccess) {
      return const _TurmaMessageScaffold(
        child: _TurmaMessage(
          icon: AppIcons.lock,
          message: 'Você não tem acesso a esta turma.',
        ),
      );
    }

    final tabs = turmaTabsFor(access);
    final selected = _selected.clamp(0, tabs.length - 1);
    final active = tabs[selected];

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: Text(
          turma.name,
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TurmaHeader(turma: turma, courseId: widget.courseId),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: AppTabs(
              tabs: [for (final tab in tabs) AppTab(label: tab.label)],
              selectedIndex: selected,
              onChanged: (i) => setState(() => _selected = i),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(active),
              child: _buildTab(active, origin, access),
            ),
          ),
        ],
      ),
    );
  }
}

/// Última faixa do cabeçalho, na cor da barra: curso (com link), situação e
/// período.
class _TurmaHeader extends ConsumerWidget {
  final CourseTurma turma;
  final String courseId;

  const _TurmaHeader({required this.turma, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final courseTitle = ref
        .watch(courseByIdProvider(courseId))
        .maybeWhen(data: (c) => c?.title, orElse: () => null);
    final period = turma.periodLabel;

    return Container(
      color: CommunityDesign.headerColor(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            key: const ValueKey('turma-course-link'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/courses/$courseId/view'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.study, size: 16, color: accent),
                const SizedBox(width: 4),
                Text(
                  courseTitle ?? 'Ver curso',
                  style: CommunityDesign.metaStyle(context).copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: turma.status.displayName,
            tone: courseTurmaStatusTone(turma.status),
          ),
          if (period != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(period, style: CommunityDesign.metaStyle(context)),
              ],
            ),
        ],
      ),
    );
  }
}

class _TurmaMessageScaffold extends StatelessWidget {
  final Widget child;

  const _TurmaMessageScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text('Turma'),
      ),
      body: child,
    );
  }
}

class _TurmaMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TurmaMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
