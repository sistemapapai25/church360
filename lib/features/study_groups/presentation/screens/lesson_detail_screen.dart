import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/community_design.dart';
import '../providers/study_group_provider.dart';

class LessonDetailScreen extends ConsumerWidget {
  final String groupId;
  final String lessonId;

  const LessonDetailScreen({
    super.key,
    required this.groupId,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));

    return lessonAsync.when(
      data: (lesson) {
        if (lesson == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lição não encontrada')),
            body: const Center(child: Text('Lição não encontrada')),
          );
        }

        return Scaffold(
          backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: CommunityDesign.headerColor(context),
            title: Text(
              'Lição ${lesson.lessonNumber}',
              style: CommunityDesign.titleStyle(context),
            ),
          ),
          body: SingleChildScrollView(
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
                
                // Referências Bíblicas
                if (lesson.bibleReferences != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lesson.bibleReferences!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Descrição
                if (lesson.description != null) ...[
                  Text(
                    lesson.description!,
                    style: CommunityDesign.contentStyle(context),
                  ),
                  const SizedBox(height: 24),
                ],
                
                const Divider(),
                const SizedBox(height: 24),
                
                // Conteúdo em Markdown
                if (lesson.content != null) ...[
                  MarkdownBody(
                    data: lesson.content!,
                    styleSheet: MarkdownStyleSheet(
                      h1: CommunityDesign.titleStyle(context).copyWith(fontSize: 24),
                      h2: CommunityDesign.titleStyle(context).copyWith(fontSize: 20),
                      h3: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
                      p: CommunityDesign.contentStyle(context),
                      blockquote: CommunityDesign.contentStyle(context).copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Perguntas para Discussão
                if (lesson.discussionQuestions != null && lesson.discussionQuestions!.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    'Perguntas para Discussão',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...lesson.discussionQuestions!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              question,
                              style: CommunityDesign.contentStyle(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                
                // Recursos
                if (lesson.videoUrl != null || lesson.audioUrl != null || lesson.pdfUrl != null) ...[
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    'Recursos',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (lesson.videoUrl != null)
                    _buildResourceCard(
                      context,
                      Icons.video_library,
                      'Vídeo da Lição',
                      lesson.videoUrl!,
                    ),
                  if (lesson.audioUrl != null)
                    _buildResourceCard(
                      context,
                      Icons.audiotrack,
                      'Áudio da Lição',
                      lesson.audioUrl!,
                    ),
                  if (lesson.pdfUrl != null)
                    _buildResourceCard(
                      context,
                      Icons.picture_as_pdf,
                      'Material em PDF',
                      lesson.pdfUrl!,
                    ),
                ],
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildResourceCard(BuildContext context, IconData icon, String title, String url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new),
        onTap: () async {
          final uri = Uri.parse(url);
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Não foi possível abrir: $url')),
            );
          }
        },
      ),
    );
  }
}
