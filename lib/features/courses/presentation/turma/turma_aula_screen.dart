import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../../core/widgets/media/inline_video.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_subjects_section.dart';
import 'adapters/turma_surfaces.dart';
import 'tabs/aula_observacoes_tab.dart';
import 'tabs/turma_aulas_tab.dart';
import 'turma_access.dart';
import 'turma_detail_screen.dart';
import 'turma_mode.dart';
import 'turma_origin.dart';
import 'widgets/turma_sheet.dart';

/// Rota da tela da aula, pela mesma porta da turma: com [courseId] é a
/// vitrine de Cursos (leitura); sem, a porta de gestão.
String turmaLessonRoute({
  String? courseId,
  required String studyGroupId,
  required String lessonId,
}) => courseId == null
    ? '/turmas/$studyGroupId/gestao/aulas/$lessonId'
    : '/courses/$courseId/turmas/$studyGroupId/aulas/$lessonId';

/// Tela da aula (PR 1b do módulo acadêmico): tudo o que é daquela aula,
/// no desenho da tela da turma — cabeçalho e abas.
///
/// Herda da turma o papel ([turmaAccessProvider]), a origem e a porta
/// ([TurmaMode]); as mesmas respostas de "sem acesso". Aula de outra turma,
/// ou rascunho para o aluno (a RLS já esconde), vira "Aula não encontrada".
class TurmaAulaScreen extends ConsumerWidget {
  final String? courseId;
  final String studyGroupId;
  final String lessonId;
  final TurmaMode mode;

  const TurmaAulaScreen({
    super.key,
    this.courseId,
    required this.studyGroupId,
    required this.lessonId,
    this.mode = TurmaMode.leitura,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turmaAsync = ref.watch(turmaByIdProvider(studyGroupId));
    final accessAsync = ref.watch(turmaAccessProvider(studyGroupId));
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));
    const title = 'Aula';

    if (turmaAsync.isLoading ||
        accessAsync.isLoading ||
        lessonAsync.isLoading) {
      return const TurmaMessageScaffold(
        title: title,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (turmaAsync.hasError || accessAsync.hasError || lessonAsync.hasError) {
      return TurmaMessageScaffold(
        title: title,
        child: TurmaMessage.error(
          message: 'Não foi possível abrir a aula.',
          onRetry: () {
            ref.invalidate(turmaByIdProvider(studyGroupId));
            ref.invalidate(turmaAccessProvider(studyGroupId));
            ref.invalidate(lessonByIdProvider(lessonId));
          },
        ),
      );
    }

    final turma = turmaAsync.value;
    final role = accessAsync.value ?? TurmaAccess.none;
    final access = mode == TurmaMode.leitura ? role.asReadOnly() : role;
    final origin = ref.watch(turmaOriginProvider(studyGroupId)).value;
    if (turma == null ||
        origin == null ||
        (courseId != null && turma.courseId != courseId) ||
        !access.hasAccess) {
      return const TurmaMessageScaffold(
        title: title,
        child: TurmaMessage(
          icon: AppIcons.lock,
          message: 'Você não tem acesso a esta aula.',
        ),
      );
    }

    final lesson = lessonAsync.value;
    if (lesson == null ||
        lesson.studyGroupId != studyGroupId ||
        (!access.isLeadership && lesson.status != LessonStatus.published)) {
      return const TurmaMessageScaffold(
        title: title,
        child: TurmaMessage(
          icon: AppIcons.info,
          message: 'Aula não encontrada.',
        ),
      );
    }

    return TurmaAulaView(
      lesson: lesson,
      access: access,
      surfaces: turmaSurfacesFor(origin, access),
    );
  }
}

/// As abas da tela da aula. Todo papel vê as três; o que muda é o
/// conteúdo de Presença e Observações. Os materiais ficam no fim de
/// Conteúdo.
enum AulaTabId {
  conteudo('Conteúdo'),
  presenca('Presença'),
  observacoes('Observações');

  final String label;

  const AulaTabId(this.label);
}

/// Corpo da tela da aula, já com aula, papel e superfícies resolvidos.
class TurmaAulaView extends ConsumerStatefulWidget {
  final StudyLesson lesson;
  final TurmaAccess access;
  final TurmaSurfaces surfaces;

  const TurmaAulaView({
    super.key,
    required this.lesson,
    required this.access,
    required this.surfaces,
  });

  @override
  ConsumerState<TurmaAulaView> createState() => _TurmaAulaViewState();
}

class _TurmaAulaViewState extends ConsumerState<TurmaAulaView> {
  AulaTabId _tab = AulaTabId.conteudo;

  bool get _canWrite =>
      widget.access.isLeadership && widget.access.canWriteLessons;

  Widget _buildTab(AulaTabId tab) {
    final lesson = widget.lesson;
    return switch (tab) {
      AulaTabId.conteudo => LessonContentTab(
        lesson: lesson,
        materials: LessonComplementaryMaterials(
          lessonId: lesson.id,
          canWrite: _canWrite,
        ),
      ),
      AulaTabId.presenca => widget.surfaces.lessonPresence(lesson),
      AulaTabId.observacoes => AulaObservacoesTab(
        lessonId: lesson.id,
        access: widget.access,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final next = lessonNextStep(lesson.status);
    final date = lesson.scheduledDate;
    final courseId = ref
        .watch(turmaByIdProvider(lesson.studyGroupId))
        .valueOrNull
        ?.courseId;
    final subject = lesson.subjectId == null || courseId == null
        ? null
        : ref
              .watch(courseSubjectsProvider(courseId))
              .valueOrNull
              ?.where((s) => s.id == lesson.subjectId)
              .firstOrNull;
    final teacher = memberNameById(ref, lesson.teacherId);
    final when = [
      if (date != null) DateFormat('dd/MM/yyyy').format(date),
      ?lesson.startTime,
    ].join(' · ');

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
          'Aula ${lesson.lessonNumber} · ${lesson.title}',
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.w800, height: 1.15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_canWrite)
            PopupMenuButton<String>(
              key: const ValueKey('aula-acoes'),
              tooltip: 'Ações da aula',
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'status', child: Text(next.label)),
              ],
              onSelected: (value) => value == 'edit'
                  ? openTurmaLessonForm(
                      context,
                      ref,
                      studyGroupId: lesson.studyGroupId,
                      nextNumber: lesson.lessonNumber,
                      lesson: lesson,
                    )
                  : setTurmaLessonStatus(
                      context,
                      ref,
                      studyGroupId: lesson.studyGroupId,
                      lesson: lesson,
                      status: next.to,
                    ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: CommunityDesign.headerColor(context),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.access.isLeadership)
                  StatusBadge(
                    label: lesson.status.displayName,
                    tone: lessonStatusTone(lesson.status),
                  ),
                if (when.isNotEmpty)
                  Text(when, style: CommunityDesign.metaStyle(context)),
                if (subject != null)
                  Text(
                    subject.title,
                    style: CommunityDesign.metaStyle(context),
                  ),
                if (teacher != null)
                  Text(
                    'Professor: $teacher',
                    style: CommunityDesign.metaStyle(context),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: AppTabs(
              tabs: [
                for (final tab in AulaTabId.values) AppTab(label: tab.label),
              ],
              selectedIndex: _tab.index,
              onChanged: (i) => setState(() => _tab = AulaTabId.values[i]),
            ),
          ),
          Expanded(
            child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab(_tab)),
          ),
        ],
      ),
    );
  }
}

/// Aba Conteúdo: vídeo (tocando no app) e PDF da aula, descrição,
/// referências, texto, perguntas e, no fim, os [materials] da aula.
class LessonContentTab extends StatelessWidget {
  final StudyLesson lesson;
  final Widget? materials;

  const LessonContentTab({super.key, required this.lesson, this.materials});

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final body = Theme.of(context).textTheme.bodyMedium;
    final questions = lesson.discussionQuestions ?? const <String>[];
    final videoUrl = blankToNull(lesson.videoUrl);
    final pdfUrl = blankToNull(lesson.pdfUrl);

    final sections = [
      ('Descrição', blankToNull(lesson.description)),
      ('Referências bíblicas', blankToNull(lesson.bibleReferences)),
      ('Conteúdo', blankToNull(lesson.content)),
      (
        'Perguntas para discussão',
        questions.isEmpty
            ? null
            : [for (final q in questions) '• $q'].join('\n'),
      ),
    ];
    final empty =
        videoUrl == null &&
        pdfUrl == null &&
        sections.every((s) => s.$2 == null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (videoUrl != null) ...[
          InlineVideo(url: videoUrl),
          const SizedBox(height: 12),
        ],
        if (pdfUrl != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => openLessonLink(context, pdfUrl),
              icon: const Icon(AppIcons.pdf, size: 18),
              label: const Text('Abrir PDF'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final (label, text) in sections)
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: meta.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: body),
                ],
              ),
            ),
        if (empty) Text('Esta aula ainda não tem conteúdo.', style: meta),
        if (materials != null) ...[const SizedBox(height: 24), materials!],
      ],
    );
  }
}
