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
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../community/presentation/providers/community_providers.dart';

const double _pagePadding = 16;
const double _cardRadius = 16;
const double _cardPadding = 16;
const double _gap = 12;
const double _gapLg = 16;
const double _maxFeedWidth = 640;

BoxDecoration _surfaceCardDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: cs.surface,
    borderRadius: BorderRadius.circular(_cardRadius),
    border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
    boxShadow: [CommunityDesign.overlayBaseShadow()],
  );
}

/// Tela de listagem de devocionais
class DevotionalsListScreen extends ConsumerStatefulWidget {
  final bool fromDashboard;
  const DevotionalsListScreen({super.key, this.fromDashboard = false});

  @override
  ConsumerState<DevotionalsListScreen> createState() => _DevotionalsListScreenState();
}

class _DevotionalsListScreenState extends ConsumerState<DevotionalsListScreen> {
  @override
  Widget build(BuildContext context) {
    final devotionalsAsync = ref.watch(widget.fromDashboard ? allDevotionalsIncludingDraftsProvider : allDevotionalsProvider);
    final canPop = Navigator.of(context).canPop();

    final scaffold = Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        centerTitle: false,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () {
              if (canPop) {
                Navigator.of(context).pop();
              } else if (widget.fromDashboard) {
                context.go('/dashboard');
              } else {
                context.go('/home?tab=devotionals');
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4, right: 12),
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
          if (widget.fromDashboard) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  sliver: SliverList.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DevotionalFeedCard(
                        devotional: sorted[index],
                        isManagementMode: widget.fromDashboard,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_pagePadding, _pagePadding, _pagePadding, _gapLg),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxFeedWidth),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final savedDevotionalsAsync = ref.watch(savedDevotionalsProvider);
                          return savedDevotionalsAsync.when(
                            data: (saved) => SavedDevotionalsCTA(
                              onTap: () => context.push('/devotionals/saved'),
                              count: saved.length,
                            ),
                            loading: () => SavedDevotionalsCTA(
                              onTap: () => context.push('/devotionals/saved'),
                            ),
                            error: (_, __) => SavedDevotionalsCTA(
                              onTap: () => context.push('/devotionals/saved'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_pagePadding, 0, _pagePadding, _pagePadding),
                sliver: SliverList.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: _gapLg),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxFeedWidth),
                        child: DevotionalFeedCard(devotional: sorted[index]),
                      ),
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

class SavedDevotionalsCTA extends StatelessWidget {
  final VoidCallback? onTap;
  final int? count;
  const SavedDevotionalsCTA({super.key, this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCount = (count ?? 0) > 0;
    final label = hasCount ? 'Devocionais Salvos ($count)' : 'Devocionais Salvos';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Ink(
          decoration: _surfaceCardDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(_cardPadding),
            child: Row(
              children: [
                _SoftIcon(
                  icon: Icons.bookmark,
                  iconColor: cs.primary,
                  backgroundColor: cs.primary.withValues(alpha: 0.10),
                  borderColor: cs.primary.withValues(alpha: 0.18),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: Text(
                    label,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavedDevotionalsCountCard extends StatelessWidget {
  final int? count;
  const SavedDevotionalsCountCard({super.key, this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCount = (count ?? 0) > 0;
    final label = hasCount ? 'Devocionais salvos ($count)' : 'Devocionais salvos';
    return Container(
      decoration: _surfaceCardDecoration(context),
      padding: const EdgeInsets.all(_cardPadding),
      child: Row(
        children: [
          _SoftIcon(
            icon: Icons.bookmark,
            iconColor: cs.primary,
            backgroundColor: cs.primary.withValues(alpha: 0.10),
            borderColor: cs.primary.withValues(alpha: 0.18),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: Text(
              label,
              style: CommunityDesign.titleStyle(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final double size;
  final double iconSize;

  const _SoftIcon({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    this.size = 36,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
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
              SavedDevotionalsCountCard(count: count),
              const SizedBox(height: 16),
              ...devotionals
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DevotionalFeedCard(devotional: d),
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
class DevotionalFeedCard extends ConsumerStatefulWidget {
  final Devotional devotional;
  final bool isManagementMode;

  const DevotionalFeedCard({
    super.key,
    required this.devotional,
    this.isManagementMode = false,
  });

  @override
  ConsumerState<DevotionalFeedCard> createState() => _DevotionalFeedCardState();
}

class _DevotionalFeedCardState extends ConsumerState<DevotionalFeedCard>
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
  void didUpdateWidget(covariant DevotionalFeedCard oldWidget) {
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
    final isSaved = _savedOverride ?? devotional.isSavedByMe;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final neutralFill = muted.withValues(alpha: 0.10);
    final neutralBorder = muted.withValues(alpha: 0.18);
    final activeFill = cs.primary.withValues(alpha: 0.12);
    final activeBorder = cs.primary.withValues(alpha: 0.24);
    String? imageUrl;
    if (widget.isManagementMode) {
      if (devotional.imageUrl != null) {
        imageUrl = devotional.imageUrl;
      } else if (devotional.hasYoutubeVideo && devotional.youtubeUrl != null) {
        final id = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
        imageUrl = id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null;
      }
    }

    Widget buildStatusPill({
      required String label,
      required Color color,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildActionCircle({
      required Widget child,
      required Color fillColor,
      required Color borderColor,
    }) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Center(child: child),
      );
    }

    Widget buildIconAction({
      required VoidCallback? onTap,
      required IconData icon,
      required Color iconColor,
      required Color fillColor,
      required Color borderColor,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: buildActionCircle(
              child: Icon(icon, size: 18, color: iconColor),
              fillColor: fillColor,
              borderColor: borderColor,
            ),
          ),
        ),
      );
    }

    final statusPills = <Widget>[
      if (widget.isManagementMode && !devotional.isPublished)
        buildStatusPill(label: 'RASCUNHO', color: Colors.orange),
      if (isSaved)
        buildStatusPill(
          label: 'SALVO',
          color: cs.primary,
          icon: Icons.bookmark,
        ),
    ];

    final myReaction = _reactionOverride ?? devotional.myReaction;
    final likesCount = _likesOverride ?? devotional.likesCount;
    final isLiked = myReaction != null;
    final contentPadding = EdgeInsets.fromLTRB(
      _cardPadding,
      imageUrl != null ? 0 : _cardPadding,
      _cardPadding,
      _cardPadding,
    );

    return InkWell(
      onTap: widget.isManagementMode
          ? () => context.push('/devotionals/${devotional.id}/edit')
          : () => context.push('/devotionals/${devotional.id}'),
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        decoration: _surfaceCardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isManagementMode && imageUrl != null) ...[
                ChurchImage(imageUrl: imageUrl, type: ChurchImageType.card),
                const SizedBox(height: _gap),
              ],
              Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SoftIcon(
                          icon: Icons.schedule,
                          iconColor: muted,
                          backgroundColor: muted.withValues(alpha: 0.10),
                          borderColor: muted.withValues(alpha: 0.18),
                          size: 30,
                          iconSize: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            devotional.formattedDate,
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ),
                        if (statusPills.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 6,
                              children: statusPills,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: _gap),
                    Text(
                      devotional.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (devotional.scriptureReference != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.menu_book, size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              devotional.scriptureReference!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.isManagementMode &&
                        (devotional.category != null || devotional.preacher != null || devotional.hasYoutubeVideo)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (devotional.category != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category, size: 14, color: muted),
                                const SizedBox(width: 4),
                                Text(devotional.categoryText, style: CommunityDesign.metaStyle(context)),
                              ],
                            ),
                          if (devotional.preacher != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 14, color: muted),
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
                    const SizedBox(height: _gap),
                    Text(
                      devotional.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.contentStyle(context).copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: _gap),
                    Divider(color: cs.outline.withValues(alpha: 0.12)),
                    const SizedBox(height: _gap),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedScale(
                              scale: _likePulse ? 1.03 : 1,
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOut,
                              child: CompositedTransformTarget(
                                link: _reactionLink,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isTogglingLike
                                        ? null
                                        : () async {
                                            final picked = await _showReactionPicker(
                                              context,
                                              myReaction,
                                            );
                                            if (!mounted || picked == null) {
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
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Row(
                                        key: _reactionTargetKey,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          buildActionCircle(
                                            fillColor: isLiked ? activeFill : neutralFill,
                                            borderColor: isLiked ? activeBorder : neutralBorder,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 160),
                                              switchInCurve: Curves.easeOutBack,
                                              switchOutCurve: Curves.easeIn,
                                              transitionBuilder: (child, anim) => ScaleTransition(
                                                scale: anim,
                                                child: child,
                                              ),
                                              child: isLiked
                                                  ? Text(
                                                      _reactionEmoji(myReaction),
                                                      key: ValueKey<String?>(myReaction),
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontFamilyFallback: _emojiFallback,
                                                        height: 1,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.volunteer_activism_outlined,
                                                      key: const ValueKey<String>('none'),
                                                      size: 18,
                                                      color: muted,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$likesCount',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: buildIconAction(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) => _DevotionalCommentsSheet(
                                    devotionalId: devotional.id,
                                  ),
                                );
                              },
                              icon: Icons.mode_comment_outlined,
                              iconColor: muted,
                              fillColor: neutralFill,
                              borderColor: neutralBorder,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: buildIconAction(
                              onTap: _isTogglingSave
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
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
                                              savedNow ? 'Salvo para ler depois' : 'Removido dos salvos',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setState(() => _savedOverride = isSaved);
                                        messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isTogglingSave = false);
                                        }
                                      }
                                    },
                              icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                              iconColor: isSaved ? cs.primary : muted,
                              fillColor: isSaved ? activeFill : neutralFill,
                              borderColor: isSaved ? activeBorder : neutralBorder,
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
