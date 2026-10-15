import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/course_lesson.dart';
import '../../domain/models/course_progress.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_study_panel.dart';
import '../widgets/course_subjects_section.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/media/inline_video.dart';

/// Tela de visualização de aula individual
class LessonViewerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;

  const LessonViewerScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  @override
  ConsumerState<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends ConsumerState<LessonViewerScreen> {
  bool _saving = false;

  /// E3: o que está trancado, com o progresso dado (o `_complete` passa o
  /// progresso já com a aula atual concluída para saber se a próxima abre).
  CourseLocks _locks(
    List<CourseModule> modules,
    Map<String, LessonProgress> lessonProgress,
  ) {
    final course = ref.read(courseByIdProvider(widget.courseId)).valueOrNull;
    return CourseStudyPanel.locksOf(
      sequential: course?.sequential ?? false,
      modules: modules,
      quizzes:
          ref.read(courseQuizzesProvider(widget.courseId)).valueOrNull ??
          const [],
      lessonProgress: lessonProgress,
      attempts:
          ref.read(myQuizAttemptsProvider(widget.courseId)).valueOrNull ??
          const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));
    // E1: concluída ou não. Falha aqui não derruba a aula: vira "não".
    final lessonProgress =
        ref.watch(lessonProgressMapProvider(widget.courseId)).valueOrNull ??
        const <String, LessonProgress>{};
    final completed = lessonProgress[widget.lessonId]?.completed ?? false;
    // E3: o cadeado depende do curso, das matérias, das provas e das
    // tentativas; observar aqui para a tela reagir quando chegarem.
    final sequential =
        ref.watch(courseByIdProvider(widget.courseId)).valueOrNull?.sequential ??
        false;
    final subjects =
        ref.watch(courseSubjectsProvider(widget.courseId)).valueOrNull ??
        const [];
    ref.watch(courseQuizzesProvider(widget.courseId));
    ref.watch(myQuizAttemptsProvider(widget.courseId));

    return lessonsAsync.when(
      data: (allLessons) {
        // Ordem da tela do curso: por módulo, depois order_index.
        final modules = CourseStudyPanel.modulesOf(allLessons, subjects);
        final lessons = [for (final m in modules) ...m.lessons];
        final lessonIndex = lessons.indexWhere((l) => l.id == widget.lessonId);
        if (lessonIndex == -1) {
          return Scaffold(
            appBar: AppBar(title: const Text('Aula não encontrada')),
            body: const Center(child: Text('Aula não encontrada')),
          );
        }

        final lesson = lessons[lessonIndex];
        final lessonNumber = lessonIndex + 1;

        if (sequential &&
            _locks(modules, lessonProgress).lessons.contains(lesson.id)) {
          return Scaffold(
            appBar: AppBar(title: Text(lesson.title)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Aula bloqueada',
                      key: const ValueKey('lesson-locked'),
                      style: CommunityDesign.titleStyle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Neste curso as aulas abrem em sequência. Conclua a aula anterior (e a prova do módulo, se houver) para continuar.',
                      textAlign: TextAlign.center,
                      style: CommunityDesign.contentStyle(context),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/courses/${widget.courseId}/view'),
                      child: const Text('Voltar ao curso'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
          body: CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, lesson, lessonNumber, lessons.length),

              // Conteúdo
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player de vídeo: o mesmo da aula da turma e do culto
                    // (YouTube no navegador e no app, mp4 do Storage).
                    if (lesson.hasVideo)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: InlineVideo(url: lesson.videoUrl!),
                      ),

                    // Informações da aula
                    _buildLessonInfo(lesson, lessonNumber),

                    // E1: "Concluir e avançar"
                    _buildCompleteButton(
                      lessons,
                      lessonIndex,
                      completed,
                      modules,
                      lessonProgress,
                    ),

                    const Divider(height: 32),

                    // Conteúdo/Transcrição
                    if (lesson.content != null && lesson.content!.isNotEmpty)
                      _buildContent(lesson.content!),

                    // Botões de ação (arquivo anexo)
                    if (lesson.fileUrl != null) _buildActionButtons(context, lesson),

                    const SizedBox(height: 32),

                    // Navegação entre aulas
                    _buildLessonNavigation(context, lessons, lessonIndex),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar aula: $error'),
            ],
          ),
        ),
      ),
    );
  }

  /// App Bar com imagem de capa
  Widget _buildAppBar(
    BuildContext context,
    CourseLesson lesson,
    int lessonNumber,
    int totalLessons,
  ) {
    return SliverAppBar(
      backgroundColor: CommunityDesign.headerColor(context),
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Aula $lessonNumber de $totalLessons',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Capa da aula (se tiver)
            if (lesson.coverImageUrl != null)
              Image.network(
                lesson.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultCover();
                },
              )
            else
              _buildDefaultCover(),

            // Gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Capa padrão
  Widget _buildDefaultCover() {
    return Container(
      color: Colors.blue.shade700,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// E1: marca a aula como concluída e vai para a próxima (ou volta ao
  /// curso na última). Já concluída: só navega.
  Widget _buildCompleteButton(
    List<CourseLesson> lessons,
    int index,
    bool completed,
    List<CourseModule> modules,
    Map<String, LessonProgress> lessonProgress,
  ) {
    final hasNext = index < lessons.length - 1;
    // E3: a próxima aula pode estar atrás da prova do módulo.
    final nextLocked =
        hasNext &&
        _locks(modules, {
          ...lessonProgress,
          lessons[index].id: LessonProgress(
            lessonId: lessons[index].id,
            completedAt: DateTime.now(),
          ),
        }).lessons.contains(lessons[index + 1].id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (completed) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Aula concluída',
                  style: CommunityDesign.contentStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('lesson-complete'),
              onPressed: _saving
                  ? null
                  : () => _complete(lessons, index, completed, nextLocked),
              icon: Icon(
                completed ? Icons.arrow_forward_rounded : Icons.check_rounded,
              ),
              label: Text(
                completed
                    ? (hasNext && !nextLocked
                          ? 'Próxima aula'
                          : nextLocked
                          ? 'Ir para a prova do módulo'
                          : 'Voltar ao curso')
                    : (hasNext && !nextLocked
                          ? 'Concluir e avançar'
                          : nextLocked
                          ? 'Concluir e fazer a prova'
                          : 'Concluir aula'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _complete(
    List<CourseLesson> lessons,
    int index,
    bool already,
    bool nextLocked,
  ) async {
    // Próxima trancada atrás da prova: volta ao curso, onde a prova está.
    final hasNext = index < lessons.length - 1 && !nextLocked;
    if (!already) {
      setState(() => _saving = true);
      try {
        await ref
            .read(lessonProgressActionsProvider)
            .completeLesson(widget.courseId, widget.lessonId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível marcar a aula: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (!mounted) return;
    if (hasNext) {
      context.pushReplacement(
        '/courses/${widget.courseId}/lessons/${lessons[index + 1].id}/view',
      );
      return;
    }
    if (!already) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextLocked
                ? 'Aula concluída. Agora faça a prova do módulo.'
                : 'Última aula concluída. Parabéns!',
          ),
        ),
      );
    }
    if (context.canPop()) context.pop();
  }

  /// Informações da aula
  Widget _buildLessonInfo(CourseLesson lesson, int lessonNumber) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            lesson.title,
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Descrição
          if (lesson.description != null && lesson.description!.isNotEmpty) ...[
            Text(
              lesson.description!,
              style: CommunityDesign.contentStyle(context).copyWith(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Duração do vídeo
          if (lesson.videoDuration != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Duração: ${lesson.durationText}',
                  style: CommunityDesign.contentStyle(context).copyWith(fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Conteúdo/Transcrição
  Widget _buildContent(String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conteúdo da Aula',
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
            child: Text(
              content,
              style: CommunityDesign.contentStyle(context).copyWith(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botões de ação (arquivo anexo)
  Widget _buildActionButtons(BuildContext context, CourseLesson lesson) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Material de Apoio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
            child: ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.green),
              title: Text(lesson.fileName ?? 'Arquivo Anexo'),
              subtitle: const Text('Clique para baixar'),
              trailing: const Icon(Icons.download),
              onTap: () => _launchUrl(lesson.fileUrl!),
            ),
          ),
        ],
      ),
    );
  }

  /// Navegação entre aulas
  Widget _buildLessonNavigation(
    BuildContext context,
    List<CourseLesson> lessons,
    int currentIndex,
  ) {
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < lessons.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Aula anterior
          if (hasPrevious)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final previousLesson = lessons[currentIndex - 1];
                  context.push(
                    '/courses/${widget.courseId}/lessons/${previousLesson.id}/view',
                  );
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Aula Anterior'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 16),

          // Próxima aula
          if (hasNext)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final nextLesson = lessons[currentIndex + 1];
                  context.push(
                    '/courses/${widget.courseId}/lessons/${nextLesson.id}/view',
                  );
                },
                icon: const Icon(Icons.arrow_forward_ios),
                label: const Text('Próxima Aula'),
                iconAlignment: IconAlignment.end,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
