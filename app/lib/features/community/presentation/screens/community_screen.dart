import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/community_providers.dart';
import '../../../../core/design/community_design.dart';
import '../../domain/models/community_post.dart';
import '../../domain/models/classified.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _fabPressed = false;
  int? _pressedMobileTabIndex;
  late final AnimationController _fabBreathController;

  static const _muralBlue = Color(0xFF0B5FA5);
  static const _prayerGreen = Color(0xFF1D6E45);
  static const _classifiedOrange = Color(0xFF8A5B00);
  static const _membersSlate = Color(0xFF4E6B85);

  Color _tabAccentColorForIndex(int index) {
    switch (index) {
      case 0:
        return _muralBlue;
      case 1:
        return _prayerGreen;
      case 2:
        return _classifiedOrange;
      default:
        return _membersSlate;
    }
  }

  Color _tabActiveBackground(Color accent) => accent.withValues(alpha: 0.10);

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  ButtonStyle _pillTextButtonStyle({
    required Color foregroundColor,
    required Color overlayColor,
  }) {
    return ButtonStyle(
      shape: WidgetStateProperty.all(const StadiumBorder()),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      foregroundColor: WidgetStateProperty.all(foregroundColor),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return overlayColor;
        }
        return null;
      }),
      visualDensity: VisualDensity.compact,
    );
  }

  ButtonStyle _pillElevatedButtonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color overlayColor,
  }) {
    return ButtonStyle(
      shape: WidgetStateProperty.all(const StadiumBorder()),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 40)),
      backgroundColor: WidgetStateProperty.all(backgroundColor),
      foregroundColor: WidgetStateProperty.all(foregroundColor),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return overlayColor;
        }
        return null;
      }),
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  void initState() {
    super.initState();
    // 4 Tabs: Mural (Feed), Orações, Classificados, Membros
    _tabController = TabController(length: 4, vsync: this);
    _fabBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabBreathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Layout Check
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Builder(
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildDesktopLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    final theme = Theme.of(context);
    const inactiveTabText = Color(0xFF7A8A9A);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 60,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: const Color(0xFFF5F9FD),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: _handleBack,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.church_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Comunidade',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compartilhe, ore e participe',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildMobileSocialTab(
                        label: 'Mural',
                        index: 0,
                        accentColor: _tabAccentColorForIndex(0),
                        inactiveText: inactiveTabText,
                      ),
                      const SizedBox(width: 10),
                      _buildMobileSocialTab(
                        label: 'Orações',
                        index: 1,
                        accentColor: _tabAccentColorForIndex(1),
                        inactiveText: inactiveTabText,
                      ),
                      const SizedBox(width: 10),
                      _buildMobileSocialTab(
                        label: 'Classificados',
                        index: 2,
                        accentColor: _tabAccentColorForIndex(2),
                        inactiveText: inactiveTabText,
                      ),
                      const SizedBox(width: 10),
                      _buildMobileSocialTab(
                        label: 'Membros',
                        index: 3,
                        accentColor: _tabAccentColorForIndex(3),
                        inactiveText: inactiveTabText,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MuralTab(filterType: null), // Mix
          _MuralTab(filterType: 'prayer_request'), // Only Prayers
          _ClassifiedsTab(),
          _MembersTab(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildMobileSocialTab({
    required String label,
    required int index,
    required Color accentColor,
    required Color inactiveText,
  }) {
    final isActive = _tabController.index == index;
    final isPressed = _pressedMobileTabIndex == index;
    final bg = isActive
        ? _tabActiveBackground(accentColor)
        : isPressed
        ? _tabActiveBackground(accentColor).withValues(alpha: 0.55)
        : Colors.transparent;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: isPressed ? 0.98 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
          onHighlightChanged: (value) =>
              setState(() => _pressedMobileTabIndex = value ? index : null),
          splashColor: accentColor.withValues(alpha: 0.10),
          highlightColor: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accentColor.withValues(alpha: isActive ? 0.18 : 0.10),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? accentColor : inactiveText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSocialTab({required String label, required int index}) {
    final isActive = _tabController.index == index;
    final accent = _tabAccentColorForIndex(index);
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _tabActiveBackground(accent) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: isActive ? 0.18 : 0.10),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? accent : const Color(0xFF7A8A9A),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // Facebook Style: 3 Columns
    // Left: Navigation (handled by App Shell usually, but we can add shortcuts here)
    // Center: Feed (Tab Content)
    // Right: Birthdays, Contacts, etc.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        backgroundColor: const Color(0xFFF5F9FD),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: _handleBack,
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.church_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comunidade',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Compartilhe, ore e participe',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, theme.scaffoldBackgroundColor],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    _buildSidebarItem(
                      0,
                      Icons.dashboard,
                      'Mural',
                      _tabAccentColorForIndex(0),
                    ),
                    _buildSidebarItem(
                      1,
                      Icons.volunteer_activism,
                      'Orações',
                      _tabAccentColorForIndex(1),
                    ),
                    _buildSidebarItem(
                      2,
                      Icons.storefront,
                      'Classificados',
                      _tabAccentColorForIndex(2),
                    ),
                    _buildSidebarItem(
                      3,
                      Icons.people,
                      'Membros',
                      _tabAccentColorForIndex(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, _) {
                                return TabBar(
                                  controller: _tabController,
                                  dividerColor: Colors.transparent,
                                  indicator: const BoxDecoration(),
                                  overlayColor: WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states.contains(
                                            WidgetState.pressed,
                                          ) ||
                                          states.contains(
                                            WidgetState.hovered,
                                          )) {
                                        return colorScheme.primary.withValues(
                                          alpha: 0.06,
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  tabs: [
                                    _buildDesktopSocialTab(
                                      label: 'Mural',
                                      index: 0,
                                    ),
                                    _buildDesktopSocialTab(
                                      label: 'Orações',
                                      index: 1,
                                    ),
                                    _buildDesktopSocialTab(
                                      label: 'Classificados',
                                      index: 2,
                                    ),
                                    _buildDesktopSocialTab(
                                      label: 'Membros',
                                      index: 3,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: const [
                              _MuralTab(filterType: null),
                              _MuralTab(filterType: 'prayer_request'),
                              _ClassifiedsTab(),
                              _MembersTab(showBirthdays: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      _CommunityMomentCard(),
                      SizedBox(height: 12),
                      _BirthdaysSection(),
                      Divider(),
                      Expanded(child: _ContactsSection()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label,
    Color color,
  ) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final isSelected = _tabController.index == index;
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Icon(
            icon,
            color: isSelected ? color : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            label,
            style: CommunityDesign.metaStyle(context).copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => _tabController.animateTo(index),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: isSelected ? color.withValues(alpha: 0.08) : null,
        );
      },
    );
  }

  Widget? _buildFab() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isMobile = MediaQuery.of(context).size.width < 700;
        if (_tabController.index == 0 || _tabController.index == 1) {
          if (!isMobile) {
            return FloatingActionButton.extended(
              onPressed: () => _showCreatePostDialog(context),
              icon: const Icon(Icons.add_comment),
              label: const Text('Novo Post'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }
          return _buildSocialFab(
            backgroundColor: _muralBlue,
            foregroundColor: Colors.white,
            icon: Icons.add_comment,
            label: 'Novo Post',
            onTap: () => _showCreatePostDialog(context),
            breathe: true,
          );
        } else if (_tabController.index == 2) {
          if (!isMobile) {
            return FloatingActionButton.extended(
              onPressed: () => _showCreateClassifiedDialog(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Novo Anúncio'),
              backgroundColor: _classifiedOrange,
              foregroundColor: Colors.white,
            );
          }
          return _buildSocialFab(
            backgroundColor: _classifiedOrange,
            foregroundColor: Colors.white,
            icon: Icons.add_shopping_cart,
            label: 'Novo Anúncio',
            onTap: () => _showCreateClassifiedDialog(context),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSocialFab({
    required Color backgroundColor,
    required Color foregroundColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool breathe = false,
  }) {
    final shadow = backgroundColor.withValues(alpha: 0.25);
    return AnimatedBuilder(
      animation: _fabBreathController,
      builder: (context, child) {
        final breath = breathe
            ? (1 +
                  (0.03 *
                      Curves.easeInOut.transform(_fabBreathController.value)))
            : 1.0;
        return Transform.scale(scale: breath, child: child);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _fabPressed ? 0.98 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onHighlightChanged: (value) =>
                  setState(() => _fabPressed = value),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 24, color: foregroundColor),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: CommunityDesign.metaStyle(context).copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final contentController = TextEditingController();
    String type = _tabController.index == 1
        ? 'prayer_request'
        : 'general'; // Default based on tab
    bool isPublic = false;
    bool allowWhatsappContact = true;

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.28,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _getIconForType(type),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getTitleForType(type),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTypeOption(
                              context,
                              'prayer_request',
                              'Pedido de Oração',
                              '🙏',
                              colorScheme.tertiary,
                              type == 'prayer_request',
                              () => setState(() => type = 'prayer_request'),
                            ),
                            const SizedBox(width: 8),
                            _buildTypeOption(
                              context,
                              'testimony',
                              'Testemunho',
                              '🙌',
                              colorScheme.secondary,
                              type == 'testimony',
                              () => setState(() => type = 'testimony'),
                            ),
                            const SizedBox(width: 8),
                            _buildTypeOption(
                              context,
                              'general',
                              'Compartilhar',
                              '😊',
                              colorScheme.primary,
                              type == 'general',
                              () => setState(() => type = 'general'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (type == 'prayer_request')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Obrigado por compartilhar! Vamos orar juntos! Se desejar, compartilhe seu pedido de oração para que possamos interceder por você como família e corpo de Cristo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      if (type == 'prayer_request') const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        decoration: const InputDecoration(
                          hintText: 'No que você está pensando?',
                        ),
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: allowWhatsappContact,
                        onChanged: (val) =>
                            setState(() => allowWhatsappContact = val ?? false),
                        title: const Text(
                          'Permitir contato via WhatsApp',
                          style: TextStyle(fontSize: 14),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: isPublic,
                        onChanged: (val) =>
                            setState(() => isPublic = val ?? false),
                        title: const Text(
                          'Permitir que meu pedido de oração seja Público',
                          style: TextStyle(fontSize: 14),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              label: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              style: _pillTextButtonStyle(
                                foregroundColor: colorScheme.onSurfaceVariant,
                                overlayColor: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                return ElevatedButton.icon(
                                  onPressed: () async {
                                    if (contentController.text.isNotEmpty) {
                                      try {
                                        await ref
                                            .read(communityRepositoryProvider)
                                            .createPost(
                                              contentController.text,
                                              type,
                                              isPublic: isPublic,
                                              allowWhatsappContact:
                                                  allowWhatsappContact,
                                            );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Post enviado!'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text('Erro: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                  ),
                                  style: _pillElevatedButtonStyle(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    overlayColor: colorScheme.onPrimary
                                        .withValues(alpha: 0.12),
                                  ),
                                  label: const Text('Publicar'),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                _getIconForType(type),
                const SizedBox(width: 8),
                Text(_getTitleForType(type)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeOption(
                            context,
                            'prayer_request',
                            'Pedido de Oração',
                            '🙏',
                            colorScheme.tertiary,
                            type == 'prayer_request',
                            () => setState(() => type = 'prayer_request'),
                          ),
                          const SizedBox(width: 8),
                          _buildTypeOption(
                            context,
                            'testimony',
                            'Testemunho',
                            '🙌',
                            colorScheme.secondary,
                            type == 'testimony',
                            () => setState(() => type = 'testimony'),
                          ),
                          const SizedBox(width: 8),
                          _buildTypeOption(
                            context,
                            'general',
                            'Compartilhar',
                            '😊',
                            colorScheme.primary,
                            type == 'general',
                            () => setState(() => type = 'general'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (type == 'prayer_request')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Obrigado por compartilhar! Vamos orar juntos! Se desejar, compartilhe seu pedido de oração para que possamos interceder por você como família e corpo de Cristo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    if (type == 'prayer_request') const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        hintText: 'No que você está pensando?',
                      ),
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: allowWhatsappContact,
                      onChanged: (val) =>
                          setState(() => allowWhatsappContact = val ?? false),
                      title: const Text(
                        'Permitir contato via WhatsApp',
                        style: TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: isPublic,
                      onChanged: (val) =>
                          setState(() => isPublic = val ?? false),
                      title: const Text(
                        'Permitir que meu pedido de oração seja Público',
                        style: TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  'Cancelar',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                style: _pillTextButtonStyle(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  overlayColor: colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton.icon(
                    onPressed: () async {
                      if (contentController.text.isNotEmpty) {
                        try {
                          await ref
                              .read(communityRepositoryProvider)
                              .createPost(
                                contentController.text,
                                type,
                                isPublic: isPublic,
                                allowWhatsappContact: allowWhatsappContact,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post enviado!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: _pillElevatedButtonStyle(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      overlayColor: colorScheme.onPrimary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    label: const Text('Publicar'),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _getIconForType(String type) {
    const emojiFallback = <String>[
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Noto Color Emoji',
    ];

    switch (type) {
      case 'prayer_request':
        return const Text(
          '🙏',
          style: TextStyle(fontSize: 24, fontFamilyFallback: emojiFallback),
        );
      case 'testimony':
        return const Text(
          '🙌',
          style: TextStyle(fontSize: 24, fontFamilyFallback: emojiFallback),
        );
      default:
        return const Text(
          '😊',
          style: TextStyle(fontSize: 24, fontFamilyFallback: emojiFallback),
        );
    }
  }

  String _getTitleForType(String type) {
    switch (type) {
      case 'prayer_request':
        return 'Pedido de oração';
      case 'testimony':
        return 'Testemunho';
      default:
        return 'Criar Publicação';
    }
  }

  Widget _buildTypeOption(
    BuildContext context,
    String value,
    String label,
    String emoji,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadClassifiedImage(XFile file) async {
    final supabase = Supabase.instance.client;
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) throw Exception('Usuário não autenticado');
    final userId = member.id;

    final bytes = await file.readAsBytes();
    final name = file.name;
    final extension = name.contains('.') ? name.split('.').last : 'jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final filePath = 'classifieds/$userId/$timestamp.$extension';

    await supabase.storage
        .from('church-assets')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );

    return supabase.storage.from('church-assets').getPublicUrl(filePath);
  }

  Future<List<String>> _pickAndUploadClassifiedImages({
    required BuildContext context,
    required int maxCount,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked.isEmpty) return const [];

    final limited = picked.take(maxCount).toList();
    final urls = <String>[];
    for (final file in limited) {
      urls.add(await _uploadClassifiedImage(file));
    }
    return urls;
  }

  void _showCreateClassifiedDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final contactController = TextEditingController();
    String category = 'product';
    String dealStatus = 'available';
    final imageUrls = <String>[];
    bool isUploadingImages = false;

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: StatefulBuilder(
                builder: (context, setState) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.28,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Novo Anúncio',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              tooltip: 'Fechar',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          items: const [
                            DropdownMenuItem(
                              value: 'product',
                              child: Text('Produto'),
                            ),
                            DropdownMenuItem(
                              value: 'service',
                              child: Text('Serviço'),
                            ),
                            DropdownMenuItem(
                              value: 'job',
                              child: Text('Vaga de Emprego'),
                            ),
                            DropdownMenuItem(
                              value: 'donation',
                              child: Text('Doação'),
                            ),
                            DropdownMenuItem(
                              value: 'wanted',
                              child: Text('Procuro Comprar'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => category = val);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Fotos (até 3)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  isUploadingImages || imageUrls.length >= 3
                                  ? null
                                  : () async {
                                      setState(() => isUploadingImages = true);
                                      try {
                                        final urls =
                                            await _pickAndUploadClassifiedImages(
                                              context: context,
                                              maxCount: 3 - imageUrls.length,
                                            );
                                        setState(() {
                                          imageUrls.addAll(urls);
                                        });
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Erro ao enviar fotos: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(
                                            () => isUploadingImages = false,
                                          );
                                        }
                                      }
                                    },
                              icon: isUploadingImages
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 18,
                                    ),
                              label: const Text('Adicionar'),
                              style: _pillTextButtonStyle(
                                foregroundColor: colorScheme.primary,
                                overlayColor: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final entry in imageUrls.asMap().entries)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: GestureDetector(
                                        onTap: () => _showImageGalleryDialog(
                                          context,
                                          imageUrls,
                                          initialIndex: entry.key,
                                        ),
                                        child: Image.network(
                                          entry.value,
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => imageUrls.removeAt(entry.key),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Preço (Opcional)',
                            prefixText: 'R\$ ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contato (WhatsApp/Tel)',
                            helperText: 'Deixe em branco para usar seu perfil',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                label: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                style: _pillTextButtonStyle(
                                  foregroundColor: colorScheme.onSurfaceVariant,
                                  overlayColor: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, _) {
                                  return ElevatedButton(
                                    onPressed: () async {
                                      if (titleController.text.isNotEmpty &&
                                          descriptionController
                                              .text
                                              .isNotEmpty) {
                                        try {
                                          final price = double.tryParse(
                                            priceController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          );

                                          final classified = Classified(
                                            id: '',
                                            authorId: '',
                                            title: titleController.text,
                                            description:
                                                descriptionController.text,
                                            price: price,
                                            category: category,
                                            contactInfo:
                                                contactController.text.isEmpty
                                                ? null
                                                : contactController.text,
                                            imageUrls: imageUrls,
                                            status: 'pending_approval',
                                            dealStatus: dealStatus,
                                            viewsCount: 0,
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                          );

                                          await ref
                                              .read(communityRepositoryProvider)
                                              .createClassified(classified);

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Anúncio enviado para aprovação!',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Erro: $e'),
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Preencha título e descrição.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: _pillElevatedButtonStyle(
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                      overlayColor: colorScheme.onSecondary
                                          .withValues(alpha: 0.12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.send_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Publicar'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Novo Anúncio'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return DropdownButtonFormField<String>(
                        initialValue: category,
                        items: const [
                          DropdownMenuItem(
                            value: 'product',
                            child: Text('Produto'),
                          ),
                          DropdownMenuItem(
                            value: 'service',
                            child: Text('Serviço'),
                          ),
                          DropdownMenuItem(
                            value: 'job',
                            child: Text('Vaga de Emprego'),
                          ),
                          DropdownMenuItem(
                            value: 'donation',
                            child: Text('Doação'),
                          ),
                          DropdownMenuItem(
                            value: 'wanted',
                            child: Text('Procuro Comprar'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => category = val!);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Fotos (até 3)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    isUploadingImages || imageUrls.length >= 3
                                    ? null
                                    : () async {
                                        setState(
                                          () => isUploadingImages = true,
                                        );
                                        try {
                                          final urls =
                                              await _pickAndUploadClassifiedImages(
                                                context: context,
                                                maxCount: 3 - imageUrls.length,
                                              );
                                          setState(() {
                                            imageUrls.addAll(urls);
                                          });
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Erro ao enviar fotos: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            setState(
                                              () => isUploadingImages = false,
                                            );
                                          }
                                        }
                                      },
                                icon: isUploadingImages
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 18,
                                      ),
                                label: const Text('Adicionar'),
                                style: _pillTextButtonStyle(
                                  foregroundColor: colorScheme.primary,
                                  overlayColor: colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final entry in imageUrls.asMap().entries)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: GestureDetector(
                                          onTap: () => _showImageGalleryDialog(
                                            context,
                                            imageUrls,
                                            initialIndex: entry.key,
                                          ),
                                          child: Image.network(
                                            entry.value,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => imageUrls.removeAt(entry.key),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço (Opcional)',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contato (WhatsApp/Tel)',
                      helperText: 'Deixe em branco para usar seu perfil',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              label: Text(
                'Cancelar',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              style: _pillTextButtonStyle(
                foregroundColor: colorScheme.onSurfaceVariant,
                overlayColor: colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty &&
                        descriptionController.text.isNotEmpty) {
                      try {
                        final price = double.tryParse(
                          priceController.text.replaceAll(',', '.'),
                        );

                        final classified = Classified(
                          id: '',
                          authorId: '',
                          title: titleController.text,
                          description: descriptionController.text,
                          price: price,
                          category: category,
                          contactInfo: contactController.text.isEmpty
                              ? null
                              : contactController.text,
                          imageUrls: imageUrls,
                          status: 'pending_approval',
                          dealStatus: dealStatus,
                          viewsCount: 0,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        await ref
                            .read(communityRepositoryProvider)
                            .createClassified(classified);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Anúncio enviado para aprovação!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha título e descrição.'),
                        ),
                      );
                    }
                  },
                  style: _pillElevatedButtonStyle(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    overlayColor: colorScheme.onSecondary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Publicar'),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// --- Sections & Tabs ---

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays}d';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return 'há ${weeks}sem';
  final months = (diff.inDays / 30).floor();
  return 'há ${months}m';
}

String _birthdayEventLabel(DateTime birthdate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(now.year, birthdate.month, birthdate.day);
  if (next.isBefore(today)) {
    next = DateTime(now.year + 1, birthdate.month, birthdate.day);
  }
  final diffDays = next.difference(today).inDays;
  if (diffDays == 0) return '🎉 Hoje';
  if (diffDays == 1) return '🎈 Amanhã';
  return '🎂 ${DateFormat('d MMM', 'pt_BR').format(next)}';
}

String _buildPostShareUrl(String postId) {
  if (kIsWeb) {
    final base = Uri.base;
    final origin = base.hasAuthority
        ? '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}'
        : '';
    return '$origin/#/community/post/$postId';
  }
  return 'https://church360.app/community/post/$postId';
}

class _ActivityPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _ActivityPill({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CommunityDesign.badge(
      context,
      text,
      accent,
      icon: icon,
      iconSize: 16,
    );
  }
}

class _CommunityMomentCard extends ConsumerStatefulWidget {
  final bool dense;
  const _CommunityMomentCard({this.dense = false});

  @override
  ConsumerState<_CommunityMomentCard> createState() =>
      _CommunityMomentCardState();
}

class _CommunityMomentCardState extends ConsumerState<_CommunityMomentCard> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final postsAsync = ref.watch(communityPostsProvider);
    final classifiedsAsync = ref.watch(classifiedsProvider);
    final birthdaysAsync = ref.watch(birthdaysProvider);

    final moments = <_MomentItem>[
      _MomentItem(
        icon: Icons.auto_awesome,
        title: 'Momento da Comunidade',
        subtitle: 'Compartilhe, ore e participe hoje',
        accent: colorScheme.primary,
      ),
    ];

    postsAsync.whenData((posts) {
      final prayers = posts.where((p) => p.type == 'prayer_request').toList();
      if (prayers.isNotEmpty) {
        final latest = prayers.first;
        moments.add(
          _MomentItem(
            icon: Icons.volunteer_activism,
            title: 'Último pedido ${_timeAgoLabel(latest.createdAt)}',
            subtitle: 'Vamos interceder como família',
            accent: const Color(0xFF1D6E45),
          ),
        );
      } else if (posts.isNotEmpty) {
        final latest = posts.first;
        final author = latest.authorNickname ?? latest.authorName ?? 'Alguém';
        moments.add(
          _MomentItem(
            icon: Icons.chat_bubble_outline,
            title: '$author postou ${_timeAgoLabel(latest.createdAt)}',
            subtitle: 'Veja o que está acontecendo no mural',
            accent: const Color(0xFF0B5FA5),
          ),
        );
      }
    });

    classifiedsAsync.whenData((classifieds) {
      if (classifieds.isNotEmpty) {
        final latest = classifieds.first;
        moments.add(
          _MomentItem(
            icon: Icons.storefront,
            title: 'Novo anúncio ${_timeAgoLabel(latest.createdAt)}',
            subtitle: latest.title,
            accent: const Color(0xFF8A5B00),
          ),
        );
      }
    });

    birthdaysAsync.whenData((members) {
      if (members.isNotEmpty) {
        final member = members.first;
        final date = member.birthdate;
        final label = date == null
            ? 'Aniversariante do mês'
            : DateFormat('d MMM', 'pt_BR').format(date);
        moments.add(
          _MomentItem(
            icon: Icons.cake,
            title: '🎂 $label',
            subtitle:
                'Deseje felicidades para ${member.firstName ?? member.nickname ?? 'alguém'}',
            accent: colorScheme.tertiary,
          ),
        );
      }
    });

    final safeIndex = moments.isEmpty ? 0 : (_index % moments.length);
    final item = moments.isEmpty ? null : moments[safeIndex];
    if (item == null) return const SizedBox.shrink();

    final padding = widget.dense
        ? const EdgeInsets.all(12)
        : const EdgeInsets.all(14);
    final titleStyle = CommunityDesign.titleStyle(
      context,
    ).copyWith(fontSize: widget.dense ? 13 : 14, fontWeight: FontWeight.w800);
    final subtitleStyle = CommunityDesign.metaStyle(context).copyWith(
      fontSize: widget.dense ? 12 : 13,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );

    return _OverlayCard(
      padding: padding,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Row(
          key: ValueKey('${item.icon}-${item.title}-${item.subtitle}'),
          children: [
            Container(
              width: widget.dense ? 34 : 38,
              height: widget.dense ? 34 : 38,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.accent.withValues(alpha: 0.18)),
              ),
              child: Icon(
                item.icon,
                color: item.accent,
                size: widget.dense ? 18 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: subtitleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _MomentItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

class _BirthdaysSection extends ConsumerWidget {
  const _BirthdaysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final birthdaysAsync = ref.watch(birthdaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cake, color: colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'Aniversariantes do Mês',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        birthdaysAsync.when(
          data: (members) {
            if (members.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Nenhum aniversariante este mês.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              );
            }
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 120,
                      child: _OverlayCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: member.photoUrl != null
                                      ? NetworkImage(member.photoUrl!)
                                      : null,
                                  child: member.photoUrl == null
                                      ? Text(member.initials)
                                      : null,
                                ),
                                if (member.showContact && member.phone != null)
                                  InkWell(
                                    onTap: () => _launchWhatsapp(member.phone!),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF25D366),
                                            Color(0xFF128C7E),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Center(
                                        child: FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              member.firstName ?? member.nickname ?? '?',
                              style: CommunityDesign.metaStyle(context)
                                  .copyWith(
                                    fontSize: 12,
                                    color: colorScheme.onSurface,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _birthdayEventLabel(member.birthdate!),
                              style: CommunityDesign.metaStyle(context)
                                  .copyWith(
                                    fontSize: 10,
                                    color: colorScheme.tertiary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _launchWhatsapp(String phone) async {
    // Remove non-digits
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse(
      'https://wa.me/55$cleanPhone',
    ); // Assuming BR country code, can be improved
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}

class _ContactsSection extends ConsumerWidget {
  const _ContactsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reusing All Members for now, but in a real app might be "Friends" or "Online"
    return const _MembersTab(showBirthdays: false);
  }
}

class _MuralFeedItem {
  final DateTime createdAt;
  final CommunityPost? post;
  final Classified? classified;

  _MuralFeedItem.post(this.post)
    : classified = null,
      createdAt = post!.createdAt;

  _MuralFeedItem.classified(this.classified)
    : post = null,
      createdAt = classified!.createdAt;
}

class _MuralTab extends ConsumerWidget {
  final String? filterType;
  const _MuralTab({this.filterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final postsAsync = ref.watch(communityPostsProvider);
    final classifiedsAsync = ref.watch(classifiedsProvider);

    return postsAsync.when(
      data: (posts) {
        final classifieds = classifiedsAsync.maybeWhen(
          data: (value) => value,
          orElse: () => const <Classified>[],
        );

        if (filterType == 'prayer_request') {
          final filteredPosts = posts
              .where((p) => p.type == 'prayer_request')
              .toList();

          if (filteredPosts.isEmpty) {
            const title = 'Ainda não há pedidos aqui.';
            const subtitle =
                'Seja o primeiro a orar por alguém. Toque em "Novo Post".';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          const accent = Color(0xFF1D6E45);
          final latest = filteredPosts.first;
          final recentCount = filteredPosts
              .where(
                (p) => p.createdAt.isAfter(
                  now.subtract(const Duration(hours: 24)),
                ),
              )
              .length;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPosts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverlayCard(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActivityPill(
                            icon: Icons.volunteer_activism,
                            text:
                                'Última oração ${_timeAgoLabel(latest.createdAt)}',
                            accent: accent,
                          ),
                          _ActivityPill(
                            icon: Icons.schedule,
                            text: recentCount == 0
                                ? 'Movimento leve nas últimas 24h'
                                : '$recentCount nas últimas 24h',
                            accent: accent,
                          ),
                          _ActivityPill(
                            icon: Icons.groups_2_outlined,
                            text: '${filteredPosts.length} pedidos ativos',
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return _PostCard(post: filteredPosts[index - 1]);
            },
          );
        }

        final items = <_MuralFeedItem>[
          for (final post in posts) _MuralFeedItem.post(post),
          for (final classified in classifieds)
            _MuralFeedItem.classified(classified),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (items.isEmpty) {
          const title = 'Ainda não há publicações.';
          const subtitle =
              'Compartilhe algo com a igreja. Toque em "Novo Post".';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                const Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(subtitle, textAlign: TextAlign.center),
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        const accent = Color(0xFF0B5FA5);
        final recentCount = posts
            .where(
              (p) =>
                  p.createdAt.isAfter(now.subtract(const Duration(hours: 24))),
            )
            .length;
        final likesToday = posts
            .where(
              (p) =>
                  p.createdAt.isAfter(now.subtract(const Duration(hours: 24))),
            )
            .fold<int>(0, (sum, p) => sum + p.likesCount);

        final totalItems = items.length + 1;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: totalItems,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CommunityMomentCard(dense: true),
                  const SizedBox(height: 12),
                  _OverlayCard(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (posts.isNotEmpty)
                          _ActivityPill(
                            icon: Icons.bolt,
                            text:
                                'Última postagem ${_timeAgoLabel(posts.first.createdAt)}',
                            accent: accent,
                          ),
                        _ActivityPill(
                          icon: Icons.volunteer_activism,
                          text:
                              '${posts.where((p) => p.type == 'prayer_request').length} pedidos de oração',
                          accent: const Color(0xFF1D6E45),
                        ),
                        _ActivityPill(
                          icon: Icons.schedule,
                          text: recentCount == 0
                              ? 'Movimento leve nas últimas 24h'
                              : '$recentCount nas últimas 24h',
                          accent: accent,
                        ),
                        _ActivityPill(
                          icon: Icons.favorite,
                          text: likesToday == 0
                              ? 'Seja o primeiro a curtir hoje'
                              : '$likesToday curtidas hoje',
                          accent: accent,
                        ),
                        _ActivityPill(
                          icon: Icons.storefront_outlined,
                          text: classifieds.isEmpty
                              ? 'Nenhum anúncio ativo'
                              : '${classifieds.length} anúncios ativos',
                          accent: const Color(0xFF8A5B00),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final item = items[index - 1];
            if (item.post != null) {
              return _PostCard(post: item.post!);
            }
            return _ClassifiedCard(classified: item.classified!, compact: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }
}

class _OverlayCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _OverlayCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<_OverlayCard> createState() => _OverlayCardState();
}

class _OverlayCardState extends State<_OverlayCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: CommunityDesign.overlayDecoration(
          colorScheme,
          hovered: _hovered,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CommunityDesign.radius),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPost post;

  const _PostCard({required this.post});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard>
    with SingleTickerProviderStateMixin {
  String? _reactionOverride;
  int? _likesOverride;
  bool _isTogglingLike = false;
  bool _likePulse = false;
  bool _commentPulse = false;
  final LayerLink _reactionLink = LayerLink();
  final GlobalKey _reactionTargetKey = GlobalKey();
  OverlayEntry? _reactionOverlay;
  Completer<String?>? _reactionCompleter;
  late final AnimationController _reactionController;
  bool _reactionsShowBelow = false;

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
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likesCount != widget.post.likesCount ||
        oldWidget.post.myReaction != widget.post.myReaction) {
      _reactionOverride = null;
      _likesOverride = null;
      _dismissReactionPicker(immediate: true);
    }
  }

  // Mantido apenas _reactionEmoji; o label fixo é 'Curtir'

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
          .setReaction(widget.post.id, nextReaction);
      ref.invalidate(communityPostsProvider);
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
          .removeReaction(widget.post.id);
      ref.invalidate(communityPostsProvider);
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
    if (box != null) {
      final top = box.localToGlobal(Offset.zero).dy;
      _reactionsShowBelow = top < 104;
    } else {
      _reactionsShowBelow = false;
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

        final targetAnchor = _reactionsShowBelow
            ? Alignment.bottomCenter
            : Alignment.topCenter;
        final followerAnchor = _reactionsShowBelow
            ? Alignment.topCenter
            : Alignment.bottomCenter;
        final offset = _reactionsShowBelow
            ? const Offset(0, 10)
            : const Offset(0, -10);

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
                    alignment: _reactionsShowBelow
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
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
                      child: Row(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.$3,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontFamilyFallback: _emojiFallback,
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                        color: selected == option.$1
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
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
    final post = widget.post;
    final colorScheme = Theme.of(context).colorScheme;
    final authorStyle = CommunityDesign.authorStyle(context);
    final metaStyle = CommunityDesign.metaStyle(context);
    final contentStyle = CommunityDesign.contentStyle(
      context,
    ).copyWith(fontSize: 15.5);

    final myReaction = _reactionOverride ?? post.myReaction;
    final isLiked = myReaction != null;
    final likesCount = _likesOverride ?? post.likesCount;

    return _OverlayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: post.authorAvatarUrl != null
                    ? NetworkImage(post.authorAvatarUrl!)
                    : null,
                child: post.authorAvatarUrl == null
                    ? Text(
                        (post.authorNickname ?? post.authorName ?? '?')[0],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorNickname ?? post.authorName ?? 'Anônimo',
                    style: authorStyle,
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(post.createdAt),
                    style: metaStyle,
                  ),
                ],
              ),
              const Spacer(),
              if (post.allowWhatsappContact)
                InkWell(
                  onTap: () async {
                    if (post.authorPhone != null) {
                      final phone = post.authorPhone!.replaceAll(
                        RegExp(r'[^\d]'),
                        '',
                      );
                      final url = Uri.parse('https://wa.me/$phone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não foi possível abrir o WhatsApp',
                              ),
                            ),
                          );
                        }
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Telefone não disponível'),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              _buildTypeBadge(context, post.type),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.content, style: contentStyle),
          if (post.pollOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: post.pollOptions.map((option) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    width: double.infinity,
                    child: Text(
                      option,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Divider(color: colorScheme.outline.withValues(alpha: 0.16)),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;

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
                        if (label != null) ...[const SizedBox(width: 6), label],
                      ],
                    ),
                  ),
                );
              }

              final muted = colorScheme.onSurfaceVariant;

              return Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final actionColor = isLiked
                            ? colorScheme.primary
                            : muted;
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
                                  duration: const Duration(milliseconds: 160),
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
                                          key: ValueKey<String?>(myReaction),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontFamilyFallback: _emojiFallback,
                                          ),
                                        )
                                      : Icon(
                                          Icons.thumb_up_outlined,
                                          key: const ValueKey<String>('none'),
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
                                        if (!mounted || picked == null) return;

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
                    child: AnimatedScale(
                      scale: _commentPulse ? 1.02 : 1,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: buildPillButton(
                        icon: const Icon(Icons.mode_comment_outlined),
                        label: isCompact ? null : const Text('Comentar'),
                        actionColor: muted,
                        onPressed: () {
                          setState(() => _commentPulse = true);
                          Future.delayed(const Duration(milliseconds: 160), () {
                            if (mounted) setState(() => _commentPulse = false);
                          });

                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (context) =>
                                _CommentsSheet(postId: post.id),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: buildPillButton(
                      icon: const Icon(Icons.share_outlined),
                      label: isCompact ? null : const Text('Compartilhar'),
                      actionColor: muted,
                      onPressed: () {
                        final url = _buildPostShareUrl(post.id);
                        Share.share(
                          'Veja esta publicação na Comunidade da sua igreja:\n$url',
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String type) {
    switch (type) {
      case 'prayer_request':
        return CommunityDesign.badge(
          context,
          'Oração',
          const Color(0xFF1D6E45),
        );
      case 'classified':
        return CommunityDesign.badge(
          context,
          'Classificado',
          const Color(0xFF8A5B00),
        );
      case 'testimony':
        return CommunityDesign.badge(
          context,
          'Testemunho',
          const Color(0xFF5A3BA6),
        );
      default:
        return CommunityDesign.badge(context, 'Geral', const Color(0xFF0B5FA5));
    }
  }
}

class _MembersTab extends ConsumerWidget {
  final bool showBirthdays;
  const _MembersTab({this.showBirthdays = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);

    return Column(
      children: [
        if (showBirthdays)
          const Padding(
            padding: EdgeInsets.all(16),
            child: _BirthdaysSection(),
          ),
        Expanded(
          child: membersAsync.when(
            data: (members) {
              final activeMembers = members.where((m) => m.isActive).toList();
              if (activeMembers.isEmpty) {
                final colorScheme = Theme.of(context).colorScheme;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum membro ativo por aqui.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Quando alguém entrar na comunidade, ele aparece aqui.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.92,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final now = DateTime.now();
              final birthdaysThisMonth = activeMembers
                  .where(
                    (m) =>
                        m.showBirthday &&
                        m.birthdate != null &&
                        m.birthdate!.month == now.month,
                  )
                  .length;
              final contactsAllowed = activeMembers
                  .where((m) => m.showContact && m.phone != null)
                  .length;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: activeMembers.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _OverlayCard(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActivityPill(
                            icon: Icons.groups_2_outlined,
                            text: '${activeMembers.length} membros ativos',
                            accent: const Color(0xFF4E6B85),
                          ),
                          _ActivityPill(
                            icon: Icons.cake_outlined,
                            text: birthdaysThisMonth == 0
                                ? 'Sem aniversários públicos este mês'
                                : '$birthdaysThisMonth aniversários este mês',
                            accent: const Color(0xFF5A3BA6),
                          ),
                          _ActivityPill(
                            icon: Icons.chat_bubble_outline,
                            text: contactsAllowed == 0
                                ? 'WhatsApp liberado: ninguém'
                                : 'WhatsApp liberado: $contactsAllowed',
                            accent: const Color(0xFF25D366),
                          ),
                        ],
                      ),
                    );
                  }
                  final member = activeMembers[index - 1];
                  return _MemberInteractiveCard(member: member);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erro: $err')),
          ),
        ),
      ],
    );
  }
}

class _MemberInteractiveCard extends StatefulWidget {
  final Member member;
  const _MemberInteractiveCard({required this.member});

  @override
  State<_MemberInteractiveCard> createState() => _MemberInteractiveCardState();
}

class _MemberInteractiveCardState extends State<_MemberInteractiveCard> {
  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final colorScheme = Theme.of(context).colorScheme;
    final canShowBirthday = member.showBirthday && member.birthdate != null;
    final canWhatsapp =
        member.showContact &&
        member.phone != null &&
        member.phone!.trim().isNotEmpty;

    final title = member.nickname?.trim().isNotEmpty == true
        ? member.nickname!.trim()
        : member.displayName;
    final dateText = canShowBirthday
        ? DateFormat('dd/MM').format(member.birthdate!)
        : null;

    return _OverlayCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.surfaceContainerHighest,
              backgroundImage: member.photoUrl != null
                  ? NetworkImage(member.photoUrl!)
                  : null,
              child: member.photoUrl == null ? Text(member.initials) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (dateText != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        dateText,
                        style: CommunityDesign.metaStyle(context).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.tertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (canWhatsapp)
              InkWell(
                onTap: () async {
                  final cleanPhone = member.phone!.replaceAll(
                    RegExp(r'[^\d]'),
                    '',
                  );
                  final url = Uri.parse('https://wa.me/55$cleanPhone');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassifiedsTab extends ConsumerWidget {
  const _ClassifiedsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classifiedsAsync = ref.watch(classifiedsProvider);

    return classifiedsAsync.when(
      data: (classifieds) {
        if (classifieds.isEmpty) {
          final colorScheme = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum anúncio por enquanto.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Ofereça, anuncie ou peça algo. Toque em "Novo Anúncio".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.92,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final latest = classifieds.first;
        final weekCount = classifieds
            .where(
              (c) => c.createdAt.isAfter(now.subtract(const Duration(days: 7))),
            )
            .length;
        final accent = const Color(0xFF8A5B00);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _OverlayCard(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActivityPill(
                        icon: Icons.storefront,
                        text:
                            'Último anúncio ${_timeAgoLabel(latest.createdAt)}',
                        accent: accent,
                      ),
                      _ActivityPill(
                        icon: Icons.new_releases_outlined,
                        text: weekCount == 0
                            ? 'Sem novos nesta semana'
                            : '$weekCount novos nesta semana',
                        accent: accent,
                      ),
                      _ActivityPill(
                        icon: Icons.visibility_outlined,
                        text: 'Total: ${classifieds.length}',
                        accent: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.crossAxisExtent;
                  final targetItemWidth = 270.0;
                  final count = (availableWidth / targetItemWidth)
                      .floor()
                      .clamp(1, 4);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 520,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ClassifiedCard(
                        classified: classifieds[index],
                        compact: true,
                      ),
                      childCount: classifieds.length,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }
}

class _ClassifiedCard extends ConsumerStatefulWidget {
  final Classified classified;
  final bool compact; // usado no feed (ListView)

  const _ClassifiedCard({required this.classified, this.compact = false});

  @override
  ConsumerState<_ClassifiedCard> createState() => _ClassifiedCardState();
}

class _ClassifiedCardState extends ConsumerState<_ClassifiedCard>
    with SingleTickerProviderStateMixin {
  int _pageIndex = 0;
  String? _reactionOverride;
  int? _likesOverride;
  bool _isTogglingLike = false;
  bool _likePulse = false;
  bool _commentPulse = false;
  final LayerLink _reactionLink = LayerLink();
  final GlobalKey _reactionTargetKey = GlobalKey();
  OverlayEntry? _reactionOverlay;
  Completer<String?>? _reactionCompleter;
  late final AnimationController _reactionController;
  bool _reactionsShowBelow = false;
  static const _emojiFallback = <String>[
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  String _dealStatusLabel(String dealStatus) {
    switch (dealStatus) {
      case 'sold':
        return 'Vendido';
      case 'donated':
        return 'Doado';
      case 'bought':
        return 'Comprado';
      default:
        return 'Disponível';
    }
  }

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
  void didUpdateWidget(covariant _ClassifiedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classified.id != widget.classified.id ||
        oldWidget.classified.likesCount != widget.classified.likesCount ||
        oldWidget.classified.myReaction != widget.classified.myReaction) {
      _reactionOverride = null;
      _likesOverride = null;
      _dismissReactionPicker(immediate: true);
    }
  }

  // Mantido apenas _reactionEmoji; o label fixo é 'Curtir'

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

  Future<void> _applyClassifiedReaction({
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
          .setClassifiedReaction(widget.classified.id, nextReaction);
      ref.invalidate(classifiedsProvider);
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

  Future<void> _removeClassifiedReaction({
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
          .removeClassifiedReaction(widget.classified.id);
      ref.invalidate(classifiedsProvider);
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
    if (box != null) {
      final top = box.localToGlobal(Offset.zero).dy;
      _reactionsShowBelow = top < 104;
    } else {
      _reactionsShowBelow = false;
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
        final targetAnchor = _reactionsShowBelow
            ? Alignment.bottomCenter
            : Alignment.topCenter;
        final followerAnchor = _reactionsShowBelow
            ? Alignment.topCenter
            : Alignment.bottomCenter;
        final offset = _reactionsShowBelow
            ? const Offset(0, 10)
            : const Offset(0, -10);
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
                    alignment: _reactionsShowBelow
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
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
                      child: Row(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.$3,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontFamilyFallback: _emojiFallback,
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                        color: selected == option.$1
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    final classified = widget.classified;
    final isUnavailable = classified.dealStatus != 'available';
    final hasMultipleImages = classified.imageUrls.length > 1;
    final myReaction = _reactionOverride ?? classified.myReaction;
    final isLiked = myReaction != null;
    final likesCount = _likesOverride ?? classified.likesCount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => _ClassifiedDetailsSheet(classified: classified),
        );
      },
      child: _OverlayCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: classified.authorAvatarUrl != null
                        ? NetworkImage(classified.authorAvatarUrl!)
                        : null,
                    child: classified.authorAvatarUrl == null
                        ? Text(
                            (classified.authorNickname ??
                                classified.authorName ??
                                '?')[0],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classified.authorNickname ??
                              classified.authorName ??
                              'Anônimo',
                          style: CommunityDesign.authorStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(classified.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: CommunityDesign.badge(
                          context,
                          'Classificado',
                          const Color(0xFF8A5B00),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.compact)
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      child: classified.imageUrls.isEmpty
                          ? Icon(
                              Icons.image,
                              size: 50,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            )
                          : hasMultipleImages
                          ? PageView.builder(
                              itemCount: classified.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _pageIndex = i),
                              itemBuilder: (context, index) => Image.network(
                                classified.imageUrls[index],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.network(
                              classified.imageUrls.first,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (hasMultipleImages)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var i = 0;
                              i < classified.imageUrls.length;
                              i++
                            )
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: i == _pageIndex ? 16 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: i == _pageIndex ? 0.95 : 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (isUnavailable)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isUnavailable)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _dealStatusLabel(classified.dealStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (widget.compact)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  children: [
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      child: classified.imageUrls.isEmpty
                          ? Icon(
                              Icons.image,
                              size: 50,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            )
                          : hasMultipleImages
                          ? PageView.builder(
                              itemCount: classified.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _pageIndex = i),
                              itemBuilder: (context, index) => Image.network(
                                classified.imageUrls[index],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.network(
                              classified.imageUrls.first,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (hasMultipleImages)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var i = 0;
                              i < classified.imageUrls.length;
                              i++
                            )
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: i == _pageIndex ? 16 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: i == _pageIndex ? 0.95 : 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (isUnavailable)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isUnavailable)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _dealStatusLabel(classified.dealStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classified.price != null
                        ? 'R\$ ${classified.price!.toStringAsFixed(2)}'
                        : 'Grátis/A Combinar',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    classified.title,
                    maxLines: widget.compact ? 2 : null,
                    overflow: TextOverflow.ellipsis,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (classified.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      classified.description,
                      maxLines: widget.compact ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.contentStyle(
                        context,
                      ).copyWith(fontSize: 15.5),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: colorScheme.outline.withValues(alpha: 0.16)),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 380;
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

                      final muted = colorScheme.onSurfaceVariant;
                      return Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final actionColor = isLiked
                                    ? colorScheme.primary
                                    : muted;
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
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
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
                                            ? FittedBox(
                                                child: Text('$likesCount'),
                                              )
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
                                                  if (myReaction == null) {
                                                    return;
                                                  }
                                                  await _removeClassifiedReaction(
                                                    currentReaction: myReaction,
                                                    currentLikesCount:
                                                        likesCount,
                                                  );
                                                  return;
                                                }
                                                await _applyClassifiedReaction(
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
                            child: AnimatedScale(
                              scale: _commentPulse ? 1.02 : 1,
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOut,
                              child: buildPillButton(
                                icon: const Icon(Icons.mode_comment_outlined),
                                label: isCompact
                                    ? null
                                    : const Text('Comentar'),
                                actionColor: muted,
                                onPressed: () {
                                  setState(() => _commentPulse = true);
                                  Future.delayed(
                                    const Duration(milliseconds: 160),
                                    () {
                                      if (mounted) {
                                        setState(() => _commentPulse = false);
                                      }
                                    },
                                  );
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) =>
                                        _ClassifiedCommentsSheet(
                                          classifiedId: classified.id,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: buildPillButton(
                              icon: const Icon(Icons.share_outlined),
                              label: isCompact
                                  ? null
                                  : const Text('Compartilhar'),
                              actionColor: muted,
                              onPressed: () {
                                final priceText = classified.price != null
                                    ? 'por R\$ ${classified.price!.toStringAsFixed(2)}'
                                    : '';
                                final text =
                                    'Confira este classificado: ${classified.title} $priceText\n${classified.description}';
                                Share.share(text.trim());
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
    );
  }
}

Future<void> _showImageGalleryDialog(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
}) async {
  if (urls.isEmpty) return;

  final safeIndex = initialIndex.clamp(0, urls.length - 1);

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (context) =>
        _ImageGalleryDialog(urls: urls, initialIndex: safeIndex),
  );
}

class _ImageGalleryDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImageGalleryDialog({required this.urls, required this.initialIndex});

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) {
                setState(() {
                  _pageIndex = i;
                });
              },
              itemBuilder: (context, index) => Center(
                child: Image.network(urls[index], fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < urls.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: i == _pageIndex ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _pageIndex ? 0.95 : 0.55,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassifiedDetailsSheet extends ConsumerStatefulWidget {
  final Classified classified;
  const _ClassifiedDetailsSheet({required this.classified});

  @override
  ConsumerState<_ClassifiedDetailsSheet> createState() =>
      _ClassifiedDetailsSheetState();
}

class _ClassifiedDetailsSheetState
    extends ConsumerState<_ClassifiedDetailsSheet> {
  late Classified _classified;
  int _pageIndex = 0;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _classified = widget.classified;
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'service':
        return 'Serviço';
      case 'job':
        return 'Vaga';
      case 'donation':
        return 'Doação';
      case 'wanted':
        return 'Procuro Comprar';
      default:
        return 'Produto';
    }
  }

  String _dealStatusLabel(String dealStatus) {
    switch (dealStatus) {
      case 'sold':
        return 'Vendido';
      case 'donated':
        return 'Doado';
      case 'bought':
        return 'Comprado';
      default:
        return 'Disponível';
    }
  }

  String _primaryDealStatus(String category) {
    switch (category) {
      case 'donation':
        return 'donated';
      case 'wanted':
        return 'bought';
      default:
        return 'sold';
    }
  }

  String _primaryDealLabel(String category) {
    switch (category) {
      case 'donation':
        return 'Marcar como Doado';
      case 'wanted':
        return 'Marcar como Comprado';
      default:
        return 'Marcar como Vendido';
    }
  }

  Future<void> _setDealStatus(String next) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .setClassifiedDealStatus(_classified.id, next);
      ref.invalidate(classifiedsProvider);
      if (mounted) {
        setState(() {
          _classified = Classified(
            id: _classified.id,
            authorId: _classified.authorId,
            title: _classified.title,
            description: _classified.description,
            price: _classified.price,
            category: _classified.category,
            contactInfo: _classified.contactInfo,
            imageUrls: _classified.imageUrls,
            status: _classified.status,
            dealStatus: next,
            viewsCount: _classified.viewsCount,
            createdAt: _classified.createdAt,
            updatedAt: DateTime.now(),
            authorName: _classified.authorName,
            authorAvatarUrl: _classified.authorAvatarUrl,
            authorNickname: _classified.authorNickname,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _openEdit() async {
    final colorScheme = Theme.of(context).colorScheme;
    final updated = await showModalBottomSheet<Classified>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EditClassifiedSheet(classified: _classified),
    );

    if (!mounted || updated == null) return;
    setState(() => _classified = updated);
    ref.invalidate(classifiedsProvider);
  }

  Future<void> _openContact() async {
    final contact = _classified.contactInfo?.trim();
    if (contact == null || contact.isEmpty) return;
    final digits = contact.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 8) {
      final url = Uri.parse('https://wa.me/$digits');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentMemberId = ref.watch(currentMemberProvider).value?.id;
    final isOwner = currentMemberId != null && currentMemberId == _classified.authorId;

    final primaryStatus = _primaryDealStatus(_classified.category);
    final showPrimary = _classified.dealStatus == 'available';
    final showBackToAvailable = _classified.dealStatus != 'available';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: _classified.authorAvatarUrl != null
                        ? NetworkImage(_classified.authorAvatarUrl!)
                        : null,
                    child: _classified.authorAvatarUrl == null
                        ? Text(
                            (_classified.authorNickname ??
                                _classified.authorName ??
                                '?')[0],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _classified.authorNickname ??
                            _classified.authorName ??
                            'Anônimo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(_classified.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF2D797)),
                    ),
                    child: const Text(
                      'Classificado',
                      style: TextStyle(
                        color: Color(0xFF8A5B00),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _classified.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _classified.imageUrls.isEmpty
                      ? Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image,
                            size: 56,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            PageView.builder(
                              itemCount: _classified.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _pageIndex = i),
                              itemBuilder: (context, index) => GestureDetector(
                                onTap: () => _showImageGalleryDialog(
                                  context,
                                  _classified.imageUrls,
                                  initialIndex: index,
                                ),
                                child: Image.network(
                                  _classified.imageUrls[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (_classified.imageUrls.length > 1)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 10,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _classified.imageUrls.length;
                                      i++
                                    )
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        width: i == _pageIndex ? 16 : 7,
                                        height: 7,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: i == _pageIndex
                                                ? 0.95
                                                : 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _classified.price != null
                        ? 'R\$ ${_classified.price!.toStringAsFixed(2)}'
                        : 'Grátis/A Combinar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      _categoryLabel(_classified.category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (_classified.dealStatus != 'available') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dealStatusLabel(_classified.dealStatus),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _classified.description,
                style: TextStyle(color: colorScheme.onSurface, height: 1.5),
              ),
              const SizedBox(height: 12),
              if ((_classified.contactInfo ?? '').trim().isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _classified.contactInfo!,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          ((_classified.contactInfo ?? '').trim().isEmpty)
                          ? null
                          : _openContact,
                      icon: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      label: const Text('Contato'),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isWorking ? null : _openEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                  ],
                ],
              ),
              if (isOwner) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (showPrimary)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isWorking
                              ? null
                              : () => _setDealStatus(primaryStatus),
                          child: Text(_primaryDealLabel(_classified.category)),
                        ),
                      ),
                    if (showBackToAvailable)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isWorking
                              ? null
                              : () => _setDealStatus('available'),
                          child: const Text('Marcar como Disponível'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditClassifiedSheet extends ConsumerStatefulWidget {
  final Classified classified;
  const _EditClassifiedSheet({required this.classified});

  @override
  ConsumerState<_EditClassifiedSheet> createState() =>
      _EditClassifiedSheetState();
}

class _EditClassifiedSheetState extends ConsumerState<_EditClassifiedSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _contactController;
  late String _category;
  late List<String> _imageUrls;
  bool _isUploadingImages = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.classified.title);
    _descriptionController = TextEditingController(
      text: widget.classified.description,
    );
    _priceController = TextEditingController(
      text: widget.classified.price?.toStringAsFixed(2) ?? '',
    );
    _contactController = TextEditingController(
      text: widget.classified.contactInfo ?? '',
    );
    _category = widget.classified.category;
    _imageUrls = List<String>.from(widget.classified.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<String> _uploadImage(XFile file) async {
    final supabase = Supabase.instance.client;
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) throw Exception('Usuário não autenticado');
    final userId = member.id;

    final bytes = await file.readAsBytes();
    final name = file.name;
    final extension = name.contains('.') ? name.split('.').last : 'jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final filePath = 'classifieds/$userId/$timestamp.$extension';

    await supabase.storage
        .from('church-assets')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );

    return supabase.storage.from('church-assets').getPublicUrl(filePath);
  }

  Future<void> _addImages() async {
    if (_isUploadingImages || _imageUrls.length >= 3) return;
    setState(() => _isUploadingImages = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      final limited = picked.take(3 - _imageUrls.length).toList();
      final urls = <String>[];
      for (final file in limited) {
        urls.add(await _uploadImage(file));
      }
      if (mounted) setState(() => _imageUrls.addAll(urls));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar fotos: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha título e descrição.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final price = double.tryParse(
        _priceController.text.trim().replaceAll(',', '.'),
      );
      final updated = Classified(
        id: widget.classified.id,
        authorId: widget.classified.authorId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _category,
        contactInfo: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        imageUrls: _imageUrls,
        status: widget.classified.status,
        dealStatus: widget.classified.dealStatus,
        viewsCount: widget.classified.viewsCount,
        createdAt: widget.classified.createdAt,
        updatedAt: DateTime.now(),
        authorName: widget.classified.authorName,
        authorAvatarUrl: widget.classified.authorAvatarUrl,
        authorNickname: widget.classified.authorNickname,
      );

      await ref.read(communityRepositoryProvider).updateClassified(updated);
      if (mounted) {
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar anúncio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: const [
                  DropdownMenuItem(value: 'product', child: Text('Produto')),
                  DropdownMenuItem(value: 'service', child: Text('Serviço')),
                  DropdownMenuItem(
                    value: 'job',
                    child: Text('Vaga de Emprego'),
                  ),
                  DropdownMenuItem(value: 'donation', child: Text('Doação')),
                  DropdownMenuItem(
                    value: 'wanted',
                    child: Text('Procuro Comprar'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _category = val ?? _category),
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fotos (até 3)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isUploadingImages || _imageUrls.length >= 3
                        ? null
                        : _addImages,
                    icon: _isUploadingImages
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              if (_imageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _imageUrls.asMap().entries)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: GestureDetector(
                              onTap: () => _showImageGalleryDialog(
                                context,
                                _imageUrls,
                                initialIndex: entry.key,
                              ),
                              child: Image.network(
                                entry.value,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => setState(
                                () => _imageUrls.removeAt(entry.key),
                              ),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Preço (Opcional)',
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contato (WhatsApp/Tel)',
                  helperText: 'Deixe em branco para usar seu perfil',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        'Cancelar',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Salvar'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
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

  Future<void> _fetchComments() async {
    try {
      final comments = await ref
          .read(communityRepositoryProvider)
          .getComments(widget.postId);
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
      await ref
          .read(communityRepositoryProvider)
          .addComment(widget.postId, _controller.text.trim());
      _controller.clear();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
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
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.28,
                          ),
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
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final author = comment['author'] ?? {};
                            final createdAt =
                                DateTime.tryParse(comment['created_at']) ??
                                DateTime.now();

                            final name =
                                author['full_name'] ??
                                author['nickname'] ??
                                'Anônimo';
                            final avatarText =
                                (author['full_name'] ??
                                        author['nickname'] ??
                                        '?')
                                    .toString();
                            final avatarInitial = avatarText.isNotEmpty
                                ? avatarText[0]
                                : '?';

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: author['avatar_url'] != null
                                      ? NetworkImage(author['avatar_url'])
                                      : null,
                                  child: author['avatar_url'] == null
                                      ? Text(avatarInitial)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style:
                                                    CommunityDesign.titleStyle(
                                                      context,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'dd/MM HH:mm',
                                              ).format(createdAt),
                                              style: CommunityDesign.metaStyle(
                                                context,
                                              ).copyWith(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (comment['content'] ?? '').toString(),
                                          style:
                                              CommunityDesign.metaStyle(
                                                context,
                                              ).copyWith(
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
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Escreva um comentário...',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          enabled: !commentsDisabled,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (commentsDisabled || _isSending)
                              ? null
                              : _addComment,
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            colorScheme.primary,
                          ),
                          child: _isSending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
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

class _ClassifiedCommentsSheet extends ConsumerStatefulWidget {
  final String classifiedId;
  const _ClassifiedCommentsSheet({required this.classifiedId});

  @override
  ConsumerState<_ClassifiedCommentsSheet> createState() =>
      _ClassifiedCommentsSheetState();
}

class _ClassifiedCommentsSheetState
    extends ConsumerState<_ClassifiedCommentsSheet> {
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

  Future<void> _fetchComments() async {
    try {
      final comments = await ref
          .read(communityRepositoryProvider)
          .getClassifiedComments(widget.classifiedId);
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
      await ref
          .read(communityRepositoryProvider)
          .addClassifiedComment(widget.classifiedId, _controller.text.trim());
      _controller.clear();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
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
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.28,
                          ),
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
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final author = comment['author'] ?? {};
                            final createdAt =
                                DateTime.tryParse(comment['created_at']) ??
                                DateTime.now();
                            final name =
                                author['full_name'] ??
                                author['nickname'] ??
                                'Anônimo';
                            final avatarText =
                                (author['full_name'] ??
                                        author['nickname'] ??
                                        '?')
                                    .toString();
                            final avatarInitial = avatarText.isNotEmpty
                                ? avatarText[0]
                                : '?';
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: author['avatar_url'] != null
                                      ? NetworkImage(author['avatar_url'])
                                      : null,
                                  child: author['avatar_url'] == null
                                      ? Text(avatarInitial)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style:
                                                    CommunityDesign.titleStyle(
                                                      context,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat(
                                                'dd/MM HH:mm',
                                              ).format(createdAt),
                                              style: CommunityDesign.metaStyle(
                                                context,
                                              ).copyWith(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (comment['content'] ?? '').toString(),
                                          style:
                                              CommunityDesign.metaStyle(
                                                context,
                                              ).copyWith(
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
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Escreva um comentário...',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          enabled: !commentsDisabled,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (commentsDisabled || _isSending)
                              ? null
                              : _addComment,
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            colorScheme.primary,
                          ),
                          child: _isSending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
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
