import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yi;
import 'package:flutter/services.dart';

import '../providers/devotional_provider.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../../core/design/community_design.dart';

/// Tela de detalhes do devocional (leitura)
class DevotionalDetailScreen extends ConsumerStatefulWidget {
  final String devotionalId;

  const DevotionalDetailScreen({super.key, required this.devotionalId});

  @override
  ConsumerState<DevotionalDetailScreen> createState() =>
      _DevotionalDetailScreenState();
}

class _DevotionalDetailScreenState
    extends ConsumerState<DevotionalDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isEditingNotes = false;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  bool _animateIn = false;
  double _animateScale = 0.95;
  bool _statsCard1In = false;
  bool _statsCard2In = false;
  bool _isPlayingVideo = false;
  YoutubePlayerController? _youtubeController;
  yi.YoutubePlayerController? _ytIframeController;
  bool _badgeIn = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _animateIn = true;
          _animateScale = 1.0;
        });
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) {
            setState(() => _statsCard1In = true);
          }
        });
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) {
            setState(() => _statsCard2In = true);
          }
        });
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted) {
            setState(() => _badgeIn = true);
          }
        });
      }
    });
  }

  Future<void> _markAsRead() async {
    try {
      setState(() {
        _isSaving = true;
      });
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
        setState(() {
          _isEditingNotes = false;
        });
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _playYouTube(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      return;
    }
    if (kIsWeb) {
      _ytIframeController = yi.YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const yi.YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    } else {
      _youtubeController?.dispose();
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
    setState(() {
      _isPlayingVideo = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final devotionalAsync = ref.watch(
      devotionalByIdProvider(widget.devotionalId),
    );
    final readingAsync = ref.watch(
      userDevotionalReadingProvider(widget.devotionalId),
    );
    final statsAsync = ref.watch(devotionalStatsProvider(widget.devotionalId));
    final streakAsync = ref.watch(currentUserReadingStreakProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Community Theme Background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: const Color(0xFFF5F9FD),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        titleSpacing: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.menu_book_rounded, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Devocional',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222B3A),
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Alimente sua fé',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: devotionalAsync.when(
        data: (devotional) {
          if (devotional == null) {
            return const Center(child: Text('Devocional não encontrado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO SECTION (Imagem/Vídeo)
                if (devotional.imageUrl != null ||
                    devotional.hasYoutubeVideo) ...[
                  AnimatedSlide(
                    offset: _animateIn ? Offset.zero : const Offset(0, 0.05),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: _animateScale,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      child: Container(
                        height: 240,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: devotional.hasYoutubeVideo
                                  ? (_isPlayingVideo
                                        ? (kIsWeb && _ytIframeController != null
                                              ? yi.YoutubePlayer(
                                                  controller:
                                                      _ytIframeController!,
                                                )
                                              : (_youtubeController != null
                                                    ? YoutubePlayer(
                                                        controller:
                                                            _youtubeController!,
                                                        showVideoProgressIndicator:
                                                            true,
                                                      )
                                                    : const SizedBox.shrink()))
                                        : _YoutubeThumbnail(
                                            url: devotional.youtubeUrl!,
                                            onTap: () => _playYouTube(
                                              devotional.youtubeUrl!,
                                            ),
                                          ))
                                  : (devotional.imageUrl != null
                                        ? Image.network(
                                            devotional.imageUrl!,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    color: Colors.grey[200],
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                },
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                  ),
                                                ),
                                          )
                                        : const SizedBox.shrink()),
                            ),
                            if (_isPlayingVideo)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: InkWell(
                                  onTap: () {
                                    _youtubeController?.pause();
                                    _youtubeController?.dispose();
                                    setState(() {
                                      _youtubeController = null;
                                      _ytIframeController = null;
                                      _isPlayingVideo = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // 2. META DATA (Data + Rascunho)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            devotional.formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (devotional.isToday) ...[
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        opacity: _badgeIn ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedScale(
                          scale: _badgeIn ? 1.0 : 0.96,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'HOJE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    readingAsync.when(
                      data: (reading) {
                        if (reading == null) return const SizedBox.shrink();
                        return AnimatedOpacity(
                          opacity: _badgeIn ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: AnimatedScale(
                            scale: _badgeIn ? 1.0 : 0.96,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 12,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LIDO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    if (!devotional.isPublished)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'RASCUNHO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. TÍTULO
                Text(
                  devotional.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 4. REFERÊNCIA BÍBLICA
                if (devotional.scriptureReference != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.menu_book,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEITURA BÍBLICA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                devotional.scriptureReference!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: devotional.scriptureReference!,
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Referência copiada!'),
                                  backgroundColor: cs.primary,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: BorderSide(color: cs.onSurface.withValues(alpha: 0.2)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. CONTEÚDO
                if (devotional.content.isNotEmpty)
                  ...devotional.content
                      .split(RegExp(r'(?:\r?\n){1,}'))
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            p.trim(),
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.6,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 12),

                // Ocultar botão externo quando houver vídeo YouTube (reprodução inline no hero)
                Divider(height: 60, color: cs.onSurface.withValues(alpha: 0.1)),

                // 6. ESTATÍSTICAS EMOCIONAIS
                CoordinatorOnlyWidget(
                  child: statsAsync.when(
                    data: (stats) => AnimatedOpacity(
                      opacity: _animateIn ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: AnimatedSlide(
                        offset: _animateIn
                            ? Offset.zero
                            : const Offset(0, 0.02),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Impacto na Comunidade',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AnimatedOpacity(
                                      opacity: _statsCard1In ? 1 : 0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                      child: AnimatedSlide(
                                        offset: _statsCard1In
                                            ? Offset.zero
                                            : const Offset(0, 0.02),
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration:
                                              CommunityDesign.overlayDecoration(
                                                Theme.of(context).colorScheme,
                                              ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs.primary
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.people_alt_rounded,
                                                  size: 28,
                                                  color: cs.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                child: Text(
                                                  stats.uniqueReaders
                                                      .toString(),
                                                  key: ValueKey(
                                                    stats.uniqueReaders,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'pessoas foram edificadas',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: AnimatedOpacity(
                                      opacity: _statsCard2In ? 1 : 0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                      child: AnimatedSlide(
                                        offset: _statsCard2In
                                            ? Offset.zero
                                            : const Offset(0, 0.02),
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration:
                                              CommunityDesign.overlayDecoration(
                                                Theme.of(context).colorScheme,
                                              ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs.secondary
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.remove_red_eye_rounded,
                                                  size: 28,
                                                  color: cs.secondary,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                child: Text(
                                                  stats.totalReads.toString(),
                                                  key: ValueKey(
                                                    stats.totalReads,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'leituras realizadas',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impacto na Comunidade',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: CommunityDesign.overlayDecoration(
                                    Theme.of(context).colorScheme,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 24,
                                        width: 40,
                                        color: Colors.grey[200],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: CommunityDesign.overlayDecoration(
                                    Theme.of(context).colorScheme,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 24,
                                        width: 40,
                                        color: Colors.grey[200],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                streakAsync.when(
                  data: (streak) {
                    if (streak <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sequência de leitura: $streak dias',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // 7. ANOTAÇÕES (Estilo Acolhedor)
                readingAsync.when(
                  data: (reading) {
                    if (reading != null && !_isEditingNotes) {
                      _notesController.text = reading.notes ?? '';
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: CommunityDesign.overlayDecoration(
                        Theme.of(context).colorScheme,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.edit_note,
                                  color: cs.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Minhas Anotações',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Seu espaço com Deus',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _notesController,
                            maxLines: 4,
                            style: TextStyle(color: cs.onSurface, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'O que Deus falou ao seu coração hoje?',
                              hintStyle: TextStyle(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              filled: true,
                              fillColor: cs.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            onChanged: (_) =>
                                setState(() => _isEditingNotes = true),
                          ),
                        ],
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
        error: (error, stack) => Center(child: Text('Erro: $error')),
      ),
      bottomNavigationBar: devotionalAsync.when(
        data: (devotional) {
          if (devotional == null) {
            return null;
          }
          return readingAsync.when(
            data: (reading) {
              final hasRead = reading != null;

              return Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        minimumSize: const Size(0, 44),
                        disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                      ),
                      onPressed: (_isSaving || (hasRead && !_isEditingNotes))
                          ? null
                          : _markAsRead,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              hasRead ? Icons.check_circle : Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isSaving
                              ? 'Salvando...'
                              : hasRead
                              ? (_isEditingNotes
                                    ? 'Salvar Anotações'
                                    : 'Amém, li este devocional 🙏')
                              : 'Concluir Leitura',
                          key: ValueKey('${hasRead}_$_isEditingNotes'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

class _YoutubeThumbnail extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;

  const _YoutubeThumbnail({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      return Container(color: Colors.grey);
    }

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                color: Colors.grey,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, __, ___) => Container(color: Colors.grey),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}
