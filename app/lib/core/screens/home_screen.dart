import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/church_image.dart';
import '../../features/permissions/presentation/widgets/dashboard_access_gate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/contribution/presentation/screens/contribution_info_screen.dart';
import '../../features/devotionals/presentation/screens/devotionals_list_screen.dart';
import '../screens/agenda_tab_screen.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/events/presentation/providers/events_provider.dart';
import '../../features/devotionals/presentation/providers/devotional_provider.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/home_content/presentation/providers/banners_provider.dart';
import '../../features/home_content/domain/models/banner.dart';
import '../../features/reading_plans/presentation/screens/reading_plan_detail_screen.dart';
import '../../features/church_info/presentation/providers/church_info_provider.dart';
import '../design/community_design.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../../features/home/presentation/widgets/home_content_card.dart';
import '../../features/home/presentation/widgets/home_section_widget.dart';

/// Tela principal do app com navegação por abas fixas
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 2; // Inicia no Home (Dashboard)
  bool _initializedFromQuery = false;
  bool _syncedDefaultTabToUrl = false;

  String _tabParamForIndex(int index) {
    switch (index) {
      case 0:
        return 'devotionals';
      case 1:
        return 'agenda';
      case 2:
        return 'home';
      case 3:
        return 'contribution';
      case 4:
        return 'more';
      default:
        return 'home';
    }
  }

  int _indexForTabParam(String? tab) {
    switch (tab) {
      case 'devotionals':
        return 0;
      case 'agenda':
        return 1;
      case 'home':
        return 2;
      case 'contribution':
        return 3;
      case 'more':
        return 4;
      default:
        return 2;
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

  // Método para navegar para uma aba específica
  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _syncUrlToSelectedIndex();
  }

  // Abas fixas do app
  List<Widget> get _screens => [
    const DevotionalsListScreen(), // Devocionais
    const AgendaTabScreen(), // Agenda (Eventos + Calendário)
    _DashboardTab(onNavigateToTab: _navigateToTab), // Home (Dashboard)
    const ContributionInfoScreen(), // Contribua
    const _MoreTab(), // Mais (Menu)
  ];

  @override
  Widget build(BuildContext context) {
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
        if (_selectedIndex != 2) {
          setState(() {
            _selectedIndex = 2;
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
        ).then((confirm) {
          if (confirm == true && context.mounted) {
            Navigator.of(context).pop();
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Home - Mural do app com eventos, cultos e informações úteis
class _DashboardTab extends ConsumerWidget {
  final void Function(int) onNavigateToTab;

  const _DashboardTab({required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100), // Espaço para Navigation Bar (aumentado)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Novo (Olá, Nome...)
                const _HomeHeader(),

                // Card: Feed Espiritual (Como está se sentindo hoje?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const _SpiritualFeedCard(),
                ),

                const SizedBox(height: 8),

                // Círculos de atalhos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const _ShortcutCircles(),
                ),

                const SizedBox(height: 12),

                // Banner rotativo da home
                const _HomeBanners(),

                const SizedBox(height: 0),

                // Card: Para sua edificação
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EdificationCard(onNavigateToTab: onNavigateToTab),
                ),

                const SizedBox(height: 12),

                // Card: Fique por dentro
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StayInformedCard(onNavigateToTab: onNavigateToTab),
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
// WIDGET: Header da Home (Olá, Nome)
// =====================================================

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: SafeArea(
        bottom: false,
        child: currentMemberAsync.when(
          data: (member) {
            final user = Supabase.instance.client.auth.currentUser;
            final displayName =
                member?.nickname ??
                member?.firstName ??
                user?.email?.split('@').first ??
                'Usuário';
            final photoUrl = member?.photoUrl ?? user?.userMetadata?['avatar_url'];

            return Row(
              children: [
                // Avatar com borda branca suave
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Saudação
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Olá,',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600, // Destaque leve
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Notificação
                const NotificationBadge(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card "Feed Espiritual" (Antigo FeelingCard)
// =====================================================

class _SpiritualFeedCard extends StatelessWidget {
  const _SpiritualFeedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20), // Bordas mais arredondadas
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Sombra muito suave
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/community'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Padding vertical reduzido
            child: Row(
              children: [
                // Ícone ilustrativo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), // Fundo suave
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '🙏',
                    style: const TextStyle(fontSize: 28), // Ícone maior
                  ),
                ),
                const SizedBox(width: 20), // Mais espaço
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Como está se sentindo?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, // Fonte mais forte
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Compartilhe ou peça oração',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600], // Subtítulo cinza premium
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Seta
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
        toolbarHeight: 72, // Aumentado para acomodar o perfil
        titleSpacing: 0, // Alinhamento estrito
        title: Padding(
          padding: const EdgeInsets.only(left: 20), // Pequeno ajuste visual
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
                    width: 42,
                    height: 42,
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
                                size: 24,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName, // Apelido ou Primeiro Nome em destaque
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 18, height: 1.1),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          _buildMenuCard(
            context,
            Icons.school_outlined,
            'Cursos',
            '/courses',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.church_outlined,
            'A Igreja',
            '/church-info',
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
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
            Icons.article_outlined,
            'Notícias',
            '/news',
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.groups_outlined,
            'Comunidade',
            '/community',
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.book_outlined,
            'Planos de Leituras',
            '/reading-plans',
            color: Colors.brown,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            Icons.menu_book_outlined,
            'Bíblia',
            '/bible',
            color: Colors.indigo,
          ),

          const SizedBox(height: 32),

          // ADMINISTRATIVO
          ConditionalDashboardAccess(
            builder: (context, canAccess) {
              if (!canAccess) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle(context, 'ADMINISTRATIVO'),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    context,
                    Icons.dashboard_outlined,
                    'Dashboard',
                    '/dashboard',
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),

          // Logout Button
          Container(
            decoration: CommunityDesign.overlayDecoration(
              Theme.of(context).colorScheme,
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
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
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
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
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
      decoration: CommunityDesign.overlayDecoration(cs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CommunityDesign.radius),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ), // Espaçamento interno confortável
            child: Row(
              children: [
                // Ícone Colorido
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: itemColor, size: 22),
                ),
                const SizedBox(width: 16),
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                // Seta
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
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
// WIDGET: Círculos de Atalhos
// =====================================================

class _ShortcutCircles extends ConsumerWidget {
  const _ShortcutCircles();

  /// Abre a rede social da igreja
  Future<void> _launchSocialMedia(
    BuildContext context,
    WidgetRef ref,
    String platform,
  ) async {
    // ... (lógica mantida, simplificada para brevidade neste exemplo se fosse reescrever tudo, 
    // mas vou manter a lógica original e mudar apenas o layout no build)
    final churchInfoAsync = ref.read(churchInfoProvider);

    await churchInfoAsync.when(
      data: (churchInfo) async {
        if (churchInfo == null || churchInfo.socialMedia == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Link de $platform não cadastrado'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        String? url;

        // Buscar URL específica da plataforma
        switch (platform.toLowerCase()) {
          case 'whatsapp':
            final phone = churchInfo.socialMedia!['whatsapp'];
            if (phone != null && phone.isNotEmpty) {
              final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
              final message = Uri.encodeComponent(
                'Olá! Vim através do app Church 360 🙏',
              );
              url = 'https://wa.me/$cleanPhone?text=$message';
            }
            break;
          case 'youtube':
            url = churchInfo.socialMedia!['youtube'];
            break;
          case 'instagram':
            url = churchInfo.socialMedia!['instagram'];
            break;
          case 'facebook':
            url = churchInfo.socialMedia!['facebook'];
            break;
        }

        if (url == null || url.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Link de $platform não cadastrado'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Não foi possível abrir $platform'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      loading: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carregando informações...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      error: (error, stack) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao carregar informações da igreja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShortcutCircle(
            icon: FontAwesomeIcons.whatsapp,
            gradient: const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            label: 'WhatsApp',
            onTap: () => _launchSocialMedia(context, ref, 'whatsapp'),
          ),
          _ShortcutCircle(
            icon: FontAwesomeIcons.youtube,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            label: 'YouTube',
            onTap: () => _launchSocialMedia(context, ref, 'youtube'),
          ),
          _ShortcutCircle(
            icon: FontAwesomeIcons.instagram,
            gradient: const LinearGradient(
              colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            label: 'Instagram',
            onTap: () => _launchSocialMedia(context, ref, 'instagram'),
          ),
          _ShortcutCircle(
            icon: FontAwesomeIcons.facebook,
            gradient: const LinearGradient(
              colors: [Color(0xFF1877F2), Color(0xFF0C63D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            label: 'Facebook',
            onTap: () => _launchSocialMedia(context, ref, 'facebook'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCircle extends StatelessWidget {
  final IconData? icon;
  final Gradient? gradient;
  final String label;
  final VoidCallback onTap;

  const _ShortcutCircle({
    this.icon,
    this.gradient,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: (gradient?.colors.first ?? Colors.black).withValues(alpha: 0.1),
      highlightColor: (gradient?.colors.first ?? Colors.black).withValues(alpha: 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, // Reduzido para 52 (levemente menor e mais elegante)
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: (gradient?.colors.first ?? Colors.black).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: icon != null
                ? Center(child: FaIcon(icon, color: Colors.white, size: 24)) // Ícone ajustado
                : null,
          ),
          const SizedBox(height: 10), // Respiro visual um pouco maior
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), // Texto suavizado
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// WIDGET: Banner Rotativo da Home
// =====================================================

class _HomeBanners extends ConsumerStatefulWidget {
  const _HomeBanners();

  @override
  ConsumerState<_HomeBanners> createState() => _HomeBannersState();
}

class _HomeBannersState extends ConsumerState<_HomeBanners> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  int _totalBanners = 0;

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_totalBanners <= 1) {
      return; // Não faz auto-play se houver apenas 1 banner
    }

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nextPage = (_currentPage + 1) % _totalBanners;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersStreamProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        // Atualizar total de banners e reiniciar auto-play se necessário
        if (_totalBanners != banners.length) {
          _totalBanners = banners.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startAutoPlay();
          });
        }

        return SizedBox(
          height: 240, // Altura aumentada para estilo Hero
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return _HomeBannerCard(banner: banner);
                },
              ),
              // Indicadores de página (dentro do banner)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    banners.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8, // Largura dinâmica
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _HomeBannerCard extends StatelessWidget {
  final HomeBanner banner;

  const _HomeBannerCard({required this.banner});

  void _handleBannerTap(BuildContext context) {
    switch (banner.linkType) {
      case 'event':
        if (banner.linkedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EventDetailScreen(eventId: banner.linkedId!),
            ),
          );
        }
        break;
      case 'reading_plan':
        if (banner.linkedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReadingPlanDetailScreen(planId: banner.linkedId!),
            ),
          );
        }
        break;
      case 'course':
        if (banner.linkedId != null) {
          // Navegar para a lista de cursos por enquanto (até criar a tela de detalhe)
          context.push('/courses');
        }
        break;
      case 'external':
        if (banner.linkUrl != null && banner.linkUrl!.isNotEmpty) {
          // Abrir URL externa (você pode usar url_launcher aqui)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Abrindo: ${banner.linkUrl}')));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChurchImage(
      imageUrl: banner.imageUrl,
      type: ChurchImageType.hero,
      enableOverlay: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleBannerTap(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  banner.title,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (banner.description != null &&
                    banner.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    banner.description!,
                    style: CommunityDesign.contentStyle(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
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
    );
  }
}

// =====================================================
// WIDGET: Card "Para sua edificação"
// =====================================================

class _EdificationCard extends ConsumerStatefulWidget {
  final void Function(int) onNavigateToTab;

  const _EdificationCard({required this.onNavigateToTab});

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
            // Navegar para a aba Devocionais (índice 0)
            widget.onNavigateToTab(0);
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
