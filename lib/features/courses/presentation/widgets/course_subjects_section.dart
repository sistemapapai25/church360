import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/course_subject.dart';
import '../hub/course_hub.dart';
import '../providers/courses_provider.dart';
import '../turma/widgets/turma_sheet.dart';

/// Matérias do curso (PR 2a), na ordem de criação.
final courseSubjectsProvider =
    FutureProvider.family<List<CourseSubject>, String>((ref, courseId) {
      return ref.watch(coursesRepositoryProvider).getCourseSubjects(courseId);
    });

/// Quem edita as matérias. Espelha `course_subject_editable` só para
/// mostrar os botões; quem manda é a policy.
final courseSubjectsEditableProvider = FutureProvider.family<bool, String>((
  ref,
  courseId,
) async {
  if (await ref.watch(currentUserIsElevatedProvider.future)) return true;
  if (await ref.watch(
    currentUserHasPermissionProvider('courses.manage_lessons').future,
  )) {
    return true;
  }
  final course = await ref.watch(courseByIdProvider(courseId).future);
  final ministryId = course?.ministryId;
  if (ministryId == null) return false;
  if (await ref.watch(ministriesCanSeeAllProvider.future)) return true;
  return await ref.watch(
        currentUserHasPermissionProvider('baptism.edit').future,
      ) &&
      await ref.watch(ministryAccessProvider(ministryId).future);
});

/// Pessoa que pode ser escolhida como professor: `id` = `user_account.id`.
typedef TeacherOption = ({String id, String name});

/// Elegíveis a professor do curso.
///
/// Curso com ministério: integrantes com a função "Professor" (por
/// `member_function` ou pelas funções do vínculo, as duas fontes do
/// gerador de escala). Curso sem ministério: qualquer membro, por busca.
/// Nunca busca em outro ministério.
final teacherOptionsProvider =
    FutureProvider.family<List<TeacherOption>, String>((ref, courseId) async {
      final course = await ref.watch(courseByIdProvider(courseId).future);
      final ministryId = course?.ministryId;
      if (ministryId == null) {
        final directory = await ref.watch(memberDirectoryProvider.future);
        return [for (final m in directory) (id: m.id, name: m.displayName)]
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      final members = await ref.watch(
        ministryMembersProvider(ministryId).future,
      );
      final functions = await ref
          .watch(ministriesRepositoryProvider)
          .getMemberFunctionsByMinistry(ministryId);
      return [
        for (final m in members)
          if ([
            ...m.assignedFunctions,
            ...?functions[m.memberId],
          ].any(isTeacherFunction))
            (id: m.memberId, name: m.memberName),
      ]..sort((a, b) => a.name.compareTo(b.name));
    });

/// "Professor", "Professora", "Professores"...
bool isTeacherFunction(String name) =>
    name.trim().toLowerCase().startsWith('professor');

/// Nome de quem tem `user_account.id` = [id], pelo diretório do tenant.
String? memberNameById(WidgetRef ref, String? id) {
  if (id == null) return null;
  for (final m in ref.watch(memberDirectoryProvider).valueOrNull ?? const []) {
    if (m.id == id) return m.displayName;
  }
  return null;
}

/// Seção "Matérias" da tela do curso: só a gestão vê; quem edita o
/// conteúdo do curso cria, edita e apaga.
class CourseSubjectsSection extends ConsumerWidget {
  final String courseId;

  const CourseSubjectsSection({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(courseHubProvider(courseId)).valueOrNull;
    if (hub == null || !hub.management) return const SizedBox.shrink();
    final canEdit =
        ref.watch(courseSubjectsEditableProvider(courseId)).valueOrNull ??
        false;
    final subjectsAsync = ref.watch(courseSubjectsProvider(courseId));
    final meta = CommunityDesign.metaStyle(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Matérias',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (canEdit) ...[
                const Spacer(),
                TextButton.icon(
                  key: const ValueKey('materia-nova'),
                  onPressed: () => _openForm(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova matéria'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          subjectsAsync.when(
            data: (subjects) => subjects.isEmpty
                ? Text('Nenhuma matéria neste curso ainda.', style: meta)
                : Column(
                    children: [
                      for (final s in subjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: canEdit
                                ? () => _openForm(context, ref, subject: s)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: CommunityDesign.titleStyle(context)
                                      .copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    s.lessonCount == 1
                                        ? '1 aula'
                                        : '${s.lessonCount} aulas',
                                    ?memberNameById(ref, s.defaultTeacherId),
                                  ].join(' · '),
                                  style: meta,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Text('Não foi possível carregar as matérias.', style: meta),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    CourseSubject? subject,
  }) async {
    final saved = await showTurmaSheet<bool>(
      context: context,
      builder: (_) => _SubjectFormSheet(courseId: courseId, subject: subject),
    );
    if (saved == true) ref.invalidate(courseSubjectsProvider(courseId));
  }
}

class _SubjectFormSheet extends ConsumerStatefulWidget {
  final String courseId;
  final CourseSubject? subject;

  const _SubjectFormSheet({required this.courseId, this.subject});

  @override
  ConsumerState<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends ConsumerState<_SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.subject?.title);
  late final _count = TextEditingController(
    text: '${widget.subject?.lessonCount ?? 1}',
  );
  late String? _teacherId = widget.subject?.defaultTeacherId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar matéria?'),
        content: const Text(
          'As aulas desta matéria continuam na turma, só ficam sem matéria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(coursesRepositoryProvider)
          .deleteCourseSubject(widget.subject!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return Form(
      key: _formKey,
      child: TurmaSheetBody(
        title: subject == null ? 'Nova matéria' : 'Editar matéria',
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título *'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Informe o título da matéria'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _count,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nº de aulas *'),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              return n == null || n < 1 || n > 200 ? 'De 1 a 200' : null;
            },
          ),
          const SizedBox(height: 12),
          TeacherField(
            courseId: widget.courseId,
            label: 'Professor padrão',
            value: _teacherId,
            onChanged: (id) => setState(() => _teacherId = id),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (subject != null)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('Apagar'),
                ),
              const Spacer(),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        _run(
                          () => ref
                              .read(coursesRepositoryProvider)
                              .saveCourseSubject(
                                id: subject?.id,
                                courseId: widget.courseId,
                                title: _title.text.trim(),
                                lessonCount: int.parse(_count.text.trim()),
                                defaultTeacherId: _teacherId,
                              ),
                        );
                      },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Campo de professor: mostra o escolhido e abre uma busca entre os
/// elegíveis do curso ([teacherOptionsProvider]). O escolhido continua
/// aparecendo mesmo que tenha perdido a função (aula antiga não muda).
class TeacherField extends ConsumerWidget {
  final String courseId;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const TeacherField({
    super.key,
    required this.courseId,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = memberNameById(ref, value);
    return InkWell(
      key: const ValueKey('teacher-field'),
      onTap: () async {
        final picked = await showDialog<TeacherOption>(
          context: context,
          builder: (_) => _TeacherPickerDialog(courseId: courseId),
        );
        if (picked != null) onChanged(picked.id);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: 'Tirar professor',
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value == null ? '—' : name ?? '…'),
      ),
    );
  }
}

class _TeacherPickerDialog extends ConsumerStatefulWidget {
  final String courseId;

  const _TeacherPickerDialog({required this.courseId});

  @override
  ConsumerState<_TeacherPickerDialog> createState() =>
      _TeacherPickerDialogState();
}

class _TeacherPickerDialogState extends ConsumerState<_TeacherPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(teacherOptionsProvider(widget.courseId));
    final hasMinistry =
        ref
            .watch(courseByIdProvider(widget.courseId))
            .valueOrNull
            ?.ministryId !=
        null;
    final meta = CommunityDesign.metaStyle(context);
    final q = _query.trim().toLowerCase();

    return AlertDialog(
      title: const Text('Escolher professor'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar pelo nome',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: optionsAsync.when(
                data: (options) {
                  final shown = [
                    for (final o in options)
                      if (q.isEmpty || o.name.toLowerCase().contains(q)) o,
                  ];
                  if (shown.isEmpty) {
                    return Center(
                      child: Text(
                        options.isEmpty && hasMinistry
                            ? 'Nenhum integrante do ministério tem a função '
                                  'Professor.'
                            : 'Ninguém encontrado.',
                        style: meta,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      for (final o in shown)
                        ListTile(
                          title: Text(o.name),
                          onTap: () => Navigator.of(context).pop(o),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(
                    'Não foi possível carregar os professores.',
                    style: meta,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
