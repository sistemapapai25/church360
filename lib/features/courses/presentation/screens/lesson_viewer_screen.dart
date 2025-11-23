import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../domain/models/course_lesson.dart';
import '../providers/courses_provider.dart';

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
  YoutubePlayerController? _youtubeController;

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));

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

        // Inicializar YouTube player se necessário
        if (lesson.videoUrl != null && _isYouTubeUrl(lesson.videoUrl!)) {
          final videoId = YoutubePlayer.convertUrlToId(lesson.videoUrl!);
          if (videoId != null && _youtubeController == null) {
            _youtubeController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
              ),
            );
          }
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, lesson, lessonNumber, lessons.length),

              // Conteúdo
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player de vídeo
                    if (lesson.videoUrl != null) _buildVideoPlayer(lesson),

                    // Informações da aula
                    _buildLessonInfo(lesson, lessonNumber),

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

  /// Player de vídeo
  Widget _buildVideoPlayer(CourseLesson lesson) {
    if (_isYouTubeUrl(lesson.videoUrl!)) {
      // YouTube Player
      if (_youtubeController != null) {
        return YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blue,
          progressColors: const ProgressBarColors(
            playedColor: Colors.blue,
            handleColor: Colors.blueAccent,
          ),
        );
      }
    } else {
      // Vídeo hospedado (placeholder - você pode usar video_player package)
      return Container(
        height: 200,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _launchUrl(lesson.videoUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir Vídeo'),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Descrição
          if (lesson.description != null && lesson.description!.isNotEmpty) ...[
            Text(
              lesson.description!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
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
                  style: const TextStyle(fontSize: 14),
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
          const Text(
            'Conteúdo da Aula',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: const TextStyle(
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
          Card(
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
                icon: const Icon(Icons.arrow_forward),
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

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
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
