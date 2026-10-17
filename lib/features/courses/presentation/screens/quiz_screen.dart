import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/readable_width.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/course_quiz.dart';
import '../providers/courses_provider.dart';

/// Prova do módulo para o aluno (E4): uma questão por vez, depois o
/// resultado com o gabarito e as explicações, e "Refazer".
class QuizScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String quizId;

  const QuizScreen({super.key, required this.courseId, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  QuizResult? _result;
  bool _sending = false;

  Future<void> _submit(Map<String, int> answers) async {
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(quizActionsProvider)
          .submit(widget.courseId, widget.quizId, answers);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar a prova: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = ref.watch(courseQuizzesProvider(widget.courseId));
    final questions = ref.watch(quizQuestionsProvider(widget.quizId));
    final quiz = quizzes.valueOrNull
        ?.where((q) => q.id == widget.quizId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(quiz?.title ?? 'Prova'),
      ),
      body: ReadableWidth(child: questions.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Esta prova ainda não tem questões.'));
          }
          final result = _result;
          if (result != null) {
            return QuizResultView(
              questions: items,
              result: result,
              onRetry: () => setState(() => _result = null),
              onBack: () => context.pop(),
            );
          }
          return QuizTaker(
            questions: items,
            passScore: quiz?.passScore ?? 70,
            sending: _sending,
            onSubmit: _submit,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar a prova: $error')),
      )),
    );
  }
}

/// Responde uma questão por vez. Widget puro: devolve `{question_id: índice}`
/// em [onSubmit].
class QuizTaker extends StatefulWidget {
  final List<QuizQuestion> questions;
  final int passScore;
  final bool sending;
  final void Function(Map<String, int> answers) onSubmit;

  const QuizTaker({
    super.key,
    required this.questions,
    required this.passScore,
    this.sending = false,
    required this.onSubmit,
  });

  @override
  State<QuizTaker> createState() => _QuizTakerState();
}

class _QuizTakerState extends State<QuizTaker> {
  int _index = 0;
  final _answers = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    final total = widget.questions.length;
    final chosen = _answers[q.id];
    final last = _index == total - 1;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Questão ${_index + 1} de $total',
                style: CommunityDesign.metaStyle(context),
              ),
            ),
            Text(
              'Nota mínima ${widget.passScore}%',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / total,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Text(
            q.text,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        RadioGroup<int>(
          groupValue: chosen,
          onChanged: (v) => setState(() => _answers[q.id] = v!),
          child: Column(
            children: [
              for (final (i, option) in q.options.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: CommunityDesign.overlayDecoration(scheme),
                    child: RadioListTile<int>(
                      key: ValueKey('option-$i'),
                      value: i,
                      title: Text(option),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_index > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _index--),
                  child: const Text('Anterior'),
                ),
              ),
            if (_index > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const ValueKey('quiz-next'),
                onPressed: chosen == null || widget.sending
                    ? null
                    : last
                    ? () => widget.onSubmit(Map.of(_answers))
                    : () => setState(() => _index++),
                child: Text(last ? 'Enviar respostas' : 'Próxima'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Resultado da prova: nota, aprovação e cada questão com a sua resposta, o
/// gabarito e a explicação.
class QuizResultView extends StatelessWidget {
  final List<QuizQuestion> questions;
  final QuizResult result;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const QuizResultView({
    super.key,
    required this.questions,
    required this.result,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final q in questions) q.id: q};
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              Icon(
                result.passed ? Icons.verified_rounded : Icons.replay_rounded,
                size: 48,
                color: result.passed ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 8),
              Text(
                '${result.score}%',
                key: const ValueKey('quiz-score'),
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 36, fontWeight: FontWeight.w800),
              ),
              Text(
                result.passed
                    ? 'Aprovado! ${result.correct} de ${result.total} certas.'
                    : 'Não foi dessa vez: ${result.correct} de ${result.total} certas (mínimo ${result.passScore}%).',
                textAlign: TextAlign.center,
                style: CommunityDesign.contentStyle(context),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Refazer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onBack,
                      child: const Text('Voltar ao curso'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final (i, c) in result.questions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: CommunityDesign.overlayDecoration(scheme),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        c.isRight ? Icons.check_circle : Icons.cancel,
                        color: c.isRight ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${i + 1}. ${byId[c.questionId]?.text ?? ''}',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (c.chosen != null && !c.isRight)
                    Text(
                      'Sua resposta: ${_option(byId[c.questionId], c.chosen!)}',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  Text(
                    'Resposta certa: ${_option(byId[c.questionId], c.correctIndex)}',
                    style: CommunityDesign.contentStyle(context),
                  ),
                  if (c.explanation != null && c.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.explanation!,
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _option(QuizQuestion? q, int index) {
    if (q == null || index < 0 || index >= q.options.length) return '-';
    return q.options[index];
  }
}
