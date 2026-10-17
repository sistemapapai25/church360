import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/course_lesson.dart';
import '../providers/courses_provider.dart';

/// Minhas anotações de uma aula gravada (só as do próprio aluno).
final courseLessonNotesProvider =
    FutureProvider.family<List<CourseLessonNote>, String>(
      (ref, lessonId) =>
          ref.watch(coursesRepositoryProvider).getLessonNotes(lessonId),
    );

/// P4: anotações do aluno na aula do curso gravado (`course_lesson_note`).
/// Molde da aba Observações da aula da turma, só a parte pessoal: só o
/// autor lê. Sem edição: corrigir = apagar e escrever de novo.
class CourseLessonNotesSection extends ConsumerStatefulWidget {
  final String lessonId;

  const CourseLessonNotesSection({super.key, required this.lessonId});

  @override
  ConsumerState<CourseLessonNotesSection> createState() =>
      _CourseLessonNotesSectionState();
}

class _CourseLessonNotesSectionState
    extends ConsumerState<CourseLessonNotesSection> {
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(courseLessonNotesProvider(widget.lessonId));
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    final ok = await _run(
      () => ref
          .read(coursesRepositoryProvider)
          .addLessonNote(widget.lessonId, body),
    );
    if (ok && mounted) _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final notesAsync = ref.watch(courseLessonNotesProvider(widget.lessonId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Minhas anotações', style: CommunityDesign.titleStyle(context)),
          const SizedBox(height: 4),
          Text('Só você vê.', style: meta),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('curso-nota-campo'),
            controller: _body,
            minLines: 2,
            maxLines: 6,
            maxLength: 5000,
            decoration: const InputDecoration(labelText: 'Nova anotação'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('curso-nota-salvar'),
              onPressed: _saving ? null : _add,
              child: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 12),
          notesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => TextButton(
              onPressed: () =>
                  ref.invalidate(courseLessonNotesProvider(widget.lessonId)),
              child: const Text(
                'Não foi possível carregar as anotações. Tentar de novo',
              ),
            ),
            data: (notes) => notes.isEmpty
                ? Text('Nenhuma anotação ainda.', style: meta)
                : Column(
                    children: [
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            key: ValueKey('curso-nota-${note.id}'),
                            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(note.body),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(note.createdAt.toLocal()),
                                        style: meta,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Apagar',
                                  icon: const Icon(AppIcons.close, size: 18),
                                  onPressed: _saving
                                      ? null
                                      : () => _run(
                                          () => ref
                                              .read(coursesRepositoryProvider)
                                              .deleteLessonNote(note.id),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
