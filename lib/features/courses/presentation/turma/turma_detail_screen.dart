import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_turmas_section.dart';
import 'adapters/turma_surfaces.dart';
import 'tabs/turma_aulas_tab.dart';
import 'tabs/turma_materiais_tab.dart';
import 'turma_access.dart';
import 'turma_aula_screen.dart';
import 'turma_mode.dart';
import 'turma_origin.dart';
import 'turma_tabs.dart';

/// Tela da turma. Duas rotas, uma tela:
///
/// - `/courses/:courseId/turmas/:studyGroupId` (decisão 23 do
///   ROADMAP-FORMACAO), a porta de Cursos, em [TurmaMode.leitura];
/// - `/turmas/:studyGroupId/gestao`, a porta de gestão — o sheet de Turmas
///   do Batismo e o botão "Gerenciar" da turma genérica.
///
/// Uma turma, uma tela: Batismo e turma genérica abrem aqui. O que varia
/// vem de três lugares separados — a origem (`turmaOriginProvider`), o
/// papel de quem abriu ([turmaAccessProvider]) e a porta ([TurmaMode]).
/// Fora do `MinistryWorkspaceShell` de propósito: não é tela de ministério.
///
/// Em Cursos a tela é vitrine: o papel continua valendo para *ver* (a
/// liderança segue vendo rascunho, Alunos e Presença), mas toda gravação
/// some — quem edita entra pela porta de gestão.
///
/// Sem guard no router, como `/courses/:id/view`. Quem não enxerga o grupo
/// pela RLS, quem não tem papel nele e quem chega por um `:courseId` que não
/// é o da turma recebem a mesma resposta, sem distinguir "não existe" de
/// "não pode".
class TurmaDetailScreen extends ConsumerStatefulWidget {
  /// O curso da rota de Cursos. `null` na porta de gestão, que não passa
  /// por curso nenhum — o link do curso sai do próprio grupo.
  final String? courseId;

  final String studyGroupId;
  final TurmaMode mode;

  /// Aberta pela Dashboard: só então a porta de leitura mostra a saída
  /// para a gestão ("Gerenciar no Batismo" / "Gerenciar").
  final bool fromDashboard;

  const TurmaDetailScreen({
    super.key,
    this.courseId,
    required this.studyGroupId,
    this.mode = TurmaMode.leitura,
    this.fromDashboard = false,
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

  /// "Participar" de turma pública: o banco confere se está aberta e se há
  /// vaga (`turma_join`).
  Future<void> _join() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(studyGroupRepositoryProvider)
          .joinTurma(widget.studyGroupId);
      ref.invalidate(turmaMyParticipationProvider(widget.studyGroupId));
      ref.invalidate(turmaAccessProvider(widget.studyGroupId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Você agora participa desta turma.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('TURMA_LOTADA')
                ? 'Esta turma já está lotada.'
                : 'Não foi possível entrar na turma agora.',
          ),
        ),
      );
    }
  }

  /// Aulas e Materiais são iguais para qualquer turma; Alunos e Minha
  /// frequência vêm da origem ([turmaSurfacesFor]). A chamada fica na tela
  /// da aula.
  Widget _buildTab(TurmaTabId tab, TurmaSurfaces surfaces, TurmaAccess access) {
    return switch (tab) {
      TurmaTabId.aulas => TurmaAulasTab(
        studyGroupId: widget.studyGroupId,
        access: access,
        onOpenLesson: (lesson) => context.push(
          turmaLessonRoute(
            courseId: widget.courseId,
            studyGroupId: widget.studyGroupId,
            lessonId: lesson.id,
          ),
        ),
      ),
      TurmaTabId.materiais => TurmaMateriaisTab(
        studyGroupId: widget.studyGroupId,
        access: access,
      ),
      TurmaTabId.alunos => surfaces.alunos(),
      TurmaTabId.minhaFrequencia => surfaces.minhaFrequencia(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final turmaAsync = ref.watch(turmaByIdProvider(widget.studyGroupId));
    final accessAsync = ref.watch(turmaAccessProvider(widget.studyGroupId));

    if (turmaAsync.isLoading || accessAsync.isLoading) {
      return const TurmaMessageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (turmaAsync.hasError || accessAsync.hasError) {
      return TurmaMessageScaffold(
        child: _TurmaMessage(
          icon: AppIcons.info,
          message: 'Não foi possível abrir a turma. Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: _retry,
        ),
      );
    }

    final turma = turmaAsync.value;
    // O papel é o mesmo nas duas portas; o que muda é o que ele grava.
    final role = accessAsync.value ?? TurmaAccess.none;
    final access = widget.mode == TurmaMode.leitura ? role.asReadOnly() : role;
    // Já carregada: o acesso depende da origem.
    final origin = ref.watch(turmaOriginProvider(widget.studyGroupId)).value;
    if (turma != null &&
        turma.status == StudyGroupStatus.cancelled &&
        !access.isLeadership) {
      return const TurmaMessageScaffold(
        child: _TurmaMessage(
          icon: AppIcons.info,
          message: 'Esta turma foi cancelada.',
        ),
      );
    }
    if (turma == null ||
        origin == null ||
        (widget.courseId != null && turma.courseId != widget.courseId) ||
        !access.hasAccess) {
      final canJoin =
          turma != null &&
          origin != null &&
          turmaSurfacesFor(origin, access).acceptsJoin &&
          turma.isPublic &&
          turma.status == StudyGroupStatus.active &&
          (widget.courseId == null || turma.courseId == widget.courseId);
      return TurmaMessageScaffold(
        child: _TurmaMessage(
          icon: canJoin ? AppIcons.study : AppIcons.lock,
          message: canJoin
              ? 'Esta turma está aberta. Participe para ver as aulas e a '
                    'sua frequência.'
              : 'Você não tem acesso a esta turma.',
          actionLabel: canJoin ? 'Participar' : null,
          onAction: canJoin ? _join : null,
        ),
      );
    }

    final tabs = turmaTabsFor(access);
    final selected = _selected.clamp(0, tabs.length - 1);
    final active = tabs[selected];
    final surfaces = turmaSurfacesFor(origin, access);
    // Saída da vitrine: só na porta de leitura e só para quem edita algo
    // do outro lado. Para o aluno não há para onde ir.
    final manage =
        widget.mode == TurmaMode.leitura &&
            widget.fromDashboard &&
            role.isLeadership
        ? surfaces.manage
        : null;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          tooltip: 'Voltar',
          onPressed: () => (context.canPop() ? context.pop() : context.go('/home')),
        ),
        title: Text(
          turma.name,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.w800, height: 1.15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [if (manage != null) _ManageAction(target: manage)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TurmaHeader(
            turma: turma,
            courseId: widget.courseId ?? turma.courseId,
          ),
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
              child: _buildTab(active, surfaces, access),
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

  /// `null` só em turma sem curso (grupo antigo, até a Etapa 8): aí a
  /// faixa perde o link e mantém o resto.
  final String? courseId;

  const _TurmaHeader({required this.turma, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final courseId = this.courseId;
    final courseTitle = courseId == null
        ? null
        : ref
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
          if (courseId != null)
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
                    style: CommunityDesign.metaStyle(
                      context,
                    ).copyWith(color: accent, fontWeight: FontWeight.w700),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
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

/// Saída da vitrine: onde esta turma se edita.
///
/// Só aparece na porta de Cursos e só para a liderança — o aluno não tem
/// para onde ir. O destino é da origem, não desta tela: quem responde é o
/// adapter, em `manage`.
class _ManageAction extends StatelessWidget {
  final TurmaManageTarget target;

  const _ManageAction({required this.target});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        key: const ValueKey('turma-gerenciar'),
        onPressed: () => context.push(target.route),
        icon: const Icon(AppIcons.tune, size: 18),
        label: Text(target.label),
      ),
    );
  }
}

class TurmaMessageScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const TurmaMessageScaffold({
    super.key,
    this.title = 'Turma',
    required this.child,
  });

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
          onPressed: () => (context.canPop() ? context.pop() : context.go('/home')),
        ),
        title: Text(title),
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
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
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
