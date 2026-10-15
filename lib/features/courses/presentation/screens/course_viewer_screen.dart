import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/course.dart';
import '../../domain/models/course_lesson.dart';
import '../providers/courses_provider.dart';
import '../hub/course_hub_cta.dart';
import '../widgets/course_subjects_section.dart';
import '../widgets/course_turmas_section.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../support_materials/domain/models/support_material_link.dart';
import '../../../support_materials/presentation/widgets/linked_materials.dart';
import '../widgets/course_purchase_card.dart';
import '../widgets/course_study_panel.dart';

/// Tela de visualização de curso (para alunos)
class CourseViewerScreen extends ConsumerStatefulWidget {
  final String courseId;

  /// Aberta pela Dashboard (`?from=dashboard`): só então o ⋮ de gestão
  /// (Editar Curso / Gerenciar Aulas) aparece. Por Cursos é só exibição.
  final bool fromDashboard;

  const CourseViewerScreen({
    super.key,
    required this.courseId,
    this.fromDashboard = false,
  });

  @override
  ConsumerState<CourseViewerScreen> createState() => _CourseViewerScreenState();
}

class _CourseViewerScreenState extends ConsumerState<CourseViewerScreen> {
  /// Âncora da seção Turmas, para o "Ver turmas / Gerenciar" rolar até ela.
  final _turmasKey = GlobalKey();

  void _scrollToTurmas() {
    final target = _turmasKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseByIdProvider(widget.courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(widget.courseId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: courseAsync.when(
        data: (course) {
          if (course == null) {
            return const Center(child: Text('Curso não encontrado'));
          }

          // Painel de estudo (E1 + E2): o curso gravado sempre; o
          // presencial / ao vivo quando a gestão copiou as aulas da
          // turma para o curso (E2b). Sem aula, o gravado mostra o aviso
          // e os outros só o endereço / link da sala.
          final isRecorded = course.courseType == CourseType.onlineRecorded;
          final hasLessons = lessonsAsync.valueOrNull?.isNotEmpty ?? false;
          final Widget? studyPanel = isRecorded || hasLessons
              ? lessonsAsync.when(
                  data: (lessons) => lessons.isEmpty
                      ? _buildNoLessonsContent()
                      : _buildStudyPanel(course, lessons),
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
              : null;
          // Tablet deitado / PC (B7): as aulas ficam numa coluna ao lado.
          final sideBySide =
              studyPanel != null &&
              context.breakpoint == Breakpoint.expanded;

          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informações do curso
              _buildCourseInfo(course),

              // Chamada por estado (decisão 24): Inscrever-se,
              // Acessar minha turma, Ver turmas / Gerenciar.
              CourseHubCta(
                courseId: course.id,
                onManage: _scrollToTurmas,
                fromDashboard: widget.fromDashboard,
              ),

              const Divider(height: 32),

              if (!isRecorded) _buildCourseTypeInfo(course),
              if (studyPanel != null && !sideBySide) studyPanel,

              const SizedBox(height: 24),

              // Matérias do curso (PR 2a): só a gestão vê, e só
              // pela Dashboard.
              if (widget.fromDashboard)
                CourseSubjectsSection(courseId: course.id),

              // Material de apoio vinculado ao curso pelo módulo
              // Material de Apoio (some quando não há).
              LinkedMaterialsSection(
                linkType: MaterialLinkType.course,
                entityId: course.id,
              ),

              // Turmas do curso (study_groups.course_id), para
              // qualquer tipo de curso. Carrega à parte das aulas.
              CourseTurmasSection(
                key: _turmasKey,
                courseId: course.id,
                fromDashboard: widget.fromDashboard,
              ),

              const SizedBox(height: 32),
            ],
          );

          return CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, course),

              // Conteúdo
              SliverToBoxAdapter(
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: column),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: studyPanel,
                            ),
                          ),
                        ],
                      )
                    : column,
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
    final canEditAsync = ref.watch(currentUserHasPermissionProvider('courses.edit'));
    final canManageLessonsAsync = ref.watch(
      currentUserHasPermissionProvider('courses.manage_lessons'),
    );

    return SliverAppBar(
      backgroundColor: CommunityDesign.headerColor(context),
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      expandedHeight: 250,
      pinned: true,
      actions: [
        canEditAsync.when(
          data: (canEdit) {
            final canManageLessons = canManageLessonsAsync.maybeWhen(
              data: (v) => v,
              orElse: () => false,
            );

            final showEdit = widget.fromDashboard && canEdit;
            // E2b: qualquer tipo de curso pode ter aulas gravadas (o
            // presencial copia as da turma), então o menu não olha o tipo.
            final showLessons = widget.fromDashboard && canManageLessons;
            if (!showEdit && !showLessons) return const SizedBox.shrink();

            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/courses/${course.id}/edit');
                } else if (value == 'lessons') {
                  context.push('/courses/${course.id}/lessons');
                } else if (value == 'quizzes') {
                  context.push('/courses/${course.id}/quizzes');
                } else if (value == 'purchases') {
                  context.push('/courses/${course.id}/purchases');
                }
              },
              itemBuilder: (context) => [
                if (showEdit)
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
                if (showLessons)
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
                if (showLessons)
                  const PopupMenuItem(
                    value: 'quizzes',
                    child: Row(
                      children: [
                        Icon(Icons.quiz_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Provas'),
                      ],
                    ),
                  ),
                // E6: só no curso pago.
                if (showLessons && course.isPaid)
                  const PopupMenuItem(
                    value: 'purchases',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 20),
                        SizedBox(width: 8),
                        Text('Comprovantes PIX'),
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
            Text(
              'Sobre o curso',
              style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  course.description!,
                  style: CommunityDesign.contentStyle(context).copyWith(fontSize: 16, height: 1.5),
                ),
          ],

          // Curso pago (E6): valor, PIX e envio do comprovante.
          if (course.isPaid) ...[
            const SizedBox(height: 16),
            CoursePurchaseCard(course: course),
          ],
        ],
      ),
    );
  }

  /// Painel de estudo do aluno (E1 + E2): anel de progresso, "Continuar de
  /// onde parou" e os módulos com as aulas. Matérias e progresso carregam à
  /// parte; enquanto não chegam, o painel desenha sem eles.
  Widget _buildStudyPanel(Course course, List<CourseLesson> lessons) {
    final subjects =
        ref.watch(courseSubjectsProvider(widget.courseId)).valueOrNull ??
        const [];
    final progress = ref.watch(courseProgressProvider(widget.courseId)).valueOrNull;
    final lessonProgress =
        ref.watch(lessonProgressMapProvider(widget.courseId)).valueOrNull ??
        const {};
    // E4 + E5: provas, tentativas e certificado carregam à parte.
    final quizzes =
        ref.watch(courseQuizzesProvider(widget.courseId)).valueOrNull ??
        const [];
    final attempts =
        ref.watch(myQuizAttemptsProvider(widget.courseId)).valueOrNull ??
        const {};
    final certificate = ref
        .watch(myCertificateProvider(widget.courseId))
        .valueOrNull;
    return CourseStudyPanel(
      courseId: widget.courseId,
      lessons: lessons,
      subjects: subjects,
      progress: progress,
      lessonProgress: lessonProgress,
      quizzes: quizzes,
      attempts: attempts,
      sequential: course.sequential,
      certificate: certificate,
      onNavigate: context.push,
      onIssueCertificate: _issuing ? null : _issueCertificate,
    );
  }

  bool _issuing = false;

  /// E5: emite o certificado e abre a página pública dele.
  Future<void> _issueCertificate() async {
    setState(() => _issuing = true);
    try {
      final code = await ref
          .read(quizActionsProvider)
          .issueCertificate(widget.courseId);
      if (!mounted) return;
      context.push('/certificado/$code');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('CURSO_INCOMPLETO')
          ? 'Ainda falta concluir aula ou prova deste curso.'
          : 'Não foi possível emitir o certificado: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
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
      child: Container(
        decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
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
                      style: CommunityDesign.titleStyle(context).copyWith(
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
                Text(
                  'Link da sala:',
                  style: CommunityDesign.titleStyle(context).copyWith(
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
                Text(
                  'Este curso será realizado presencialmente.',
                  style: CommunityDesign.contentStyle(context).copyWith(fontSize: 14),
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
                          style: CommunityDesign.contentStyle(context).copyWith(fontSize: 14),
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
