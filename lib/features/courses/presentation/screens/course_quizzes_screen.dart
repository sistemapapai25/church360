import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/readable_width.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../domain/models/course_quiz.dart';
import '../../domain/models/course_subject.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_subjects_section.dart';

/// Provas do curso gravado, para a gestão (E4, `courses.manage_lessons`):
/// uma por módulo e uma final.
class CourseQuizzesScreen extends ConsumerWidget {
  final String courseId;

  const CourseQuizzesScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzes = ref.watch(courseQuizzesProvider(courseId));
    final subjects =
        ref.watch(courseSubjectsProvider(courseId)).valueOrNull ?? const [];
    final byId = {for (final s in subjects) s.id: s};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provas', style: CommunityDesign.titleStyle(context)),
            Text(
              'Uma por módulo e uma prova final',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
      body: ReadableWidth(child: quizzes.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma prova cadastrada',
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque em + para criar a prova de um módulo ou a prova final. O aluno só avança no curso sequencial depois de aprovado.',
                      textAlign: TextAlign.center,
                      style: CommunityDesign.contentStyle(context),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final q in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: CommunityDesign.overlayDecoration(
                    Theme.of(context).colorScheme,
                  ),
                  child: ListTile(
                    leading: Icon(
                      q.isFinal ? Icons.workspace_premium : Icons.quiz_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(q.title),
                    subtitle: Text(
                      '${q.isFinal ? 'Prova final' : (byId[q.subjectId]?.title ?? 'Módulo')} · nota mínima ${q.passScore}%',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Excluir prova',
                      onPressed: () => _delete(context, ref, q),
                    ),
                    onTap: () =>
                        context.push('/courses/$courseId/quizzes/${q.id}/edit'),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar provas: $error')),
      )),
      floatingActionButton: PearlFab(
        onPressed: () => context.push('/courses/$courseId/quizzes/new/edit'),
        icon: Icons.add,
        label: 'Nova Prova',
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CourseQuiz quiz,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir prova'),
        content: Text(
          'Excluir "${quiz.title}"? As tentativas dos alunos também somem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(quizActionsProvider).delete(courseId, quiz.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }
}

/// Editor da prova: título, módulo, nota mínima e as questões (2 a 6
/// opções, uma certa, explicação opcional). Grava tudo de uma vez por
/// `quiz_save`.
class CourseQuizFormScreen extends ConsumerStatefulWidget {
  final String courseId;

  /// Nulo = prova nova.
  final String? quizId;

  const CourseQuizFormScreen({super.key, required this.courseId, this.quizId});

  @override
  ConsumerState<CourseQuizFormScreen> createState() =>
      _CourseQuizFormScreenState();
}

class _QuestionDraft {
  final text = TextEditingController();
  final explanation = TextEditingController();
  final options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  int correct = 0;

  _QuestionDraft();

  _QuestionDraft.from(QuizQuestion q) {
    text.text = q.text;
    explanation.text = q.explanation ?? '';
    options
      ..clear()
      ..addAll([for (final o in q.options) TextEditingController(text: o)]);
    correct = q.correctIndex ?? 0;
  }

  void dispose() {
    text.dispose();
    explanation.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class _CourseQuizFormScreenState extends ConsumerState<CourseQuizFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _passScore = TextEditingController(text: '70');
  String? _subjectId;
  final _questions = <_QuestionDraft>[];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.quizId == null) {
      _questions.add(_QuestionDraft());
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final quizzes = await ref.read(
        courseQuizzesProvider(widget.courseId).future,
      );
      final quiz = quizzes.where((q) => q.id == widget.quizId).firstOrNull;
      final questions = await ref.read(
        quizAdminQuestionsProvider(widget.quizId!).future,
      );
      if (!mounted) return;
      setState(() {
        _title.text = quiz?.title ?? '';
        _passScore.text = '${quiz?.passScore ?? 70}';
        _subjectId = quiz?.subjectId;
        _questions.addAll([for (final q in questions) _QuestionDraft.from(q)]);
        if (_questions.isEmpty) _questions.add(_QuestionDraft());
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar a prova: $e')));
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _passScore.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(quizActionsProvider)
          .save(
            quizId: widget.quizId,
            courseId: widget.courseId,
            subjectId: _subjectId,
            title: _title.text.trim(),
            passScore: int.parse(_passScore.text.trim()),
            questions: [
              for (final (i, q) in _questions.indexed)
                QuizQuestion(
                  id: '',
                  orderIndex: i,
                  text: q.text.text.trim(),
                  options: [for (final o in q.options) o.text.trim()],
                  correctIndex: q.correct,
                  explanation: q.explanation.text.trim().isEmpty
                      ? null
                      : q.explanation.text.trim(),
                ),
            ],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prova salva!')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('course_quiz_subject_uniq') ||
              e.toString().contains('course_quiz_final_uniq')
          ? 'Já existe uma prova para esse módulo. Edite a existente.'
          : 'Erro ao salvar: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects =
        ref.watch(courseSubjectsProvider(widget.courseId)).valueOrNull ??
        const <CourseSubject>[];
    final subjectIds = {for (final s in subjects) s.id};

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizId == null ? 'Nova Prova' : 'Editar Prova'),
        actions: [
          TextButton(
            onPressed: _saving || !_loaded ? null : _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: ReadableWidth(child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Título *',
                      hintText: 'Ex.: Prova do Módulo 1',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe o título' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: subjectIds.contains(_subjectId)
                        ? _subjectId
                        : null,
                    decoration: const InputDecoration(labelText: 'Módulo'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Prova final (curso inteiro)'),
                      ),
                      for (final s in subjects)
                        DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.title),
                        ),
                    ],
                    onChanged: (v) => setState(() => _subjectId = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passScore,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nota mínima (%) *',
                      helperText: 'Padrão 70. O aluno pode refazer até passar.',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0 || n > 100) return 'De 0 a 100';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  for (final (i, q) in _questions.indexed)
                    _QuestionEditor(
                      key: ObjectKey(q),
                      index: i,
                      draft: q,
                      canRemove: _questions.length > 1,
                      onRemove: () => setState(() {
                        _questions.removeAt(i).dispose();
                      }),
                      onChanged: () => setState(() {}),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _questions.add(_QuestionDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar questão'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            )),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  final int index;
  final _QuestionDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _QuestionEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Questão ${index + 1}',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remover questão',
                  onPressed: onRemove,
                ),
            ],
          ),
          TextFormField(
            controller: draft.text,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Enunciado *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Informe o enunciado' : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Opções (marque a certa)',
            style: CommunityDesign.metaStyle(context),
          ),
          RadioGroup<int>(
            groupValue: draft.correct,
            onChanged: (v) {
              draft.correct = v!;
              onChanged();
            },
            child: Column(
              children: [
                for (final (i, o) in draft.options.indexed)
                  Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextFormField(
                          controller: o,
                          decoration: InputDecoration(
                            labelText: 'Opção ${i + 1} *',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Preencha'
                              : null,
                        ),
                      ),
                      if (draft.options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            draft.options.removeAt(i).dispose();
                            if (draft.correct >= draft.options.length) {
                              draft.correct = 0;
                            }
                            onChanged();
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (draft.options.length < 6)
            TextButton.icon(
              onPressed: () {
                draft.options.add(TextEditingController());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Mais uma opção'),
            ),
          TextFormField(
            controller: draft.explanation,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Explicação (opcional)',
              helperText: 'Aparece para o aluno depois de responder',
            ),
          ),
        ],
      ),
    );
  }
}
