import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/widgets/church_image.dart';

import '../providers/devotional_provider.dart';
import '../../domain/models/devotional.dart';
import '../../../../core/design/community_design.dart';
import '../../../community/presentation/providers/community_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

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

    final scaffold = Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        titleSpacing: widget.fromDashboard ? 0 : 16,
        centerTitle: false,
        leadingWidth: widget.fromDashboard ? 54 : null,
        leading: widget.fromDashboard
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  tooltip: 'Voltar',
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/dashboard');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              )
            : null,
        title: Padding(
          padding: widget.fromDashboard ? const EdgeInsets.only(left: 4, right: 12) : EdgeInsets.zero,
          child: Row(
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
        ),
        actions: [
          if (widget.fromDashboard)
            PermissionGate(
              permission: 'devotionals.create',
              showLoading: false,
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
                    child: _DevotionalCard(
                      devotional: sorted[index],
                      isManagementMode: widget.fromDashboard,
                    ),
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

    if (!widget.fromDashboard) return scaffold;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/dashboard');
        }
      },
      child: scaffold,
    );
  }
}

class SavedDevotionalsScreen extends ConsumerWidget {
  const SavedDevotionalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalsAsync = ref.watch(savedDevotionalsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
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
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.18),
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
                Icons.bookmark,
                size: 16,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Devocionais Salvos',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: devotionalsAsync.when(
        data: (devotionals) {
          final count = devotionals.length;
          if (count == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 56,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum devocional salvo ainda',
                      style: CommunityDesign.titleStyle(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toque em “Salvar” em um devocional para ler depois.',
                      style: CommunityDesign.metaStyle(context),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                decoration: CommunityDesign.overlayDecoration(cs),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bookmark, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você tem $count devocionais salvos',
                        style: CommunityDesign.titleStyle(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...devotionals
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DevotionalCard(devotional: d),
                    ),
                  )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

/// Card de devocional
class _DevotionalCard extends ConsumerStatefulWidget {
  final Devotional devotional;
  final bool isManagementMode;

  const _DevotionalCard({
    required this.devotional,
    this.isManagementMode = false,
  });

  @override
  ConsumerState<_DevotionalCard> createState() => _DevotionalCardState();
}

class _DevotionalCardState extends ConsumerState<_DevotionalCard>
    with SingleTickerProviderStateMixin {
  String? _reactionOverride;
  int? _likesOverride;
  bool _isTogglingLike = false;
  bool _likePulse = false;
  bool? _savedOverride;
  bool _isTogglingSave = false;
  final LayerLink _reactionLink = LayerLink();
  final GlobalKey _reactionTargetKey = GlobalKey();
  OverlayEntry? _reactionOverlay;
  Completer<String?>? _reactionCompleter;
  late final AnimationController _reactionController;
  bool _reactionsShowBelow = false;
  double _reactionsAnchorX = 0;

  static const _emojiFallback = <String>[
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  @override
  void initState() {
    super.initState();
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _dismissReactionPicker(immediate: true);
    _reactionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DevotionalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.devotional.id != widget.devotional.id ||
        oldWidget.devotional.likesCount != widget.devotional.likesCount ||
        oldWidget.devotional.myReaction != widget.devotional.myReaction ||
        oldWidget.devotional.isSavedByMe != widget.devotional.isSavedByMe) {
      _reactionOverride = null;
      _likesOverride = null;
      _savedOverride = null;
      _dismissReactionPicker(immediate: true);
    }
  }

  String _reactionEmoji(String reaction) {
    switch (reaction) {
      case 'amen':
        return '🙏';
      case 'pray':
        return '🙌';
      case 'fire':
        return '🔥';
      default:
        return '👍';
    }
  }

  Future<void> _applyReaction({
    required String? currentReaction,
    required int currentLikesCount,
    required String nextReaction,
  }) async {
    if (_isTogglingLike) return;
    if (currentReaction == nextReaction) return;

    final nextCount = (currentLikesCount + (currentReaction == null ? 1 : 0))
        .clamp(0, 1 << 30);

    setState(() {
      _isTogglingLike = true;
      _reactionOverride = nextReaction;
      _likesOverride = nextCount;
      _likePulse = true;
    });

    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _likePulse = false);
    });

    try {
      await ref
          .read(communityRepositoryProvider)
          .setDevotionalReaction(widget.devotional.id, nextReaction);
      ref.invalidate(allDevotionalsProvider);
      ref.invalidate(allDevotionalsIncludingDraftsProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _reactionOverride = currentReaction;
          _likesOverride = currentLikesCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _removeReaction({
    required String? currentReaction,
    required int currentLikesCount,
  }) async {
    if (_isTogglingLike) return;
    if (currentReaction == null) return;

    final nextCount = (currentLikesCount - 1).clamp(0, 1 << 30);

    setState(() {
      _isTogglingLike = true;
      _reactionOverride = null;
      _likesOverride = nextCount;
      _likePulse = true;
    });

    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _likePulse = false);
    });

    try {
      await ref
          .read(communityRepositoryProvider)
          .removeDevotionalReaction(widget.devotional.id);
      ref.invalidate(allDevotionalsProvider);
      ref.invalidate(allDevotionalsIncludingDraftsProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _reactionOverride = currentReaction;
          _likesOverride = currentLikesCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  void _dismissReactionPicker({String? result, bool immediate = false}) {
    final completer = _reactionCompleter;
    final overlay = _reactionOverlay;
    if (completer == null && overlay == null) return;

    _reactionCompleter = null;
    _reactionOverlay = null;

    Future<void>(() async {
      if (overlay != null) {
        if (immediate) {
          overlay.remove();
        } else {
          try {
            await _reactionController.reverse();
          } finally {
            overlay.remove();
          }
        }
      }
      if (completer != null && !completer.isCompleted) {
        completer.complete(result);
      }
    });
  }

  Future<String?> _showReactionPicker(BuildContext context, String? selected) {
    final existing = _reactionCompleter;
    if (existing != null) return existing.future;

    final box =
        _reactionTargetKey.currentContext?.findRenderObject() as RenderBox?;
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (box != null) {
      final top = box.localToGlobal(Offset.zero).dy;
      _reactionsShowBelow = top < 104;
      final centerX =
          box.localToGlobal(Offset(box.size.width / 2, 0)).dx;
      if (centerX < screenWidth / 3) {
        _reactionsAnchorX = -1;
      } else if (centerX > (screenWidth * 2) / 3) {
        _reactionsAnchorX = 1;
      } else {
        _reactionsAnchorX = 0;
      }
    } else {
      _reactionsShowBelow = false;
      _reactionsAnchorX = 0;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final options = const [
      ('like', 'Curtir', '👍'),
      ('amen', 'Amém', '🙏'),
      ('pray', 'Orar', '🙌'),
      ('fire', 'Fogo', '🔥'),
    ];

    _reactionCompleter = Completer<String?>();
    _reactionController.value = 0;

    final overlay = Overlay.of(context, rootOverlay: true);
    _reactionOverlay = OverlayEntry(
      builder: (context) {
        final builderScreenWidth = MediaQuery.sizeOf(context).width;
        final isNarrow = builderScreenWidth < 420;
        final optionPadding = EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 12,
          vertical: 8,
        );
        final emojiSize = isNarrow ? 20.0 : 22.0;
        final labelSize = isNarrow ? 10.0 : 11.0;
        final containerPadding = EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 10,
          vertical: isNarrow ? 8 : 10,
        );

        final opacity = CurvedAnimation(
          parent: _reactionController,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween<double>(begin: 0.98, end: 1).animate(
          CurvedAnimation(
            parent: _reactionController,
            curve: Curves.easeOutBack,
          ),
        );

        final targetAnchor = Alignment(
          _reactionsAnchorX,
          _reactionsShowBelow ? 1 : -1,
        );
        final followerAnchor = Alignment(
          _reactionsAnchorX,
          _reactionsShowBelow ? -1 : 1,
        );
        final offset =
            _reactionsShowBelow ? const Offset(0, 10) : const Offset(0, -10);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _dismissReactionPicker(immediate: false),
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _reactionLink,
              showWhenUnlinked: false,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: offset,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    alignment: Alignment(
                      _reactionsAnchorX,
                      _reactionsShowBelow ? -1 : 1,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: builderScreenWidth - 16,
                      ),
                      child: Container(
                        padding: containerPadding,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.10),
                          ),
                        ),
                        child: isNarrow
                            ? Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final option in options)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => _dismissReactionPicker(
                                        result: option.$1,
                                        immediate: false,
                                      ),
                                      child: Padding(
                                        padding: optionPadding,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              option.$3,
                                              style: TextStyle(
                                                fontSize: emojiSize,
                                                fontFamilyFallback:
                                                    _emojiFallback,
                                                height: 1,
                                                color: selected == option.$1
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              option.$2,
                                              style: TextStyle(
                                                fontSize: labelSize,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                                color: selected == option.$1
                                                    ? colorScheme.primary
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final option in options) ...[
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => _dismissReactionPicker(
                                        result: option.$1,
                                        immediate: false,
                                      ),
                                      child: Padding(
                                        padding: optionPadding,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              option.$3,
                                              style: TextStyle(
                                                fontSize: emojiSize,
                                                fontFamilyFallback:
                                                    _emojiFallback,
                                                height: 1,
                                                color: selected == option.$1
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              option.$2,
                                              style: TextStyle(
                                                fontSize: labelSize,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                                color: selected == option.$1
                                                    ? colorScheme.primary
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (option != options.last)
                                      SizedBox(
                                        height: 34,
                                        child: VerticalDivider(
                                          width: 10,
                                          thickness: 1,
                                          color: colorScheme.outline.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_reactionOverlay!);
    _reactionController.forward();

    return _reactionCompleter!.future;
  }

  @override
  Widget build(BuildContext context) {
    final devotional = widget.devotional;
    final hasReadAsync = ref.watch(hasUserReadDevotionalProvider(devotional.id));
    final isSaved = _savedOverride ?? devotional.isSavedByMe;
    String? imageUrl;
    if (devotional.imageUrl != null) {
      imageUrl = devotional.imageUrl;
    } else if (devotional.hasYoutubeVideo && devotional.youtubeUrl != null) {
      final id = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
      imageUrl = id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null;
    }

    return InkWell(
      onTap: widget.isManagementMode
          ? () => context.push('/devotionals/${devotional.id}/edit')
          : () => context.push('/devotionals/${devotional.id}'),
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
                    if (isSaved)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SALVO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 380;
                    final colorScheme = Theme.of(context).colorScheme;

                    Widget buildPillButton({
                      required Widget icon,
                      Widget? label,
                      required Color actionColor,
                      required VoidCallback? onPressed,
                    }) {
                      return Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            actionColor,
                            compact: isCompact,
                          ),
                          onPressed: onPressed,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              icon,
                              if (label != null) ...[
                                const SizedBox(width: 6),
                                label,
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    final myReaction = _reactionOverride ?? devotional.myReaction;
                    final isLiked = myReaction != null;
                    final likesCount = _likesOverride ?? devotional.likesCount;
                    final muted = colorScheme.onSurfaceVariant;

                    return Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final actionColor =
                                  isLiked ? colorScheme.primary : muted;
                              return AnimatedScale(
                                scale: _likePulse ? 1.03 : 1,
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                child: CompositedTransformTarget(
                                  link: _reactionLink,
                                  child: SizedBox(
                                    key: _reactionTargetKey,
                                    child: buildPillButton(
                                      icon: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        switchInCurve: Curves.easeOutBack,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (child, anim) =>
                                            ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                        child: isLiked
                                            ? Text(
                                                _reactionEmoji(myReaction),
                                                key: ValueKey<String?>(
                                                  myReaction,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontFamilyFallback:
                                                      _emojiFallback,
                                                ),
                                              )
                                            : Icon(
                                                Icons.thumb_up_outlined,
                                                key: const ValueKey<String>(
                                                  'none',
                                                ),
                                              ),
                                      ),
                                      label: isCompact
                                          ? Text('$likesCount')
                                          : Text('Curtir ($likesCount)'),
                                      actionColor: actionColor,
                                      onPressed: _isTogglingLike
                                          ? null
                                          : () async {
                                              final picked =
                                                  await _showReactionPicker(
                                                context,
                                                myReaction,
                                              );
                                              if (!mounted ||
                                                  picked == null) {
                                                return;
                                              }

                                              if (picked == myReaction) {
                                                if (myReaction == null) return;
                                                await _removeReaction(
                                                  currentReaction: myReaction,
                                                  currentLikesCount: likesCount,
                                                );
                                                return;
                                              }

                                              await _applyReaction(
                                                currentReaction: myReaction,
                                                currentLikesCount: likesCount,
                                                nextReaction: picked,
                                              );
                                            },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: buildPillButton(
                            icon: const Icon(Icons.mode_comment_outlined),
                            label: isCompact ? null : const Text('Comentar'),
                            actionColor: muted,
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) => _DevotionalCommentsSheet(
                                  devotionalId: devotional.id,
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: buildPillButton(
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_outline,
                            ),
                            label: isCompact ? null : Text(isSaved ? 'Salvo' : 'Salvar'),
                            actionColor: isSaved ? Theme.of(context).colorScheme.primary : muted,
                            onPressed: _isTogglingSave
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    setState(() {
                                      _isTogglingSave = true;
                                      _savedOverride = !isSaved;
                                    });
                                    try {
                                      final savedNow = await ref
                                          .read(devotionalActionsProvider)
                                          .toggleSaveDevotional(devotional.id);
                                      if (!mounted) return;
                                      setState(() => _savedOverride = savedNow);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            savedNow
                                                ? 'Salvo para ler depois'
                                                : 'Removido dos salvos',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      setState(() => _savedOverride = isSaved);
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Erro: $e')),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isTogglingSave = false);
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    );
                  },
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
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
          ),
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
