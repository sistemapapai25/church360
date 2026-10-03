import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../members/presentation/providers/members_provider.dart';
import '../../../../study_groups/domain/models/study_group.dart';
import '../../../../study_groups/presentation/providers/study_group_provider.dart';
import '../turma_access.dart';
import '../widgets/turma_sheet.dart';

/// Observações de uma aula numa visibilidade (o que a RLS deixa ler).
final lessonNotesProvider =
    FutureProvider.family<
      List<StudyLessonNote>,
      ({String lessonId, LessonNoteVisibility visibility})
    >((ref, key) {
      return ref
          .watch(studyGroupRepositoryProvider)
          .getLessonNotes(key.lessonId, key.visibility);
    });

/// Aba Observações da tela da aula (`study_lesson_note`).
///
/// - Liderança: observações da aula, lidas pelos demais líderes, nunca
///   pelo aluno. Escreve quem edita a aula (na vitrine de Cursos, só lê).
/// - Aluno: anotações pessoais, só ele lê. Escreve em qualquer porta — não
///   é gravação na turma.
///
/// Sem edição: corrigir = apagar e escrever de novo. Só o autor apaga.
class AulaObservacoesTab extends ConsumerStatefulWidget {
  final String lessonId;
  final TurmaAccess access;

  const AulaObservacoesTab({
    super.key,
    required this.lessonId,
    required this.access,
  });

  @override
  ConsumerState<AulaObservacoesTab> createState() => _AulaObservacoesTabState();
}

class _AulaObservacoesTabState extends ConsumerState<AulaObservacoesTab> {
  final _body = TextEditingController();
  bool _saving = false;

  LessonNoteVisibility get _visibility => widget.access.isLeadership
      ? LessonNoteVisibility.lideranca
      : LessonNoteVisibility.pessoal;

  bool get _canWrite =>
      !widget.access.isLeadership || widget.access.canWriteLessons;

  ({String lessonId, LessonNoteVisibility visibility}) get _key =>
      (lessonId: widget.lessonId, visibility: _visibility);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(lessonNotesProvider(_key));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    await _run(
      () => ref
          .read(studyGroupRepositoryProvider)
          .addLessonNote(
            lessonId: widget.lessonId,
            visibility: _visibility,
            body: body,
          ),
    );
    if (mounted) _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final leadership = widget.access.isLeadership;
    final notesAsync = ref.watch(lessonNotesProvider(_key));
    // author_id é user_account.id, a mesma chave do diretório e da ficha.
    // Só a liderança precisa: na pessoal, tudo o que volta é do aluno.
    final myId = leadership
        ? ref.watch(currentMemberProvider).valueOrNull?.id
        : null;
    final names = leadership
        ? {
            for (final m
                in ref.watch(memberDirectoryProvider).valueOrNull ?? const [])
              m.id: m.displayName,
          }
        : const <String, String>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Text(
          leadership
              ? 'Visível só para a liderança da turma. O aluno não vê.'
              : 'Suas anotações desta aula. Só você vê.',
          style: meta,
        ),
        if (_canWrite) ...[
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('aula-nota-campo'),
            controller: _body,
            minLines: 2,
            maxLines: 6,
            maxLength: 5000,
            decoration: InputDecoration(
              labelText: leadership ? 'Nova observação' : 'Nova anotação',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _add,
              child: const Text('Salvar'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        notesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => TurmaMessage.error(
            message: 'Não foi possível carregar as observações.',
            onRetry: () => ref.invalidate(lessonNotesProvider(_key)),
          ),
          data: (notes) {
            if (notes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  leadership
                      ? 'Nenhuma observação nesta aula.'
                      : 'Nenhuma anotação ainda.',
                  style: meta,
                ),
              );
            }
            return Column(
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      key: ValueKey('aula-nota-${note.id}'),
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.body),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (leadership)
                                      names[note.authorId] ?? 'Líder',
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(note.createdAt.toLocal()),
                                  ].join(' · '),
                                  style: meta,
                                ),
                              ],
                            ),
                          ),
                          if (_canWrite &&
                              (!leadership || note.authorId == myId))
                            IconButton(
                              tooltip: 'Apagar',
                              icon: const Icon(AppIcons.close, size: 18),
                              onPressed: _saving
                                  ? null
                                  : () => _run(
                                      () => ref
                                          .read(studyGroupRepositoryProvider)
                                          .deleteLessonNote(note.id),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
