import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/courses_provider.dart';
import '../../domain/models/course.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/church_image.dart';

/// Tela de listagem de cursos
class CoursesListScreen extends ConsumerStatefulWidget {
  final bool showFab;

  const CoursesListScreen({
    super.key,
    this.showFab = false, // Por padrão não mostra FAB (para aba Mais)
  });

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  String _filter = 'all'; // 'all', 'active', 'upcoming'

  @override
  Widget build(BuildContext context) {
    final coursesAsync = _filter == 'active'
        ? ref.watch(activeCoursesProvider)
        : _filter == 'upcoming'
        ? ref.watch(upcomingCoursesProvider)
        : ref.watch(allCoursesProvider);

    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: CommunityDesign.headerColor(context),
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Cursos', style: CommunityDesign.titleStyle(context)),
                  Text(
                    'Aprendizado e crescimento',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          toolbarHeight: 64,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                initialValue: _filter,
                onSelected: (value) {
                  setState(() => _filter = value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'all', child: Text('Todos')),
                  const PopupMenuItem(value: 'active', child: Text('Ativos')),
                  const PopupMenuItem(
                    value: 'upcoming',
                    child: Text('Em breve'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: widget.showFab
            ? isCoordinatorAsync.when(
                data: (isCoordinator) {
                  if (!isCoordinator) return null;
                  return FloatingActionButton.extended(
                    onPressed: () => context.push('/courses/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Curso'),
                  );
                },
                loading: () => null,
                error: (_, __) => null,
              )
            : null,
        body: coursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum curso disponível',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Os cursos aparecerão aqui quando forem cadastrados',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allCoursesProvider);
                ref.invalidate(activeCoursesProvider);
                ref.invalidate(upcomingCoursesProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return _CourseCard(
                    course: course,
                    showEditButton: widget.showFab,
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erro ao carregar cursos: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(allCoursesProvider);
                    ref.invalidate(activeCoursesProvider);
                    ref.invalidate(upcomingCoursesProvider);
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de curso
class _CourseCard extends ConsumerWidget {
  final Course course;
  final bool showEditButton;

  const _CourseCard({required this.course, this.showEditButton = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navegar para visualização do curso
          context.push('/courses/${course.id}/view');
        },
        onLongPress: () {
          // Long press para editar (apenas coordenadores)
          isCoordinatorAsync.whenData((isCoordinator) {
            if (isCoordinator) {
              context.push('/courses/${course.id}/edit');
            }
          });
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem do curso
                if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
                  ChurchImage(
                    imageUrl: course.imageUrl!,
                    type: ChurchImageType.card,
                  )
                else
                  _buildPlaceholderImage(context),

                // Conteúdo do card
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Text(
                        course.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Instrutor
                      if (course.instructor != null)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course.instructor!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Descrição
                      if (course.description != null &&
                          course.description!.isNotEmpty)
                        Text(
                          course.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),

                      // Informações adicionais
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Nível
                          _buildChip(
                            context,
                            icon: Icons.signal_cellular_alt,
                            label: course.level,
                            color: _getLevelColor(course.level),
                          ),

                          // Status
                          _buildChip(
                            context,
                            icon: _getStatusIcon(course.status),
                            label: course.statusText,
                            color: _getStatusColor(course.status),
                          ),

                          // Duração
                          if (course.duration != null)
                            _buildChip(
                              context,
                              icon: Icons.access_time,
                              label: '${course.duration}h',
                              color: Colors.blue,
                            ),

                          // Categoria
                          if (course.category != null)
                            _buildChip(
                              context,
                              icon: Icons.category_outlined,
                              label: course.category!,
                              color: Colors.purple,
                            ),

                          // Vagas
                          if (course.maxStudents != null)
                            _buildChip(
                              context,
                              icon: Icons.people_outline,
                              label:
                                  '${course.enrolledCount ?? 0}/${course.maxStudents}',
                              color: course.isFull ? Colors.red : Colors.green,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Botão de editar (apenas quando showEditButton=true e for coordenador)
            if (showEditButton)
              isCoordinatorAsync.when(
                data: (isCoordinator) {
                  if (!isCoordinator) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 4,
                      child: InkWell(
                        onTap: () {
                          context.push('/courses/${course.id}/edit');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.school,
        size: 80,
        color: Theme.of(
          context,
        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: CommunityDesign.metaStyle(
          context,
        ).copyWith(fontWeight: FontWeight.w500),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'básico':
        return Colors.green;
      case 'intermediário':
        return Colors.orange;
      case 'avançado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle_outline;
      case 'upcoming':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
}
