import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/church_image.dart';
import '../widgets/app_logo.dart';
import '../../features/permissions/presentation/widgets/dashboard_access_gate.dart';

import '../../features/bible/presentation/screens/bible_books_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/events/domain/models/event.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/events/presentation/providers/events_provider.dart';
import '../../features/devotionals/presentation/providers/devotional_provider.dart';
import '../../features/courses/presentation/providers/courses_provider.dart';
import '../../features/church_info/domain/models/church_info.dart';
import '../../features/church_info/presentation/providers/church_info_provider.dart';
import '../../features/home_content/presentation/providers/banners_provider.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/study_groups/domain/models/study_group.dart';
import '../../features/study_groups/presentation/providers/study_group_provider.dart';
import '../../features/contribution/presentation/screens/contribution_info_screen.dart';
import '../design/community_design.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../../features/home/presentation/widgets/home_content_card.dart';
import '../../features/home/presentation/widgets/home_section_widget.dart';
import '../utils/app_exit.dart';

/// Tela principal do app com navegação por abas fixas
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // Inicia na Home
  bool _initializedFromQuery = false;
  bool _syncedDefaultTabToUrl = false;

  String _tabParamForIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'bible';
      case 2:
        return 'church';
      case 3:
        return 'courses';
      case 4:
        return 'more';
      default:
        return 'home';
    }
  }

  int _indexForTabParam(String? tab) {
    switch (tab) {
      case 'home':
        return 0;
      case 'bible':
        return 1;
      case 'church':
        return 2;
      case 'courses':
        return 3;
      case 'more':
        return 4;
      default:
        return 0;
    }
  }

  void _syncUrlToSelectedIndex() {
    final uri = GoRouterState.of(context).uri;
    final tab = uri.queryParameters['tab'];
    final desiredTab = _tabParamForIndex(_selectedIndex);
    if (uri.path == '/home' && tab != desiredTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/home?tab=$desiredTab');
      });
    }
  }

  List<PremiumNavItem> _buildNavItems(String? avatarUrl) {
    return [
      const PremiumNavItem(
        label: 'Home',
        icon: Icons.home_rounded,
        activeColor: Color(0xFF2F80ED),
      ),
      PremiumNavItem(
        label: 'Bíblia',
        activeColor: const Color(0xFF9B51E0),
        iconBuilder: (context, isActive, activeColor) {
          return Transform.translate(
            offset: const Offset(0, -1),
            child: Icon(
              Icons.menu_book_rounded,
              size: 26,
              color: isActive ? activeColor : Colors.grey.shade500,
            ),
          );
        },
      ),
      PremiumNavItem(
        label: 'Igreja',
        activeColor: const Color(0xFF1F3C88),
        iconBuilder: (context, isActive, activeColor) {
          return _NavLogoIcon(isActive: isActive);
        },
      ),
      const PremiumNavItem(
        label: 'Cursos',
        icon: Icons.school_rounded,
        activeColor: Color(0xFF27AE60),
      ),
      PremiumNavItem(
        label: 'Mais',
        activeColor: const Color(0xFFF2994A),
        iconBuilder: (context, isActive, activeColor) {
          return _NavAvatarIcon(
            photoUrl: avatarUrl,
            isActive: isActive,
            activeColor: activeColor,
          );
        },
      ),
    ];
  }

  // Abas fixas do app
  List<Widget> get _screens => [
    const _DashboardTab(), // Home (Mural)
    const BibleBooksScreen(), // Bíblia
    const _ChurchHomeTab(), // Home Institucional
    const CoursesListScreen(), // Cursos
    const _MoreTab(), // Mais (Menu)
  ];

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(currentMemberProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = memberAsync.maybeWhen(
      data: (member) => member?.photoUrl ?? user?.userMetadata?['avatar_url'],
      orElse: () => user?.userMetadata?['avatar_url'],
    );
    final navItems = _buildNavItems(avatarUrl);

    if (!_initializedFromQuery) {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      _selectedIndex = _indexForTabParam(tab);
      _initializedFromQuery = true;
    }
    final tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tabParam == null && !_syncedDefaultTabToUrl) {
      _syncedDefaultTabToUrl = true;
      _syncUrlToSelectedIndex();
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          _syncUrlToSelectedIndex();
          return;
        }
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sair do aplicativo?'),
            content: const Text('Deseja realmente sair do Church 360?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ).then((confirm) async {
          if (confirm == true && context.mounted) {
            await exitApp(context);
          }
        });
      },
      child: Stack(
        children: [
          Scaffold(
            body: _screens[_selectedIndex],
            bottomNavigationBar: PremiumBottomNavBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                _syncUrlToSelectedIndex();
              },
              items: navItems,
            ),
          ),
        ],
      ),
    );
  }
}

const double _homePagePadding = 16;
const double _homeCardRadius = 16;
const double _homeCardPadding = 16;
const double _homeSectionGap = 12;

class _NavLogoIcon extends StatelessWidget {
  final bool isActive;

  const _NavLogoIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1 : 0.65,
      child: const AppLogo(
        width: 22,
        height: 22,
      ),
    );
  }
}

class _NavAvatarIcon extends StatelessWidget {
  final String? photoUrl;
  final bool isActive;
  final Color activeColor;

  const _NavAvatarIcon({
    required this.photoUrl,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            : Container(
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

/// Tab Home - Mural do app com eventos, cultos e informações úteis
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchInfoAsync = ref.watch(churchInfoProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
            child: Padding(
            padding: const EdgeInsets.only(bottom: 120), // Espaço para Navigation Bar e FAB/bolha
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Slider de banners (cabeçalho da Home)
                const _HomeBannerSlider(),

                const SizedBox(height: _homeSectionGap),

                // CTA: Comunidade
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _homePagePadding),
                  child: const _CommunityCtaCard(),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _homePagePadding),
                  child: _HomeSocialShortcuts(info: churchInfoAsync),
                ),

                // Card: Para sua edificação
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _homePagePadding),
                  child: const _EdificationCard(),
                ),

                const SizedBox(height: _homeSectionGap),

                // Cursos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _homePagePadding),
                  child: const _HomeCoursesSection(),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Slider de banners (cabeçalho da Home)
// =====================================================

class _HomeBannerSlider extends ConsumerStatefulWidget {
  const _HomeBannerSlider();

  @override
  ConsumerState<_HomeBannerSlider> createState() => _HomeBannerSliderState();
}

class _HomeBannerSliderState extends ConsumerState<_HomeBannerSlider> {
  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;
  int _currentPage = 0;
  int _totalPages = 0;

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link')),
      );
    }
  }

  Future<void> _handleBannerTap(
    BuildContext context,
    _HomeBannerSlideItem slide,
  ) async {
    final linkType = (slide.linkType ?? '').trim();
    final linkedId = (slide.linkedId ?? '').trim();
    final linkUrl = (slide.linkUrl ?? '').trim();

    if (linkType == 'event') {
      if (linkedId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento não configurado')),
        );
        return;
      }
      context.push('/events/$linkedId');
      return;
    }

    if (linkType == 'reading_plan') {
      if (linkedId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plano de leitura não configurado')),
        );
        return;
      }
      context.push('/reading-plans/$linkedId');
      return;
    }

    if (linkType == 'course') {
      if (linkedId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Curso não configurado')),
        );
        return;
      }
      context.push('/courses/$linkedId/view');
      return;
    }

    if (linkType == 'external' || linkUrl.isNotEmpty) {
      if (linkUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link não configurado')),
        );
        return;
      }
      await _openExternalLink(context, linkUrl);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ação do banner não configurada')),
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_totalPages <= 1) return;

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_currentPage + 1) % _totalPages;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersStreamProvider);
    final width = MediaQuery.sizeOf(context).width - (_homePagePadding * 2);
    final height = (width * 9 / 16).clamp(170, 200).toDouble();

    Widget buildCarousel(List<_HomeBannerSlideItem> slides) {
      if (_totalPages != slides.length) {
        _totalPages = slides.length;
        WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoPlay());
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _homePagePadding),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return _HomeBannerSlideCard(
                    title: slide.title,
                    subtitle: slide.subtitle,
                    imageUrl: slide.imageUrl,
                    onTap: slide.hasAction ? () => _handleBannerTap(context, slide) : null,
                  );
                },
              ),
              if (slides.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 20 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return bannersAsync.when(
      data: (banners) {
        final sorted = [...banners]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final slides = sorted.isEmpty
            ? _fallbackBannerSlides
            : sorted.map((banner) {
                final subtitle = banner.description?.trim();
                return _HomeBannerSlideItem(
                  title: banner.title,
                  subtitle: subtitle != null && subtitle.isNotEmpty ? subtitle : null,
                  imageUrl: banner.imageUrl,
                  linkType: banner.linkType,
                  linkUrl: banner.linkUrl,
                  linkedId: banner.linkedId,
                );
              }).toList();

        return buildCarousel(slides);
      },
      loading: () => buildCarousel(_fallbackBannerSlides),
      error: (_, __) => buildCarousel(_fallbackBannerSlides),
    );
  }
}

class _HomeBannerSlideItem {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkType;
  final String? linkUrl;
  final String? linkedId;

  const _HomeBannerSlideItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.linkType,
    this.linkUrl,
    this.linkedId,
  });

  bool get hasAction {
    final lt = (linkType ?? '').trim();
    final url = (linkUrl ?? '').trim();
    final id = (linkedId ?? '').trim();
    if (lt == 'external') return url.isNotEmpty;
    if (lt == 'event' || lt == 'reading_plan' || lt == 'course') return id.isNotEmpty;
    return url.isNotEmpty;
  }
}

const List<_HomeBannerSlideItem> _fallbackBannerSlides = [
  _HomeBannerSlideItem(
    title: 'Banner 1',
    subtitle: 'Atualizações e avisos da igreja',
  ),
  _HomeBannerSlideItem(
    title: 'Banner 2',
    subtitle: 'Fique por dentro das novidades',
  ),
  _HomeBannerSlideItem(
    title: 'Banner 3',
    subtitle: 'Eventos e comunicados recentes',
  ),
];

class _HomeBannerSlideCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _HomeBannerSlideCard({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_homeCardRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.article_outlined,
                      color: cs.onSurfaceVariant,
                      size: 32,
                    ),
                  ),
                )
              else
                Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.article_outlined,
                    color: cs.onSurfaceVariant,
                    size: 32,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
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
}

// =====================================================
// WIDGET: CTA Comunidade
// =====================================================

class _CommunityCtaCard extends StatelessWidget {
  const _CommunityCtaCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    void openContribution() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ContributionInfoScreen(),
        ),
      );
    }
    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_homeCardRadius),
          onTap: () => context.push('/community'),
          child: Padding(
            padding: const EdgeInsets.all(_homeCardPadding),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_outlined,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comunidade',
                              style: CommunityDesign.titleStyle(context).copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Conecte-se, compartilhe pedidos de oração e testemunhos.',
                              style: CommunityDesign.metaStyle(context).copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ContributePillButton(onTap: openContribution),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributePillButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContributePillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFE7F6EC);
    const fgColor = Color(0xFF1E7A3E);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: fgColor.withValues(alpha: 0.12),
        hoverColor: fgColor.withValues(alpha: 0.08),
        child: SizedBox(
          width: 84,
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.volunteer_activism,
                size: 20,
                color: fgColor,
              ),
              const SizedBox(height: 6),
              Text(
                'Contribua',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSocialShortcuts extends StatelessWidget {
  final AsyncValue<ChurchInfo?> info;

  const _HomeSocialShortcuts({required this.info});

  @override
  Widget build(BuildContext context) {
    return info.when(
      data: (churchInfo) {
        final social = churchInfo?.socialMedia;
        if (social == null || social.isEmpty) {
          return const SizedBox(height: _homeSectionGap);
        }

        final items = _buildItems(social);
        if (items.isEmpty) {
          return const SizedBox(height: _homeSectionGap);
        }

        return Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: items
                  .map((item) => Expanded(child: _SocialShortcutButton(item: item)))
                  .toList(),
            ),
            const SizedBox(height: _homeSectionGap),
          ],
        );
      },
      loading: () => const SizedBox(height: _homeSectionGap),
      error: (_, __) => const SizedBox(height: _homeSectionGap),
    );
  }

  List<_SocialShortcutItem> _buildItems(Map<String, String> social) {
    final slots = <String, _SocialShortcutItem>{};

    void putIfMatch({
      required String key,
      required String label,
      required IconData icon,
      required Color color,
      required String url,
    }) {
      if (!slots.containsKey(key)) {
        slots[key] = _SocialShortcutItem(
          label: label,
          icon: icon,
          color: color,
          url: url,
        );
      }
    }

    for (final entry in social.entries) {
      final rawKey = entry.key.toLowerCase();
      final url = entry.value.trim();
      if (url.isEmpty) continue;

      if (rawKey.contains('whatsapp')) {
        putIfMatch(
          key: 'whatsapp',
          label: 'WhatsApp',
          icon: FontAwesomeIcons.whatsapp,
          color: const Color(0xFF25D366),
          url: url,
        );
      } else if (rawKey.contains('youtube')) {
        putIfMatch(
          key: 'youtube',
          label: 'YouTube',
          icon: FontAwesomeIcons.youtube,
          color: const Color(0xFFFF0000),
          url: url,
        );
      } else if (rawKey.contains('instagram')) {
        putIfMatch(
          key: 'instagram',
          label: 'Instagram',
          icon: FontAwesomeIcons.instagram,
          color: const Color(0xFFE4405F),
          url: url,
        );
      } else if (rawKey.contains('facebook')) {
        putIfMatch(
          key: 'facebook',
          label: 'Facebook',
          icon: FontAwesomeIcons.facebook,
          color: const Color(0xFF1877F2),
          url: url,
        );
      }
    }

    return [
      slots['whatsapp'],
      slots['youtube'],
      slots['instagram'],
      slots['facebook'],
    ].whereType<_SocialShortcutItem>().toList();
  }
}

class _SocialShortcutItem {
  final String label;
  final IconData icon;
  final Color color;
  final String url;

  const _SocialShortcutItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.url,
  });
}

class _SocialShortcutButton extends StatelessWidget {
  final _SocialShortcutItem item;

  const _SocialShortcutButton({required this.item});

  String _normalizeUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    final lower = v.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('tel:') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('whatsapp:')) {
      return v;
    }
    return 'https://$v';
  }

  Uri? _buildWhatsAppUri(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();

    if (lower.startsWith('whatsapp:')) {
      return Uri.parse(v);
    }

    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('wa.me/') ||
        lower.startsWith('www.wa.me/') ||
        lower.startsWith('api.whatsapp.com') ||
        lower.startsWith('www.api.whatsapp.com')) {
      return Uri.parse(_normalizeUrl(v));
    }

    var digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.isEmpty) return null;
    if (digits.length <= 11 && !digits.startsWith('55')) {
      digits = '55$digits';
    }

    if (kIsWeb) {
      return Uri.parse('https://wa.me/$digits');
    }
    return Uri.parse('whatsapp://send?phone=$digits');
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    Uri uri;
    if (item.label.toLowerCase().contains('whatsapp')) {
      final waUri = _buildWhatsAppUri(url);
      if (waUri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp não configurado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      uri = waUri;
    } else {
      uri = Uri.parse(_normalizeUrl(url));
    }

    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (item.label.toLowerCase().contains('whatsapp')) {
      var digits = url.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('00')) {
        digits = digits.substring(2);
      }
      if (digits.isNotEmpty && digits.length <= 11 && !digits.startsWith('55')) {
        digits = '55$digits';
      }
      if (digits.isNotEmpty) {
        final fallback = Uri.parse('https://wa.me/$digits');
        if (await canLaunchUrl(fallback)) {
          await launchUrl(fallback, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir o link'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(context, item.url),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: CommunityDesign.metaStyle(context).copyWith(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Seção Cursos
// =====================================================

class _HomeCoursesSection extends ConsumerWidget {
  const _HomeCoursesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(activeCoursesProvider);

    return coursesAsync.when(
      data: (courses) {
        if (courses.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = courses.take(4).toList();

        return _HomeSectionCard(
          title: 'Cursos',
          actionLabel: 'VER TODOS',
          onAction: () => context.push('/courses'),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: _homeGridAspectRatio(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final course = items[index];
              return HomeContentCard(
                thumbnail: course.imageUrl != null
                    ? ChurchImage(
                        imageUrl: course.imageUrl!,
                        type: ChurchImageType.hero,
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.school_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                title: course.title,
                onTap: () => context.push('/courses/${course.id}/view'),
              );
            },
          ),
        );
      },
      loading: () => const _HomeSectionSkeleton(title: 'Cursos'),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _HomeSectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(_homeCardPadding),
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HomeSectionSkeleton extends StatelessWidget {
  final String title;

  const _HomeSectionSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(_homeCardPadding),
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Carregando $title...',
              style: CommunityDesign.metaStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

double _homeGridAspectRatio(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w <= 360) return 0.95;
  if (w <= 420) return 1.02;
  return 1.1;
}

// =====================================================
// =====================================================

/// Tab "Mais" - Menu com todas as opções (versão mobile)
class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        toolbarHeight: 64,
        titleSpacing: 0, // Alinhamento estrito
        title: Padding(
          padding: const EdgeInsets.only(left: _homePagePadding),
          child: currentMemberAsync.when(
            data: (member) {
              final user = Supabase.instance.client.auth.currentUser;
              final fullName =
                  member?.fullName ??
                  user?.email?.split('@').first ??
                  'Usuário';
              // Tenta pegar o primeiro nome ou apelido
              final displayName =
                  (member?.nickname != null && member!.nickname!.isNotEmpty)
                  ? member.nickname!
                  : fullName.split(' ').first;

              final photoUrl =
                  member?.photoUrl ?? user?.userMetadata?['avatar_url'];

              return Row(
                children: [
                  // Avatar com borda
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 22,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName, // Apelido ou Primeiro Nome em destaque
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 16, height: 1.1, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        fullName, // Nome completo menor
                        style: CommunityDesign.metaStyle(
                          context,
                        ).copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carregando...',
                      style: CommunityDesign.titleStyle(context),
                    ),
                  ],
                ),
              ],
            ),
            error: (_, __) =>
                Text('Menu', style: CommunityDesign.titleStyle(context)),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: NotificationBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: _homePagePadding, vertical: 20),
        children: [
          // VISÃO GERAL
          _buildSectionTitle(context, 'VISÃO GERAL'),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.person_outline,
            'Ver meu perfil',
            '/profile',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          ConditionalDashboardAccess(
            builder: (context, canAccess) {
              if (!canAccess) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMenuCard(
                    context,
                    Icons.dashboard_outlined,
                    'Liderança',
                    '/dashboard',
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          _buildMenuCard(
            context,
            Icons.child_care_outlined,
            'Inscrição Kids',
            '/kids-registration',
            color: Colors.pink,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.church_outlined,
            'A Igreja',
            '/church-info',
            color: Colors.purple,
          ),

          const SizedBox(height: 32),

          // Logout Button
          Container(
            decoration: CommunityDesign.overlayDecoration(
              Theme.of(context).colorScheme,
            ).copyWith(
              borderRadius: BorderRadius.circular(_homeCardRadius),
            ),
            child: ListTile(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmar Saída'),
                    content: const Text('Deseja realmente sair do aplicativo?'),
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
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await signOutAndExit(context);
                }
              },
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Sair do aplicativo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.red,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Version
          Text(
            'Church 360 v1.0.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 48), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final itemColor = color ?? cs.primary;

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_homeCardRadius),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Ícone Colorido
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: itemColor, size: 20),
                ),
                const SizedBox(width: 16),
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                // Seta
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Home Institucional (Igreja)
// =====================================================

class _ChurchHomeTab extends ConsumerWidget {
  const _ChurchHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final newsAsync = ref.watch(allEventsProvider);
    final churchInfoAsync = ref.watch(churchInfoProvider);
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(_homePagePadding, 16, _homePagePadding, 120),
          children: [
            _ChurchIdentityHeader(info: churchInfoAsync),
            const SizedBox(height: _homeSectionGap),
            _ChurchDateHeader(
              date: today,
              subtitle: 'Agenda da igreja para hoje',
            ),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (events) {
                final todayEvents =
                    events.where((event) => _isSameDay(event.startDate, today)).toList();

                if (todayEvents.isEmpty) {
                  return _ChurchEmptyState(
                    icon: Icons.event_busy_outlined,
                    message: 'Nenhum evento marcado para hoje.',
                  );
                }

                return Column(
                  children: todayEvents.map((event) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChurchAgendaItem(event: event),
                    );
                  }).toList(),
                );
              },
              loading: () => _ChurchLoadingCard(
                label: 'Carregando eventos',
              ),
              error: (_, __) => _ChurchEmptyState(
                icon: Icons.warning_amber,
                message: 'Não foi possível carregar os eventos.',
                color: cs.error,
              ),
            ),
            const SizedBox(height: 20),
            _ChurchSectionHeader(
              title: 'Notícias',
              subtitle: 'Atualizações e avisos recentes',
              icon: Icons.article_outlined,
            ),
            const SizedBox(height: 12),
            newsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return _ChurchEmptyState(
                    icon: Icons.article_outlined,
                    message: 'Nenhuma notícia no momento.',
                  );
                }

                final sorted = [...events]..sort((a, b) => b.startDate.compareTo(a.startDate));

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ChurchNewsCard(event: sorted[index]);
                  },
                );
              },
              loading: () => _ChurchLoadingCard(
                label: 'Carregando notícias',
              ),
              error: (_, __) => _ChurchEmptyState(
                icon: Icons.warning_amber,
                message: 'Não foi possível carregar as notícias.',
                color: cs.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChurchIdentityHeader extends StatelessWidget {
  final AsyncValue<ChurchInfo?> info;

  const _ChurchIdentityHeader({required this.info});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return info.when(
      data: (churchInfo) {
        final name = (churchInfo?.name ?? 'Igreja').trim();
        final headline = (churchInfo?.mission ?? '').trim();
        final showSubtitle = headline.isNotEmpty;
        final logoUrl = churchInfo?.logoUrl;
        const double avatarSize = 50;
        const double ringPadding = 1;
        const double ringWidth = 2;
        final ringColor = cs.primary.withValues(alpha: 0.35);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/church-info'),
                  child: Container(
                    padding: const EdgeInsets.all(ringPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: ringWidth),
                    ),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceContainerHighest,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: ClipOval(
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const AppLogo(),
                              )
                            : const AppLogo(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showSubtitle ? headline : name,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: CommunityDesign.metaStyle(context).copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      error: (_, __) => Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
            ),
            child: const AppLogo(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Igreja',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchDateHeader extends StatelessWidget {
  final DateTime date;
  final String subtitle;

  const _ChurchDateHeader({
    required this.date,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final day = date.day.toString();
    final month = _monthName(date.month);
    final weekday = _weekdayName(date.weekday);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(_homeCardRadius),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            day,
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                month,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hoje, $weekday',
                style: CommunityDesign.metaStyle(context).copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: CommunityDesign.metaStyle(context).copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push('/schedule'),
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Agenda',
        ),
      ],
    );
  }
}

class _ChurchSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ChurchSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: CommunityDesign.metaStyle(context).copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChurchAgendaItem extends StatelessWidget {
  final Event event;

  const _ChurchAgendaItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = DateFormat('HH:mm', 'pt_BR').format(event.startDate);
    final end = event.endDate != null ? DateFormat('HH:mm', 'pt_BR').format(event.endDate!) : null;

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  start,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (end != null)
                  Text(
                    end,
                    style: CommunityDesign.metaStyle(context).copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.location!,
                    style: CommunityDesign.metaStyle(context).copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchNewsCard extends StatelessWidget {
  final Event event;

  const _ChurchNewsCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('dd/MM/yyyy', 'pt_BR').format(event.startDate);

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_homeCardRadius),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(eventId: event.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: event.imageUrl != null
                        ? Image.network(
                            event.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.article_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.article_outlined,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: CommunityDesign.titleStyle(context).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.description != null && event.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          style: CommunityDesign.metaStyle(context).copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        date,
                        style: CommunityDesign.metaStyle(context).copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChurchEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _ChurchEmptyState({
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedColor = color ?? cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: resolvedColor.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: CommunityDesign.metaStyle(context).copyWith(
                color: resolvedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchLoadingCard extends StatelessWidget {
  final String label;

  const _ChurchLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(_homeCardRadius),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: CommunityDesign.metaStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> _ptMonths = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> _ptWeekdays = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

String _monthName(int month) => _ptMonths[(month - 1).clamp(0, 11)];

String _weekdayName(int weekday) => _ptWeekdays[(weekday - 1).clamp(0, 6)];

class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({super.key});

  @override
  ConsumerState<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends ConsumerState<MyJourneyScreen> {
  int _visibleCount = 25;

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedDevotionalsProvider);
    final streakAsync = ref.watch(currentUserReadingStreakProvider);
    final totalAsync = ref.watch(currentUserTotalReadingsProvider);
    final memberAsync = ref.watch(currentMemberProvider);
    final readingsAsync = ref.watch(currentUserReadingsWithDevotionalProvider);
    final coursesAsync = ref.watch(currentUserCourseEnrollmentsProvider);
    final groupsAsync = ref.watch(currentUserStudyGroupsProvider);
    final cs = Theme.of(context).colorScheme;

    final bool isLoading =
        memberAsync.isLoading || readingsAsync.isLoading || coursesAsync.isLoading || groupsAsync.isLoading;
    final Object? anyError = memberAsync.error ?? readingsAsync.error ?? coursesAsync.error ?? groupsAsync.error;

    final memberId = memberAsync.value?.id;
    final readings = readingsAsync.value ?? const <Map<String, dynamic>>[];
    final enrollments = coursesAsync.value ?? const <Map<String, dynamic>>[];
    final groups = groupsAsync.value ?? const <StudyGroup>[];

    final events = anyError == null && !isLoading
        ? _JourneyEvent.merge(
            memberId: memberId,
            readings: readings,
            enrollments: enrollments,
            studyGroups: groups,
          )
        : const <_JourneyEvent>[];

    final shown = events.length <= _visibleCount ? events : events.take(_visibleCount).toList(growable: false);
    final canShowMore = events.length > shown.length;

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
                border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.timeline_outlined, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Minha Caminhada',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          _homePagePadding,
          _homePagePadding,
          _homePagePadding,
          120,
        ),
        children: [
          Container(
            decoration: CommunityDesign.overlayDecoration(cs),
            padding: const EdgeInsets.all(_homeCardPadding),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.volunteer_activism, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sua jornada espiritual vai ficando registrada aqui.',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _homeSectionGap),
          Wrap(
            spacing: _homeSectionGap,
            runSpacing: _homeSectionGap,
            children: [
              _JourneyStatCard(
                title: 'Devocionais salvos',
                icon: Icons.bookmark_outline,
                value: savedAsync.when(
                  data: (items) => '${items.length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                onTap: () => context.push('/devotionals/saved'),
              ),
              _JourneyStatCard(
                title: 'Sequência',
                icon: Icons.local_fire_department_outlined,
                value: streakAsync.when(
                  data: (value) => '$value',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
              ),
              _JourneyStatCard(
                title: 'Leituras',
                icon: Icons.check_circle_outline,
                value: totalAsync.when(
                  data: (value) => '$value',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: _homeSectionGap),
          Container(
            decoration: CommunityDesign.overlayDecoration(cs),
            padding: const EdgeInsets.all(_homeCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Linha do tempo',
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (anyError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Não foi possível carregar sua caminhada agora.',
                      style: CommunityDesign.metaStyle(context).copyWith(color: cs.error),
                    ),
                  )
                else if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Quando você ler devocionais, iniciar cursos ou entrar em grupos, isso aparece aqui.',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final event = shown[index];
                      final prev = index > 0 ? shown[index - 1] : null;
                      final showMonthHeader = prev == null || !_sameMonth(event.when, prev.when);
                      final isLast = index == shown.length - 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showMonthHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                              child: Text(
                                _formatMonthYear(event.when),
                                style: CommunityDesign.metaStyle(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          _JourneyTimelineItem(
                            event: event,
                            isLast: isLast,
                            onTap: event.route == null
                                ? null
                                : () {
                                    context.push(event.route!);
                                  },
                          ),
                        ],
                      );
                    },
                  ),
                if (!isLoading && anyError == null && canShowMore) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _visibleCount = (_visibleCount + 25).clamp(25, events.length).toInt();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Ver toda minha jornada',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _JourneyEventKind {
  devotional,
  course,
  studyGroup,
}

class _JourneyEvent {
  final DateTime when;
  final _JourneyEventKind kind;
  final String title;
  final String subtitle;
  final String? route;
  final IconData icon;
  final bool isPinned;

  const _JourneyEvent({
    required this.when,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.isPinned,
  });

  static List<_JourneyEvent> merge({
    required String? memberId,
    required List<Map<String, dynamic>> readings,
    required List<Map<String, dynamic>> enrollments,
    required List<StudyGroup> studyGroups,
  }) {
    final items = <_JourneyEvent>[
      ...readings.map(_JourneyEvent._fromReading),
      ...enrollments.map(_JourneyEvent._fromEnrollment),
      ...studyGroups.map((g) => _JourneyEvent._fromStudyGroup(g, memberId: memberId)),
    ];

    items.sort((a, b) => b.when.compareTo(a.when));
    return items;
  }

  static _JourneyEvent _fromReading(Map<String, dynamic> row) {
    final readAt = _parseDateTime(row['read_at']) ?? _parseDateTime(row['created_at']) ?? DateTime.now();
    final devotionalId = row['devotional_id']?.toString();
    final devotional = row['devotionals'];
    final devotionalTitle = devotional is Map ? (devotional['title']?.toString().trim() ?? '') : '';
    final title = devotionalTitle.isNotEmpty ? devotionalTitle : 'Devocional';
    final notes = row['notes']?.toString().trim() ?? '';

    return _JourneyEvent(
      when: readAt,
      kind: _JourneyEventKind.devotional,
      title: 'Leu devocional',
      subtitle: title,
      route: devotionalId == null ? null : '/devotionals/$devotionalId',
      icon: Icons.menu_book_outlined,
      isPinned: notes.isNotEmpty,
    );
  }

  static _JourneyEvent _fromEnrollment(Map<String, dynamic> row) {
    final enrolledAt = _parseDateTime(row['enrolled_at']) ?? DateTime.now();
    final course = row['course'];
    final courseId = row['course_id']?.toString();
    final courseTitle = course is Map ? (course['title']?.toString().trim() ?? '') : '';
    final status = row['status']?.toString().trim().toLowerCase();
    final progress = row['progress'];
    final endDate = course is Map ? _parseDateTime(course['end_date']) : null;
    final isCompleted = status == 'completed' || (progress is num && progress >= 100);

    return _JourneyEvent(
      when: isCompleted ? (endDate ?? enrolledAt) : enrolledAt,
      kind: _JourneyEventKind.course,
      title: isCompleted ? 'Concluiu curso' : 'Iniciou curso',
      subtitle: courseTitle.isNotEmpty ? courseTitle : 'Curso',
      route: courseId == null ? null : '/courses/$courseId/view',
      icon: Icons.school_outlined,
      isPinned: isCompleted,
    );
  }

  static _JourneyEvent _fromStudyGroup(StudyGroup group, {required String? memberId}) {
    final when = group.startDate;
    final topic = (group.studyTopic ?? '').trim();
    final subtitle = topic.isNotEmpty ? '${group.name} • $topic' : group.name;
    final isPinned = memberId != null && group.createdBy == memberId;

    return _JourneyEvent(
      when: when,
      kind: _JourneyEventKind.studyGroup,
      title: 'Participa do grupo de estudo',
      subtitle: subtitle,
      route: '/study-groups/${group.id}',
      icon: Icons.groups_2_outlined,
      isPinned: isPinned,
    );
  }
}

class _JourneyTimelineItem extends StatelessWidget {
  final _JourneyEvent event;
  final bool isLast;
  final VoidCallback? onTap;

  const _JourneyTimelineItem({
    required this.event,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final markerColor = cs.primary;
    final markerBg = cs.primary.withValues(alpha: 0.10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_homeCardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: markerBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
                      ),
                      child: Icon(
                        event.isPinned ? Icons.push_pin_outlined : event.icon,
                        size: 16,
                        color: markerColor,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: cs.outline.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: CommunityDesign.overlayDecoration(cs, hovered: true).copyWith(
                    borderRadius: BorderRadius.circular(_homeCardRadius),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: CommunityDesign.titleStyle(context).copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDay(event.when),
                            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle,
                        style: CommunityDesign.metaStyle(context).copyWith(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String _formatDay(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  return '$dd/$mm/$yyyy';
}

String _formatMonthYear(DateTime dt) {
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  final monthName = months[(dt.month - 1).clamp(0, 11).toInt()];
  return '$monthName ${dt.year}';
}

class _JourneyStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  const _JourneyStatCard({
    required this.title,
    required this.icon,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: Container(
        decoration: CommunityDesign.overlayDecoration(cs, hovered: true),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(CommunityDesign.radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card "Para sua edificação"
// =====================================================

class _EdificationCard extends ConsumerStatefulWidget {
  const _EdificationCard();

  @override
  ConsumerState<_EdificationCard> createState() => _EdificationCardState();
}

class _EdificationCardState extends ConsumerState<_EdificationCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final devotionalsAsync = ref.watch(allDevotionalsProvider);

    return devotionalsAsync.when(
      data: (devotionals) {
        if (devotionals.isEmpty) {
          return const SizedBox.shrink();
        }

        // Pegar até 4 devocionais mais recentes
        final recentDevotionals = devotionals.take(4).toList();

        final items = recentDevotionals.map((devotional) {
          // Determinar qual imagem usar (imageUrl ou thumbnail do YouTube)
          String? imageUrl = devotional.imageUrl;
          if (imageUrl == null && devotional.hasYoutubeVideo) {
            final videoId = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
            if (videoId != null) {
              imageUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
            }
          }

          return HomeContentCard(
            thumbnail: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  ChurchImage(
                    imageUrl: imageUrl,
                    type: ChurchImageType.card,
                  )
                else
                  Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                if (devotional.hasYoutubeVideo)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
            title: devotional.title,
            onTap: () {
              context.go('/devotionals/${devotional.id}');
            },
          );
        }).toList();

        return HomeSectionWidget(
          title: 'Para sua edificação',
          isExpanded: _isExpanded,
          onToggle: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          items: items,
          onSeeAll: () {
            context.push('/devotionals');
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// =====================================================
// WIDGET: Card "Fique por dentro"
// =====================================================

class _StayInformedCard extends ConsumerStatefulWidget {
  final void Function(int) onNavigateToTab;

  const _StayInformedCard({required this.onNavigateToTab});

  @override
  ConsumerState<_StayInformedCard> createState() => _StayInformedCardState();
}

class _StayInformedCardState extends ConsumerState<_StayInformedCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        // Pegar apenas os primeiros 4 eventos
        final displayEvents = events.take(4).toList();

        final items = displayEvents.map((event) {
          return HomeContentCard(
            thumbnail: Stack(
              fit: StackFit.expand,
              children: [
                if (event.imageUrl != null)
                  ChurchImage(
                    imageUrl: event.imageUrl!,
                    type: ChurchImageType.hero,
                  )
                else
                  Container(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.event,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 32,
                    ),
                  ),
                // Badge de data
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${event.startDate.day}/${event.startDate.month}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: event.name,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: event.id),
                ),
              );
            },
          );
        }).toList();

        return HomeSectionWidget(
          title: 'Fique por dentro',
          isExpanded: _isExpanded,
          onToggle: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          items: items,
          onSeeAll: () {
            widget.onNavigateToTab(1);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
