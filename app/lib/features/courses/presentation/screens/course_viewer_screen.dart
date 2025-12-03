import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/course.dart';
import '../../domain/models/course_lesson.dart';
import '../providers/courses_provider.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';

/// Tela de visualização de curso (para alunos)
class CourseViewerScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseViewerScreen({
    super.key,
    required this.courseId,
  });

  @override
  ConsumerState<CourseViewerScreen> createState() => _CourseViewerScreenState();
}

class _CourseViewerScreenState extends ConsumerState<CourseViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseByIdProvider(widget.courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));

    return Scaffold(
      body: courseAsync.when(
        data: (course) {
          if (course == null) {
            return const Center(child: Text('Curso não encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, course),

              // Conteúdo
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações do curso
                    _buildCourseInfo(course),

                    const Divider(height: 32),

                    // Lista de Aulas (apenas para cursos online gravados)
                    if (course.courseType == CourseType.onlineRecorded)
                      lessonsAsync.when(
                        data: (lessons) {
                          if (lessons.isEmpty) {
                            return _buildNoLessonsContent();
                          }
                          return _buildLessonsList(lessons);
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (error, stack) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('Erro ao carregar aulas: $error'),
                          ),
                        ),
                      )
                    else
                      _buildCourseTypeInfo(course),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar curso: $error'),
            ],
          ),
        ),
      ),
    );
  }

  /// App Bar com imagem de capa
  Widget _buildAppBar(BuildContext context, Course course) {
    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: [
        // Botão de editar curso (apenas coordenadores)
        isCoordinatorAsync.when(
          data: (isCoordinator) {
            if (!isCoordinator) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/courses/${course.id}/edit');
                } else if (value == 'lessons') {
                  context.push('/courses/${course.id}/lessons');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar Curso'),
                    ],
                  ),
                ),
                if (course.courseType == CourseType.onlineRecorded)
                  const PopupMenuItem(
                    value: 'lessons',
                    child: Row(
                      children: [
                        Icon(Icons.video_library, size: 20),
                        SizedBox(width: 8),
                        Text('Gerenciar Aulas'),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          course.title,
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
            // Capa do curso (se tiver)
            if (course.imageUrl != null)
              Image.network(
                course.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultCover(course);
                },
              )
            else
              _buildDefaultCover(course),

            // Gradiente para melhorar legibilidade do título
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

  /// Capa padrão quando não há imagem
  Widget _buildDefaultCover(Course course) {
    return Container(
      color: Colors.blue.shade700,
      child: const Center(
        child: Icon(
          Icons.school,
          size: 80,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// Informações do curso
  Widget _buildCourseInfo(Course course) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo e Categoria
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  _getIconForType(course.courseType),
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(course.courseType.label),
                backgroundColor: Colors.blue,
                labelStyle: const TextStyle(color: Colors.white),
              ),
              if (course.category != null)
                Chip(
                  label: Text(course.category!),
                  backgroundColor: Colors.grey.shade200,
                ),
              Chip(
                label: Text(course.level),
                backgroundColor: Colors.green.shade100,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Instrutor
          if (course.instructor != null) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Instrutor: ${course.instructor}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Datas
          if (course.startDate != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Início: ${_formatDate(course.startDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (course.endDate != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Término: ${_formatDate(course.endDate!)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Descrição
          if (course.description != null && course.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Sobre o curso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              course.description!,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],

          // Informações de Pagamento
          if (course.isPaid) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payment, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Curso Pago',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (course.price != null)
                      Text(
                        'Valor: R\$ ${course.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (course.paymentInfo != null && course.paymentInfo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Informações de Pagamento:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.paymentInfo!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Lista de aulas disponíveis (vertical)
  Widget _buildLessonsList(List<CourseLesson> lessons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Aulas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${lessons.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Lista vertical de aulas
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lessons.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final lessonNumber = index + 1;
              return _buildLessonListItem(lesson, lessonNumber);
            },
          ),
        ],
      ),
    );
  }

  /// Item da lista de aulas
  Widget _buildLessonListItem(CourseLesson lesson, int lessonNumber) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push(
            '/courses/${widget.courseId}/lessons/${lesson.id}/view',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Capa da aula ou placeholder
              _buildLessonThumbnail(lesson),
              const SizedBox(width: 12),
              // Informações da aula
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aula $lessonNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lesson.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thumbnail da aula
  Widget _buildLessonThumbnail(CourseLesson lesson) {
    return Container(
      width: 100,
      height: 75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade100,
      ),
      child: lesson.coverImageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                lesson.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.play_circle_outline,
                    size: 40,
                    color: Colors.blue.shade700,
                  );
                },
              ),
            )
          : Icon(
              Icons.play_circle_outline,
              size: 40,
              color: Colors.blue.shade700,
            ),
    );
  }

  /// Conteúdo quando não há aulas
  Widget _buildNoLessonsContent() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aula disponível',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Informações para cursos presenciais e online ao vivo
  Widget _buildCourseTypeInfo(Course course) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForType(course.courseType),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      course.courseType == CourseType.presencial
                          ? 'Curso Presencial'
                          : 'Curso Online ao Vivo',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Online ao Vivo - Link da sala
              if (course.courseType == CourseType.onlineLive &&
                  course.meetingLink != null) ...[
                const Text(
                  'Link da sala:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _launchUrl(course.meetingLink!),
                  icon: const Icon(Icons.video_call),
                  label: const Text('Entrar na Sala'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],

              // Presencial - Endereço
              if (course.courseType == CourseType.presencial) ...[
                const Text(
                  'Este curso será realizado presencialmente.',
                  style: TextStyle(fontSize: 14),
                ),
                if (course.address != null && course.address!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.address!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(CourseType type) {
    switch (type) {
      case CourseType.presencial:
        return Icons.location_on;
      case CourseType.onlineLive:
        return Icons.videocam;
      case CourseType.onlineRecorded:
        return Icons.video_library;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
