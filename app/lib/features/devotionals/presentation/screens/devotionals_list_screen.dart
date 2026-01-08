import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../../core/widgets/church_image.dart';

import '../providers/devotional_provider.dart';
import '../../domain/models/devotional.dart';
import '../../../../core/design/community_design.dart';
import '../../../community/presentation/providers/community_providers.dart';

/// Tela de listagem de devocionais
class DevotionalsListScreen extends ConsumerStatefulWidget {
  final bool fromDashboard;
  const DevotionalsListScreen({super.key, this.fromDashboard = false});

  @override
  ConsumerState<DevotionalsListScreen> createState() => _DevotionalsListScreenState();
}

class _DevotionalsListScreenState extends ConsumerState<DevotionalsListScreen> {
  String _timeAgoLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? 'há 1 semana' : 'há $weeks semanas';
    }
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? 'há 1 dia' : 'há ${diff.inDays} dias';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? 'há 1 hora' : 'há ${diff.inHours} horas';
    }
    if (diff.inMinutes >= 1) {
      return diff.inMinutes == 1 ? 'há 1 minuto' : 'há ${diff.inMinutes} minutos';
    }
    return 'agora';
  }

  @override
  Widget build(BuildContext context) {
    final devotionalsAsync = ref.watch(widget.fromDashboard ? allDevotionalsIncludingDraftsProvider : allDevotionalsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
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
                  Icons.menu_book_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.fromDashboard ? 'Gerenciar Devocionais' : 'Devocionais',
                      style: CommunityDesign.titleStyle(context).copyWith(fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fromDashboard ? 'Criar, editar e organizar devocionais' : 'Alimente sua fé diariamente',
                      style: CommunityDesign.metaStyle(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        actions: [
          if (widget.fromDashboard)
            CoordinatorOnlyWidget(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.icon(
                  onPressed: () => context.push('/devotionals/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
              ),
            ),
        ],
      ),
      body: devotionalsAsync.when(
        data: (devotionals) {
          if (devotionals.isEmpty) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text('Nenhum devocional encontrado', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Os devocionais aparecerão aqui',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            );
          }
          final sorted = [...devotionals]..sort((a, b) => b.devotionalDate.compareTo(a.devotionalDate));
          final latest = sorted.first;
          final now = DateTime.now();
          final weekCount = sorted.where((d) => d.devotionalDate.isAfter(now.subtract(const Duration(days: 7)))).length;
          final todayCount = sorted.where((d) => d.devotionalDate.year == now.year && d.devotionalDate.month == now.month && d.devotionalDate.day == now.day).length;
          final accent = Theme.of(context).colorScheme.primary;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Container(
                        decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme, hovered: true),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(CommunityDesign.radius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Consumer(
                              builder: (context, ref, _) {
                                final mostReadAsync = ref.watch(mostReadDevotionalsProvider);
                                final weeklyReadsAsync = ref.watch(weeklyReadingsCountProvider);
                                final todayReadsAsync = ref.watch(todayReadingsCountProvider);
                                final weeklyUniqueAsync = ref.watch(weeklyUniqueReadersCountProvider);
                                return Wrap(
                                  alignment: WrapAlignment.center,
                                  runAlignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _ActivityPill(icon: Icons.new_releases_outlined, text: 'Último devocional ${_timeAgoLabel(latest.devotionalDate)}', accent: accent),
                                    _ActivityPill(icon: Icons.calendar_today, text: weekCount == 0 ? 'Sem novos nesta semana' : '$weekCount novos nesta semana', accent: accent),
                                    _ActivityPill(icon: Icons.today, text: todayCount == 0 ? 'Nenhum de hoje' : '$todayCount de hoje', accent: accent),
                                    _ActivityPill(icon: Icons.visibility_outlined, text: 'Total: ${sorted.length}', accent: accent),
                                    mostReadAsync.when(
                                      data: (list) {
                                        if (list.isEmpty) return const SizedBox.shrink();
                                        final title = (list.first['devotionals']?['title'] as String?) ?? 'Mais lido';
                                        return _ActivityPill(icon: Icons.local_fire_department_outlined, text: 'Mais lido: $title', accent: accent);
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                    weeklyReadsAsync.when(
                                      data: (count) {
                                        return _ActivityPill(icon: Icons.bar_chart, text: 'Leituras nesta semana: $count', accent: accent);
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                    todayReadsAsync.when(
                                      data: (count) {
                                        return _ActivityPill(icon: Icons.insights, text: 'Leituras hoje: $count', accent: accent);
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                    weeklyUniqueAsync.when(
                                      data: (count) {
                                        return _ActivityPill(icon: Icons.group, text: 'Leitores únicos semana: $count', accent: accent);
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                sliver: SliverList.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DevotionalCard(devotional: sorted[index]),
                  ),
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
              Text('Erro ao carregar devocionais: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de devocional
class _DevotionalCard extends ConsumerWidget {
  final Devotional devotional;

  const _DevotionalCard({required this.devotional});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReadAsync = ref.watch(hasUserReadDevotionalProvider(devotional.id));
    String? imageUrl;
    if (devotional.imageUrl != null) {
      imageUrl = devotional.imageUrl;
    } else if (devotional.hasYoutubeVideo && devotional.youtubeUrl != null) {
      final id = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
      imageUrl = id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null;
    }

    return InkWell(
      onTap: () => context.push('/devotionals/${devotional.id}'),
      borderRadius: BorderRadius.circular(CommunityDesign.radius),
      child: Container(
        decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme, hovered: true),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CommunityDesign.radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                ChurchImage(
                  imageUrl: imageUrl,
                  type: ChurchImageType.card,
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Icon(
                      devotional.isToday
                          ? Icons.today
                          : devotional.isFuture
                              ? Icons.schedule
                              : Icons.history,
                      size: 20,
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
                        style: CommunityDesign.metaStyle(context),
                      ),
                    ),
                    if (!devotional.isPublished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RASCUNHO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    hasReadAsync.when(
                      data: (hasRead) {
                        if (!hasRead) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'LIDO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
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
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final accent = CommunityDesign.devotionalAccent(context, devotional.category);
                    final isNew = devotional.devotionalDate.isAfter(DateTime.now().subtract(const Duration(days: 7)));
                    final mostReadAsync = ref.watch(mostReadDevotionalsProvider);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            devotional.title,
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          CommunityDesign.badge(context, 'NOVO', accent),
                        ],
                        const SizedBox(width: 8),
                        mostReadAsync.when(
                          data: (list) {
                            final ids = list.map((m) => m['devotional_id'] as String?).whereType<String>().toSet();
                            final isTop = ids.contains(devotional.id);
                            if (!isTop) return const SizedBox.shrink();
                            return CommunityDesign.amberBadge(context, 'MAIS LIDO');
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
                if (devotional.scriptureReference != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.menu_book, size: 16, color: CommunityDesign.devotionalAccent(context, devotional.category)),
                      const SizedBox(width: 4),
                      Text(
                        devotional.scriptureReference!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (devotional.category != null || devotional.preacher != null || devotional.hasYoutubeVideo) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (devotional.category != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(devotional.categoryText, style: CommunityDesign.metaStyle(context)),
                          ],
                        ),
                      if (devotional.preacher != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(devotional.preacher!, style: CommunityDesign.metaStyle(context)),
                          ],
                        ),
                      if (devotional.hasYoutubeVideo)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.video_library, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('Vídeo', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red, fontWeight: FontWeight.w500)),
                          ],
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  devotional.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: CommunityDesign.contentStyle(context).copyWith(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16)),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          style: CommunityDesign.pillButtonStyle(context, Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: () async {
                            try {
                              await ref.read(communityRepositoryProvider).toggleDevotionalLike(devotional.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                              }
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thumb_up_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text('Curtir', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          style: CommunityDesign.pillButtonStyle(context, Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (context) => _DevotionalCommentsSheet(devotionalId: devotional.id),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mode_comment_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text('Comentar', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          style: CommunityDesign.pillButtonStyle(context, Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo para ler depois')));
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text('Salvar', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const _ActivityPill({required this.icon, required this.text, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DevotionalCommentsSheet extends ConsumerStatefulWidget {
  final String devotionalId;
  const _DevotionalCommentsSheet({required this.devotionalId});

  @override
  ConsumerState<_DevotionalCommentsSheet> createState() => _DevotionalCommentsSheetState();
}

class _DevotionalCommentsSheetState extends ConsumerState<_DevotionalCommentsSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await ref.read(communityRepositoryProvider).getDevotionalComments(widget.devotionalId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(communityRepositoryProvider).addDevotionalComment(widget.devotionalId, _controller.text.trim());
      _controller.clear();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsDisabled = _errorMessage != null;
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Comentários',
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  _errorMessage!.replaceFirst('Exception: ', ''),
                                  textAlign: TextAlign.center,
                                  style: CommunityDesign.metaStyle(context),
                                ),
                              ),
                            )
                          : _comments.isEmpty
                              ? Center(
                                  child: Text(
                                    'Seja o primeiro a comentar!',
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _comments.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final comment = _comments[index];
                                    final author = comment['author'] ?? {};
                                    final createdAt = DateTime.tryParse(comment['created_at']) ?? DateTime.now();

                                    final name = author['full_name'] ?? author['nickname'] ?? 'Anônimo';
                                    final avatarText = (author['full_name'] ?? author['nickname'] ?? '?').toString();
                                    final avatarInitial = avatarText.isNotEmpty ? avatarText[0] : '?';

                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundImage: author['avatar_url'] != null ? NetworkImage(author['avatar_url']) : null,
                                          child: author['avatar_url'] == null ? Text(avatarInitial) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: CommunityDesign.titleStyle(context).copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat('dd/MM HH:mm').format(createdAt),
                                                      style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  (comment['content'] ?? '').toString(),
                                                  style: CommunityDesign.metaStyle(context).copyWith(
                                                    height: 1.5,
                                                    color: colorScheme.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Escreva um comentário...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          maxLines: null,
                          enabled: !commentsDisabled,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (commentsDisabled || _isSending) ? null : _addComment,
                          style: CommunityDesign.pillButtonStyle(context, colorScheme.primary),
                          child: _isSending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
