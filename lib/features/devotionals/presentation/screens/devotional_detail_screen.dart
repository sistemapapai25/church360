import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../providers/devotional_provider.dart';
import '../../../../core/widgets/permission_widget.dart';

/// Tela de detalhes do devocional (leitura)
class DevotionalDetailScreen extends ConsumerStatefulWidget {
  final String devotionalId;

  const DevotionalDetailScreen({
    super.key,
    required this.devotionalId,
  });

  @override
  ConsumerState<DevotionalDetailScreen> createState() => _DevotionalDetailScreenState();
}

class _DevotionalDetailScreenState extends ConsumerState<DevotionalDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isEditingNotes = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      final actions = ref.read(devotionalActionsProvider);
      
      await actions.markAsRead(
        devotionalId: widget.devotionalId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devocional marcado como lido!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar como lido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDevotional() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Devocional'),
        content: const Text(
          'Tem certeza que deseja deletar este devocional?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final actions = ref.read(devotionalActionsProvider);
      await actions.deleteDevotional(widget.devotionalId);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devocional deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devotionalAsync = ref.watch(devotionalByIdProvider(widget.devotionalId));
    final readingAsync = ref.watch(userDevotionalReadingProvider(widget.devotionalId));
    final statsAsync = ref.watch(devotionalStatsProvider(widget.devotionalId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devocional'),
        actions: [
          // Botão de editar (apenas Coordenadores+)
          CoordinatorOnlyWidget(
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/devotionals/${widget.devotionalId}/edit');
              },
            ),
          ),
          // Botão de deletar (apenas Coordenadores+)
          CoordinatorOnlyWidget(
            child: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteDevotional,
            ),
          ),
        ],
      ),
      body: devotionalAsync.when(
        data: (devotional) {
          if (devotional == null) {
            return const Center(
              child: Text('Devocional não encontrado'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem do devocional ou thumbnail do YouTube
                if (devotional.imageUrl != null || devotional.hasYoutubeVideo) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: devotional.imageUrl != null
                        ? Image.network(
                            devotional.imageUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Se a imagem falhar e tiver YouTube, mostra thumbnail do YouTube
                              if (devotional.hasYoutubeVideo) {
                                final videoId = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
                                if (videoId != null) {
                                  return Image.network(
                                    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.broken_image, size: 48),
                                      );
                                    },
                                  );
                                }
                              }
                              return Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.broken_image, size: 48),
                              );
                            },
                          )
                        : devotional.hasYoutubeVideo
                            ? () {
                                final videoId = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
                                if (videoId != null) {
                                  return Image.network(
                                    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.video_library, size: 48),
                                      );
                                    },
                                  );
                                }
                                return const SizedBox.shrink();
                              }()
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Header com data
                Row(
                  children: [
                    Icon(
                      devotional.isToday
                          ? Icons.today
                          : devotional.isFuture
                              ? Icons.schedule
                              : Icons.history,
                      color: devotional.isToday
                          ? Colors.green
                          : devotional.isFuture
                              ? Colors.orange
                              : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        devotional.formattedDate,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    // Badge de rascunho
                    if (!devotional.isPublished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RASCUNHO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  devotional.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Referência bíblica
                if (devotional.scriptureReference != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            devotional.scriptureReference!,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Categoria e Pregador
                if (devotional.category != null || devotional.preacher != null) ...[
                  Row(
                    children: [
                      if (devotional.category != null) ...[
                        Icon(
                          Icons.category,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          devotional.categoryText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      if (devotional.category != null && devotional.preacher != null)
                        const SizedBox(width: 16),
                      if (devotional.preacher != null) ...[
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          devotional.preacher!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Player do YouTube
                if (devotional.hasYoutubeVideo) ...[
                  _YoutubePlayerWidget(youtubeUrl: devotional.youtubeUrl!),
                  const SizedBox(height: 24),
                ],

                // Conteúdo
                Text(
                  devotional.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Estatísticas (apenas Coordenadores+)
                CoordinatorOnlyWidget(
                  child: statsAsync.when(
                    data: (stats) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estatísticas',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.visibility,
                                    label: 'Leituras',
                                    value: stats.totalReads.toString(),
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.people,
                                    label: 'Leitores',
                                    value: stats.uniqueReaders.toString(),
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                // Seção de anotações
                readingAsync.when(
                  data: (reading) {
                    if (reading != null) {
                      _notesController.text = reading.notes ?? '';
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.note_alt, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Minhas Anotações',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Escreva suas reflexões sobre este devocional...',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _isEditingNotes = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erro ao carregar devocional: $error'),
        ),
      ),
      bottomNavigationBar: devotionalAsync.when(
        data: (devotional) {
          if (devotional == null) return null;

          return readingAsync.when(
            data: (reading) {
              final hasRead = reading != null;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: hasRead && !_isEditingNotes ? null : _markAsRead,
                    icon: Icon(hasRead ? Icons.check_circle : Icons.check),
                    label: Text(
                      hasRead
                          ? (_isEditingNotes ? 'Atualizar Anotações' : 'Já Lido')
                          : 'Marcar como Lido',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: hasRead ? Colors.green : null,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

/// Card de estatística
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget do YouTube Player
class _YoutubePlayerWidget extends StatefulWidget {
  final String youtubeUrl;

  const _YoutubePlayerWidget({required this.youtubeUrl});

  @override
  State<_YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<_YoutubePlayerWidget> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl);
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
          controlsVisibleAtStart: true,
          hideControls: false,
        ),
      )..addListener(() {
          if (_isPlayerReady && mounted) {
            setState(() {});
          }
        });
      _isPlayerReady = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl);

    if (videoId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Link do YouTube inválido',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.video_library,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Vídeo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
              onReady: () {
                setState(() {
                  _isPlayerReady = true;
                });
              },
            ),
            builder: (context, player) {
              return player;
            },
          ),
        ),
      ],
    );
  }
}

