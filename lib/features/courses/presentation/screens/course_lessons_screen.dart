import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/courses_provider.dart';
import '../../domain/models/course_lesson.dart';
import '../../../../core/design/community_design.dart';

/// Tela de gerenciamento de aulas de um curso
class CourseLessonsScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseLessonsScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseLessonsScreen> createState() =>
      _CourseLessonsScreenState();
}

class _CourseLessonsScreenState extends ConsumerState<CourseLessonsScreen> {
  List<CourseLesson> _lessons = [];
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseByIdProvider(widget.courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.play_lesson_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            courseAsync.when(
              data: (course) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aulas', style: CommunityDesign.titleStyle(context)),
                  Text(
                    course?.title ?? 'Conteúdo do curso',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
              loading: () => const Text('Aulas'),
              error: (_, __) => const Text('Aulas'),
            ),
          ],
        ),
        actions: [
          if (_lessons.isNotEmpty)
            IconButton(
              icon: Icon(_isReordering ? Icons.check : Icons.reorder),
              onPressed: () {
                if (_isReordering) {
                  _saveOrder();
                }
                setState(() {
                  _isReordering = !_isReordering;
                });
              },
              tooltip: _isReordering ? 'Salvar Ordem' : 'Reordenar',
            ),
        ],
      ),
      body: lessonsAsync.when(
        data: (lessons) {
          if (lessons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma aula cadastrada',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 22,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clique no botão + para adicionar a primeira aula',
                    style: CommunityDesign.contentStyle(context).copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (_lessons.isEmpty || _lessons.length != lessons.length) {
            _lessons = List.from(lessons);
          }

          if (_isReordering) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _lessons.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _lessons.removeAt(oldIndex);
                  _lessons.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final lesson = _lessons[index];
                return _LessonCard(
                  key: ValueKey(lesson.id),
                  lesson: lesson,
                  index: index,
                  isReordering: _isReordering,
                  onTap: null,
                  onDelete: null,
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return _LessonCard(
                key: ValueKey(lesson.id),
                lesson: lesson,
                index: index,
                isReordering: false,
                onTap: () {
                  context.push(
                    '/courses/${widget.courseId}/lessons/${lesson.id}/edit',
                  );
                },
                onDelete: () => _deleteLesson(lesson),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Erro ao carregar aulas: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/courses/${widget.courseId}/lessons/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Aula'),
      ),
    );
  }

  Future<void> _saveOrder() async {
    try {
      final lessonIds = _lessons.map((l) => l.id).toList();
      final actions = ref.read(courseLessonsActionsProvider);
      await actions.reorderLessons(widget.courseId, lessonIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem das aulas atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar ordem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteLesson(CourseLesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Aula'),
        content: Text(
          'Tem certeza que deseja excluir a aula "${lesson.title}"?',
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

    if (confirmed == true) {
      try {
        final actions = ref.read(courseLessonsActionsProvider);
        await actions.deleteLesson(widget.courseId, lesson.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir aula: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _LessonCard extends StatelessWidget {
  final CourseLesson lesson;
  final int index;
  final bool isReordering;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _LessonCard({
    super.key,
    required this.lesson,
    required this.index,
    required this.isReordering,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: InkWell(
        onTap: isReordering ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Ícone de reordenação ou número
              if (isReordering)
                const Icon(Icons.drag_handle, color: Colors.grey)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (lesson.description != null &&
                        lesson.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (lesson.hasVideo) ...[
                          Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lesson.durationText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (lesson.hasFile) ...[
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Arquivo',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Botões de ação
              if (!isReordering) ...[
                // Botão de editar
                if (onTap != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: onTap,
                    tooltip: 'Editar aula',
                  ),
                // Botão de deletar
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Excluir aula',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
