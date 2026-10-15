import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/course_lesson.dart';
import '../providers/courses_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));
    // E1: concluída ou não. Falha aqui não derruba a aula: vira "não".
    final completed =
        ref
            .watch(lessonProgressMapProvider(widget.courseId))
            .valueOrNull?[widget.lessonId]
            ?.completed ??
        false;

    return lessonsAsync.when(
      data: (lessons) {
        final lessonIndex = lessons.indexWhere((l) => l.id == widget.lessonId);
        if (lessonIndex == -1) {
          return Scaffold(
            appBar: AppBar(title: const Text('Aula não encontrada')),
            body: const Center(child: Text('Aula não encontrada')),
          );
        }

        final lesson = lessons[lessonIndex];
        final lessonNumber = lessonIndex + 1;

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
                    _buildCompleteButton(lessons, lessonIndex, completed),

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
  ) {
    final hasNext = index < lessons.length - 1;
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
                  : () => _complete(lessons, index, completed),
              icon: Icon(
                completed ? Icons.arrow_forward_rounded : Icons.check_rounded,
              ),
              label: Text(
                completed
                    ? (hasNext ? 'Próxima aula' : 'Voltar ao curso')
                    : (hasNext ? 'Concluir e avançar' : 'Concluir aula'),
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
  ) async {
    final hasNext = index < lessons.length - 1;
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
        const SnackBar(content: Text('Última aula concluída. Parabéns!')),
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
