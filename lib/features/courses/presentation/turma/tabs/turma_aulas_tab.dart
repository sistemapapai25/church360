import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../../../study_groups/domain/models/study_group.dart';
import '../../../../study_groups/presentation/providers/study_group_provider.dart';
import '../adapters/turma_surfaces.dart';
import '../turma_access.dart';
import '../widgets/turma_sheet.dart';

/// Aba Aulas da tela da turma — igual para Batismo e turma genérica.
///
/// Liderança vê todas (rascunho, publicada, arquivada); aluno, só as
/// publicadas, que é também o que a RLS devolve a ele.
///
/// **Sem exclusão.** Apagar uma aula leva junto, por CASCADE, a presença e
/// os comentários dela (conferido no banco em 25/09). O ciclo é Rascunho →
/// Publicar → Arquivar → Restaurar (volta a rascunho).
///
/// Com [lessonAttendance] (hoje só o Batismo, Etapa 5.3) cada aula ganha
/// "Registrar presença" no menu de quem escreve aula.
class TurmaAulasTab extends ConsumerWidget {
  final String studyGroupId;
  final TurmaAccess access;
  final TurmaLessonAttendance? lessonAttendance;

  const TurmaAulasTab({
    super.key,
    required this.studyGroupId,
    required this.access,
    this.lessonAttendance,
  });

  FutureProvider<List<StudyLesson>> get _lessonsProvider => access.isLeadership
      ? groupLessonsProvider(studyGroupId)
      : publishedLessonsProvider(studyGroupId);

  void _invalidate(WidgetRef ref, [String? lessonId]) {
    ref.invalidate(groupLessonsProvider(studyGroupId));
    ref.invalidate(publishedLessonsProvider(studyGroupId));
    if (lessonId != null) ref.invalidate(lessonByIdProvider(lessonId));
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    List<StudyLesson> lessons, {
    StudyLesson? lesson,
  }) async {
    final nextNumber = lessons.isEmpty
        ? 1
        : lessons.map((l) => l.lessonNumber).reduce((a, b) => a > b ? a : b) +
              1;
    final saved = await showTurmaSheet<bool>(
      context: context,
      builder: (_) => _LessonFormSheet(
        studyGroupId: studyGroupId,
        nextNumber: nextNumber,
        lesson: lesson,
      ),
    );
    if (saved == true) _invalidate(ref, lesson?.id);
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    StudyLesson lesson,
    LessonStatus status,
  ) async {
    try {
      await ref
          .read(studyGroupRepositoryProvider)
          .updateLesson(lesson.id, status: status);
      _invalidate(ref, lesson.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(_lessonsProvider);
    final canWrite = access.isLeadership && access.canWriteLessons;

    return lessonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => TurmaMessage.error(
        message: 'Não foi possível carregar as aulas.',
        onRetry: () => _invalidate(ref),
      ),
      data: (lessons) {
        return RefreshIndicator(
          onRefresh: () async {
            _invalidate(ref);
            await ref.read(_lessonsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${lessons.length} '
                      '${lessons.length == 1 ? 'aula' : 'aulas'}',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ),
                  if (canWrite)
                    FilledButton.icon(
                      onPressed: () => _openForm(context, ref, lessons),
                      icon: const Icon(AppIcons.add, size: 18),
                      label: const Text('Nova aula'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (lessons.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: TurmaMessage(
                    icon: AppIcons.study,
                    message: access.isLeadership
                        ? 'Nenhuma aula cadastrada nesta turma ainda.'
                        : 'Nenhuma aula publicada ainda.',
                  ),
                )
              else
                for (final lesson in lessons)
                  _LessonCard(
                    key: ValueKey(lesson.id),
                    lesson: lesson,
                    showStatus: access.isLeadership,
                    canWrite: canWrite,
                    onRegisterAttendance: lessonAttendance == null
                        ? null
                        : () => lessonAttendance!(context, lesson),
                    onOpen: () => showTurmaSheet<void>(
                      context: context,
                      builder: (_) => _LessonReadSheet(lesson: lesson),
                    ),
                    onEdit: () =>
                        _openForm(context, ref, lessons, lesson: lesson),
                    onSetStatus: (status) =>
                        _setStatus(context, ref, lesson, status),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Próximo passo do ciclo de vida da aula, a partir do estado atual.
({LessonStatus to, String label}) lessonNextStep(LessonStatus status) {
  return switch (status) {
    LessonStatus.draft => (to: LessonStatus.published, label: 'Publicar'),
    LessonStatus.published => (to: LessonStatus.archived, label: 'Arquivar'),
    LessonStatus.archived => (to: LessonStatus.draft, label: 'Restaurar'),
  };
}

/// Link do vídeo/PDF principal da aula: vazio vira `null`; só aceita
/// `http(s)://` com host. Devolve `null` também quando inválido — quem
/// barra o link inválido no formulário é [lessonUrlError].
String? normalizeLessonUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty || lessonUrlError(text) != null) return null;
  return text;
}

/// Mensagem de erro do campo de link, ou `null` se vazio ou válido.
String? lessonUrlError(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final ok =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  return ok ? null : 'Informe um link que comece com https://';
}

/// Perguntas para discussão: uma por linha, sem linhas vazias. Nenhuma
/// pergunta vira `null` (coluna limpa), não lista vazia.
List<String>? parseLessonQuestions(String raw) {
  final questions = [
    for (final line in raw.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  return questions.isEmpty ? null : questions;
}

String? _blankToNull(String? raw) {
  final text = (raw ?? '').trim();
  return text.isEmpty ? null : text;
}

Future<void> _openLessonLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
}

AppStatusTone _tone(LessonStatus status) => switch (status) {
  LessonStatus.published => AppStatusTone.active,
  LessonStatus.draft => AppStatusTone.done,
  LessonStatus.archived => AppStatusTone.dropped,
};

class _LessonCard extends StatelessWidget {
  final StudyLesson lesson;
  final bool showStatus;
  final bool canWrite;
  final VoidCallback? onRegisterAttendance;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final ValueChanged<LessonStatus> onSetStatus;

  const _LessonCard({
    super.key,
    required this.lesson,
    required this.showStatus,
    required this.canWrite,
    this.onRegisterAttendance,
    required this.onOpen,
    required this.onEdit,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final date = lesson.scheduledDate;
    final next = lessonNextStep(lesson.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aula ${lesson.lessonNumber} · ${lesson.title}',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (showStatus || date != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (showStatus)
                          StatusBadge(
                            label: lesson.status.displayName,
                            tone: _tone(lesson.status),
                          ),
                        if (date != null)
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: CommunityDesign.metaStyle(context),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canWrite)
              PopupMenuButton<String>(
                tooltip: 'Ações da aula',
                itemBuilder: (context) => [
                  if (onRegisterAttendance != null)
                    const PopupMenuItem(
                      value: 'attendance',
                      child: Text('Registrar presença'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'status', child: Text(next.label)),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'attendance':
                      onRegisterAttendance?.call();
                    case 'edit':
                      onEdit();
                    case 'status':
                      onSetStatus(next.to);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Leitura da aula, para liderança e aluno.
///
/// A tela antiga `/study-groups/:id/lessons/:lessonId` exige a permissão
/// `study_groups.manage_lessons`; o aluno bateria nela. Por isso a leitura
/// fica aqui, numa folha.
class _LessonReadSheet extends StatelessWidget {
  final StudyLesson lesson;

  const _LessonReadSheet({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final body = Theme.of(context).textTheme.bodyMedium;
    final date = lesson.scheduledDate;

    Widget section(String label, String? text) {
      if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: meta.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text.trim(), style: body),
          ],
        ),
      );
    }

    final questions = lesson.discussionQuestions ?? const <String>[];
    final videoUrl = _blankToNull(lesson.videoUrl);
    final pdfUrl = _blankToNull(lesson.pdfUrl);

    return TurmaSheetBody(
      title: 'Aula ${lesson.lessonNumber} · ${lesson.title}',
      children: [
        if (date != null) ...[
          Text(DateFormat('dd/MM/yyyy').format(date), style: meta),
          const SizedBox(height: 12),
        ],
        if (videoUrl != null || pdfUrl != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (videoUrl != null)
                FilledButton.icon(
                  onPressed: () => _openLessonLink(context, videoUrl),
                  icon: const Icon(AppIcons.playArrow, size: 18),
                  label: const Text('Assistir vídeo'),
                ),
              if (pdfUrl != null)
                OutlinedButton.icon(
                  onPressed: () => _openLessonLink(context, pdfUrl),
                  icon: const Icon(AppIcons.pdf, size: 18),
                  label: const Text('Abrir PDF'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        section('Descrição', lesson.description),
        section('Referências bíblicas', lesson.bibleReferences),
        section('Conteúdo', lesson.content),
        if (questions.isNotEmpty)
          section(
            'Perguntas para discussão',
            [for (final q in questions) '• $q'].join('\n'),
          ),
        if ((lesson.description ?? '').trim().isEmpty &&
            (lesson.bibleReferences ?? '').trim().isEmpty &&
            (lesson.content ?? '').trim().isEmpty &&
            questions.isEmpty &&
            videoUrl == null &&
            pdfUrl == null)
          Text('Esta aula ainda não tem conteúdo.', style: meta),
      ],
    );
  }
}

/// Aula nova ou edição: título, data, textos da aula e os links do vídeo e
/// do PDF principais (colunas da própria aula — modelo híbrido do
/// ROADMAP-FORMACAO). Envio de arquivo ainda não: só link.
///
/// A edição grava o formulário inteiro por
/// [StudyGroupRepository.replaceLessonContent], então apagar um campo apaga
/// de verdade (antes o vídeo/PDF ficaria preso).
///
/// Aula nova nasce como rascunho, com o próximo número da turma e o
/// `study_group_id` da tela — não há como escolher outro grupo.
class _LessonFormSheet extends ConsumerStatefulWidget {
  final String studyGroupId;
  final int nextNumber;
  final StudyLesson? lesson;

  const _LessonFormSheet({
    required this.studyGroupId,
    required this.nextNumber,
    this.lesson,
  });

  @override
  ConsumerState<_LessonFormSheet> createState() => _LessonFormSheetState();
}

class _LessonFormSheetState extends ConsumerState<_LessonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _content;
  late final TextEditingController _bibleReferences;
  late final TextEditingController _questions;
  late final TextEditingController _videoUrl;
  late final TextEditingController _pdfUrl;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _title = TextEditingController(text: l?.title ?? '');
    _description = TextEditingController(text: l?.description ?? '');
    _content = TextEditingController(text: l?.content ?? '');
    _bibleReferences = TextEditingController(text: l?.bibleReferences ?? '');
    _questions = TextEditingController(
      text: (l?.discussionQuestions ?? const <String>[]).join('\n'),
    );
    _videoUrl = TextEditingController(text: l?.videoUrl ?? '');
    _pdfUrl = TextEditingController(text: l?.pdfUrl ?? '');
    _date = l?.scheduledDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _content.dispose();
    _bibleReferences.dispose();
    _questions.dispose();
    _videoUrl.dispose();
    _pdfUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Data da aula',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(studyGroupRepositoryProvider);
    try {
      final existing = widget.lesson;
      final title = _title.text.trim();
      final description = _blankToNull(_description.text);
      final bibleReferences = _blankToNull(_bibleReferences.text);
      final content = _blankToNull(_content.text);
      final questions = parseLessonQuestions(_questions.text);
      final videoUrl = normalizeLessonUrl(_videoUrl.text);
      final pdfUrl = normalizeLessonUrl(_pdfUrl.text);
      if (existing == null) {
        await repo.createLesson(
          studyGroupId: widget.studyGroupId,
          lessonNumber: widget.nextNumber,
          title: title,
          description: description,
          bibleReferences: bibleReferences,
          content: content,
          discussionQuestions: questions,
          scheduledDate: _date,
          videoUrl: videoUrl,
          pdfUrl: pdfUrl,
        );
      } else {
        await repo.replaceLessonContent(
          existing.id,
          title: title,
          description: description,
          bibleReferences: bibleReferences,
          content: content,
          discussionQuestions: questions,
          scheduledDate: _date,
          videoUrl: videoUrl,
          pdfUrl: pdfUrl,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return Form(
      key: _formKey,
      child: TurmaSheetBody(
        title: _isEdit
            ? 'Editar aula ${widget.lesson!.lessonNumber}'
            : 'Nova aula (Aula ${widget.nextNumber})',
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título da aula *'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Informe o título da aula'
                : null,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Data (opcional)'),
              child: Text(
                date == null ? '—' : DateFormat('dd/MM/yyyy').format(date),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bibleReferences,
            decoration: const InputDecoration(
              labelText: 'Referências bíblicas',
              hintText: 'Ex.: Atos 2:38; Romanos 6:3-4',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _content,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Conteúdo'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _questions,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Perguntas para discussão',
              helperText: 'Uma pergunta por linha.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Vídeo e PDF da aula',
            style: CommunityDesign.metaStyle(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _videoUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Link do vídeo',
              hintText: 'https://youtube.com/...',
              prefixIcon: Icon(AppIcons.videoLibrary),
            ),
            validator: lessonUrlError,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pdfUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Link do PDF',
              hintText: 'https://...',
              prefixIcon: Icon(AppIcons.pdf),
            ),
            validator: lessonUrlError,
          ),
          const SizedBox(height: 6),
          Text(
            'Quem tiver o link abre o vídeo e o PDF, mesmo com a aula em '
            'rascunho. Apague o link para tirar o vídeo ou o PDF da aula.',
            style: CommunityDesign.metaStyle(context),
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            Text(
              'A aula nasce como rascunho. Publique quando os alunos '
              'puderem ver.',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
