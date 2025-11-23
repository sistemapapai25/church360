import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../features/permissions/presentation/widgets/dashboard_access_gate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/prayer_requests/presentation/providers/prayer_request_provider.dart';
import '../../features/prayer_requests/domain/models/prayer_request.dart';
import '../../features/contribution/presentation/screens/contribution_info_screen.dart';
import '../../features/devotionals/presentation/screens/devotionals_list_screen.dart';
import '../screens/agenda_tab_screen.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/testimonies/presentation/providers/testimony_provider.dart';
import '../../features/events/presentation/providers/events_provider.dart';
import '../../features/events/domain/models/event.dart';
import '../../features/devotionals/presentation/providers/devotional_provider.dart';
import '../../features/devotionals/domain/models/devotional.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/home_content/presentation/providers/banners_provider.dart';
import '../../features/home_content/domain/models/banner.dart';
import '../../features/reading_plans/presentation/screens/reading_plan_detail_screen.dart';
import '../../features/church_info/presentation/providers/church_info_provider.dart';

/// Tela principal do app com navegação por abas fixas
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 2; // Inicia no Home (Dashboard)

  // Método para navegar para uma aba específica
  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Se não estiver na aba Home, navegar para a aba Home
        if (_selectedIndex != 2) {
          setState(() {
            _selectedIndex = 2; // Ir para aba Home
          });
        } else {
          // Se já estiver na aba Home, sair do app
          // Você pode adicionar um diálogo de confirmação aqui se quiser
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: 'Devocionais',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'Contribua',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'Mais',
            ),
          ],
        ),
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
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Nome do APP/Igreja (discreto e centralizado)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Church 360',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
              ),
            ),

            // Header com foto, saudação e nome
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: currentMemberAsync.when(
                  data: (member) {
                    final user = Supabase.instance.client.auth.currentUser;
                    // Usa apelido se existir, senão usa primeiro nome
                    final displayName = member?.nickname ?? member?.firstName ?? user?.email?.split('@').first ?? 'Usuário';
                    final photoUrl = member?.photoUrl ?? user?.userMetadata?['avatar_url'];

                    return Row(
                      children: [
                        // Foto do usuário em círculo
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Theme.of(context).colorScheme.primary,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 32,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Saudação e nome
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá,',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                              ),
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Ícone de notificação
                        const NotificationBadge(),
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
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá,',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                            ),
                            Text(
                              'Carregando...',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBadge(),
                    ],
                  ),
                  error: (_, __) {
                    final user = Supabase.instance.client.auth.currentUser;
                    final userName = user?.email?.split('@').first ?? 'Usuário';

                    return Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá,',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                              ),
                              Text(
                                userName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const NotificationBadge(),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Card: Como está se sentindo hoje?
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _FeelingCard(),
              ),
            ),

            // Círculos de atalhos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ShortcutCircles(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Banner rotativo da home
            SliverToBoxAdapter(
              child: _HomeBanners(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Card: Para sua edificação
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EdificationCard(onNavigateToTab: onNavigateToTab),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Card: Fique por dentro
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StayInformedCard(onNavigateToTab: onNavigateToTab),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card "Como está se sentindo hoje?"
// =====================================================

class _FeelingCard extends StatelessWidget {
  const _FeelingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showFeelingDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Emoji
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '😊',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Text(
                  'Como está se sentindo hoje?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              // Ícone de seta
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeelingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _FeelingDialog(),
    );
  }
}

// =====================================================
// DIALOG: Escolher entre Testemunho ou Pedido de Oração
// =====================================================

class _FeelingDialog extends StatelessWidget {
  const _FeelingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Como você está se sentindo?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Opção 1: Testemunhar
          _FeelingOption(
            emoji: '😇',
            title: 'Gostaria de Testemunhar',
            onTap: () {
              Navigator.of(context).pop();
              _showTestimonyForm(context);
            },
          ),
          const SizedBox(height: 12),
          // Opção 2: Pedir Oração
          _FeelingOption(
            emoji: '😢',
            title: 'Gostaria de Pedir Oração',
            onTap: () {
              Navigator.of(context).pop();
              _showPrayerRequestForm(context);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  void _showTestimonyForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _TestimonyFormDialog(),
    );
  }

  void _showPrayerRequestForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PrayerRequestFormDialog(),
    );
  }
}

// =====================================================
// WIDGET: Opção do Dialog
// =====================================================

class _FeelingOption extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;

  const _FeelingOption({
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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

// =====================================================
// DIALOG: Formulário de Testemunho
// =====================================================

class _TestimonyFormDialog extends ConsumerStatefulWidget {
  const _TestimonyFormDialog();

  @override
  ConsumerState<_TestimonyFormDialog> createState() => _TestimonyFormDialogState();
}

class _TestimonyFormDialogState extends ConsumerState<_TestimonyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isPublic = false; // Desativado por padrão
  bool _allowWhatsappContact = true; // Ativado por padrão
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(testimonyActionsProvider);
      await actions.createTestimony(
        title: 'Testemunho',
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
        allowWhatsappContact: _allowWhatsappContact,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Testemunho compartilhado com sucesso! 🙏'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar testemunho: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('😇', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Gostaria de testemunhar?')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mensagem
              Text(
                'Obrigado por compartilhar! Vamos celebrar juntos! Se desejar, compartilhe seu testemunho e inspire a fé de outros irmãos em Cristo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // Campo de texto
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Conta aqui...',
                  hintText: 'Compartilhe seu testemunho',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                textAlignVertical: TextAlignVertical.top,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, compartilhe seu testemunho';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Checkbox: Permitir contato via WhatsApp
              CheckboxListTile(
                value: _allowWhatsappContact,
                onChanged: (value) => setState(() => _allowWhatsappContact = value ?? true),
                title: const Text('Permitir contato via WhatsApp'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              // Checkbox: Permitir que seja público
              CheckboxListTile(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value ?? false),
                title: const Text('Permitir que meu testemunho seja Público'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Não, obrigado'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}

// =====================================================
// DIALOG: Formulário de Pedido de Oração
// =====================================================

class _PrayerRequestFormDialog extends ConsumerStatefulWidget {
  const _PrayerRequestFormDialog();

  @override
  ConsumerState<_PrayerRequestFormDialog> createState() => _PrayerRequestFormDialogState();
}

class _PrayerRequestFormDialogState extends ConsumerState<_PrayerRequestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isPublic = false; // Desativado por padrão
  bool _allowWhatsappContact = true; // Ativado por padrão
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = PrayerRequestActions.fromWidgetRef(ref);
      await actions.createPrayerRequest(
        title: 'Pedido de Oração',
        description: _descriptionController.text.trim(),
        category: PrayerCategory.personal,
        privacy: _isPublic ? PrayerPrivacy.public : PrayerPrivacy.private,
        isPublic: _isPublic,
        allowWhatsappContact: _allowWhatsappContact,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido de oração enviado! Vamos orar por você! 🙏'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('😢', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Pedido de oração')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mensagem
              Text(
                'Obrigado por compartilhar! Vamos orar juntos! Se desejar, compartilhe seu pedido de oração para que possamos interceder por você como família e corpo de Cristo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // Campo de texto
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Conta aqui...',
                  hintText: 'Compartilhe seu pedido de oração',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                textAlignVertical: TextAlignVertical.top,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, compartilhe seu pedido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Checkbox: Permitir contato via WhatsApp
              CheckboxListTile(
                value: _allowWhatsappContact,
                onChanged: (value) => setState(() => _allowWhatsappContact = value ?? true),
                title: const Text('Permitir contato via WhatsApp'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              // Checkbox: Permitir que seja público
              CheckboxListTile(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value ?? false),
                title: const Text('Permitir que meu pedido de oração seja Público'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Não, obrigado'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
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
      appBar: AppBar(
        title: const Text('Menu mais'),
        actions: const [
          NotificationBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header com foto e nome do usuário (igual ao da aba Home)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: currentMemberAsync.when(
              data: (member) {
                final user = Supabase.instance.client.auth.currentUser;
                final userName = member?.fullName ?? user?.email?.split('@').first ?? 'Usuário';
                final photoUrl = member?.photoUrl ?? user?.userMetadata?['avatar_url'];

                return Row(
                  children: [
                    // Foto do perfil (igual ao da aba Home)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 32,
                                    color: Theme.of(context).colorScheme.primary,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nome do usuário (sem saudação)
                    Expanded(
                      child: Text(
                        userName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Carregando...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              error: (_, __) {
                final user = Supabase.instance.client.auth.currentUser;
                final userName = user?.email?.split('@').first ?? 'Usuário';

                return Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Ver meu perfil (separado)
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Ver meu perfil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/profile');
            },
          ),

          const Divider(),

          // VISÃO GERAL - Itens principais do app
          _buildMobileSection(context, 'VISÃO GERAL'),
          _buildMobileMenuItem(context, Icons.school, 'Cursos', '/courses'),
          _buildMobileMenuItem(context, Icons.church, 'A Igreja', '/church-info'),
          _buildMobileMenuItem(context, Icons.child_care, 'Inscrição Kids', '/kids-registration'),
          _buildMobileMenuItem(context, Icons.article, 'Notícias', '/news'),
          _buildMobileMenuItem(context, Icons.groups, 'Comunidade', '/community'),
          _buildMobileMenuItem(context, Icons.book, 'Planos de Leituras', '/reading-plans'),
          _buildMobileMenuItem(context, Icons.menu_book, 'Bíblia', '/bible'),
          _buildMobileMenuItem(context, Icons.share, 'Compartilhar', '/share'),
          _buildMobileMenuItem(context, Icons.contact_support, 'Contato', '/contact'),

          const Divider(),

          // ADMINISTRATIVO
          // No Web, sempre exibir o item de Dashboard no menu "Mais"
          // Em outras plataformas, manter o comportamento condicional por permissão
          if (kIsWeb) ...[
            _buildMobileSection(context, 'ADMINISTRATIVO'),
            _buildMobileMenuItem(context, Icons.dashboard, 'Dashboard', '/dashboard'),
            const Divider(),
          ] else
            ConditionalDashboardAccess(
              builder: (context, canAccess) {
                if (!canAccess) return const SizedBox.shrink();

                return Column(
                  children: [
                    _buildMobileSection(context, 'ADMINISTRATIVO'),
                    DashboardMenuItem(
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      onTap: () => context.go('/dashboard'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
          _buildMobileSection(context, 'CONFIGURAÇÕES'),
          _buildMobileMenuItem(context, Icons.label, 'Tags', '/tags'),
          _buildMobileMenuItem(context, Icons.notifications, 'Notificações', '/notifications'),

          const Divider(height: 32),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Sair',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
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
          ),

          const SizedBox(height: 16),

          // Versão
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Church 360 v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildMobileMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.go(route);
      },
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
              // Remover caracteres não numéricos
              final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
              // Mensagem inicial personalizada
              final message = Uri.encodeComponent('Olá! Vim através do app Church 360 🙏');
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

        // Tentar abrir a URL
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: icon != null
                ? Center(
                    child: FaIcon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    height: 1.2,
                  ),
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
    if (_totalBanners <= 1) return; // Não faz auto-play se houver apenas 1 banner

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

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
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
            ),
            const SizedBox(height: 12),
            // Indicadores de página
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                banners.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ],
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
              builder: (context) => EventDetailScreen(eventId: banner.linkedId!),
            ),
          );
        }
        break;
      case 'reading_plan':
        if (banner.linkedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingPlanDetailScreen(planId: banner.linkedId!),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abrindo: ${banner.linkUrl}')),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => _handleBannerTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: NetworkImage(banner.imageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.3),
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  banner.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (banner.description != null && banner.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    banner.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Para sua edificação',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isExpanded ? 'OCULTAR' : 'EXPANDIR',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            devotionalsAsync.when(
              data: (devotionals) {
                if (devotionals.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Nenhum devocional disponível no momento.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  );
                }

                // Pegar até 4 devocionais mais recentes
                final recentDevotionals = devotionals.take(4).toList();

                return Column(
                  children: [
                    // Grid 2x2 de devocionais
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: recentDevotionals.length,
                        itemBuilder: (context, index) {
                          return _DevotionalGridCard(devotional: recentDevotionals[index]);
                        },
                      ),
                    ),
                    // Botão "VER TODOS"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Navegar para a aba Palavras (índice 0)
                            widget.onNavigateToTab(0);
                          },
                          child: const Text('VER TODOS'),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Erro ao carregar devocionais.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
            ),
        ],
      ),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fique por dentro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isExpanded ? 'OCULTAR' : 'EXPANDIR',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Nenhum evento disponível no momento.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  );
                }

                // Pegar apenas os primeiros 4 eventos
                final displayEvents = events.take(4).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: displayEvents.length,
                        itemBuilder: (context, index) {
                          final event = displayEvents[index];
                          return _EventGridCard(event: event);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Navegar para a aba Eventos (índice 1)
                            widget.onNavigateToTab(1);
                          },
                          child: const Text('VER TODOS'),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Erro ao carregar eventos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================
// WIDGET: Card de Devocional no Grid
// =====================================================

class _DevotionalGridCard extends StatelessWidget {
  final Devotional devotional;

  const _DevotionalGridCard({required this.devotional});

  @override
  Widget build(BuildContext context) {
    // Determinar qual imagem usar (imageUrl ou thumbnail do YouTube)
    String? imageUrl = devotional.imageUrl;
    final bool hasImage = imageUrl != null || devotional.hasYoutubeVideo;

    // Se não tiver imageUrl mas tiver YouTube, usar thumbnail
    if (imageUrl == null && devotional.hasYoutubeVideo) {
      final videoId = YoutubePlayer.convertUrlToId(devotional.youtubeUrl!);
      if (videoId != null) {
        imageUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }

    return InkWell(
      onTap: () {
        context.push('/devotionals/${devotional.id}');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.tertiaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ícone de livro ou vídeo
              Icon(
                devotional.hasYoutubeVideo ? Icons.video_library : Icons.book,
                color: hasImage
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              // Título do devocional
              Text(
                devotional.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: hasImage ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card de Evento no Grid
// =====================================================

class _EventGridCard extends StatelessWidget {
  final Event event;

  const _EventGridCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventId: event.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: event.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(event.imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                event.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: event.imageUrl != null ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
