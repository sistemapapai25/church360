import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/financial/presentation/screens/financial_screen.dart';
import '../../features/devotionals/presentation/screens/devotionals_list_screen.dart';
import '../../features/notifications/presentation/widgets/notification_badge.dart';
import '../../features/testimonies/presentation/providers/testimony_provider.dart';

/// Tela principal do app com navegação por abas fixas
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 2; // Inicia no Home (Dashboard)

  // Abas fixas do app
  final List<Widget> _screens = [
    const DevotionalsListScreen(), // Palavras (Devocionais)
    const EventsListScreen(), // Eventos
    const _DashboardTab(), // Home (Dashboard)
    const FinancialScreen(), // Contribua
    const _MoreTab(), // Mais (Menu)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            label: 'Palavras',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Eventos',
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
    );
  }
}

/// Tab Home - Mural do app com eventos, cultos e informações úteis
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Usuário';

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
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
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
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
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
                        child: user?.userMetadata?['avatar_url'] != null
                            ? Image.network(
                                user!.userMetadata!['avatar_url'],
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                    // Ícone de notificação
                    const NotificationBadge(),
                  ],
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

            // Conteúdo do mural (vamos construir aos poucos)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Mural em construção...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
      // TODO: Adicionar campos is_public e allow_whatsapp_contact no repository de prayer_requests
      // Por enquanto, vamos usar o repository existente
      final supabase = Supabase.instance.client;
      await supabase.from('prayer_requests').insert({
        'title': 'Pedido de Oração',
        'description': _descriptionController.text.trim(),
        'category': 'personal',
        'privacy': _isPublic ? 'public' : 'private',
        'is_public': _isPublic,
        'allow_whatsapp_contact': _allowWhatsappContact,
        'author_id': supabase.auth.currentUser!.id,
      });

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
// TODO: Criar tela separada de Dashboard com todos os cards e gráficos
// =====================================================

/// Tab "Mais" - Menu com todas as opções (versão mobile)
class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mais Opções'),
        actions: const [
          NotificationBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.church,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Church 360',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                            ),
                      ),
                    ],
                  ),
                ),

                // Menu items (mobile)
                const SizedBox(height: 16),

                // VISÃO GERAL
                _buildMobileSection(context, 'VISÃO GERAL'),
                _buildMobileMenuItem(context, Icons.dashboard, 'Dashboard', '/dashboard'),

                const Divider(),
                _buildMobileSection(context, 'GESTÃO'),
                _buildMobileMenuItem(context, Icons.people, 'Membros', '/members'),
                _buildMobileMenuItem(context, Icons.person_add, 'Visitantes', '/visitors'),

                const Divider(),
                _buildMobileSection(context, 'MINISTÉRIO'),
                _buildMobileMenuItem(context, Icons.church, 'Ministérios', '/ministries'),
                _buildMobileMenuItem(context, Icons.groups, 'Grupos de Comunhão', '/groups'),
                _buildMobileMenuItem(context, Icons.menu_book, 'Grupos de Estudo', '/study-groups'),
                _buildMobileMenuItem(context, Icons.church_outlined, 'Cultos', '/worship'),

                const Divider(),
                _buildMobileSection(context, 'ATIVIDADES'),
                _buildMobileMenuItem(context, Icons.favorite, 'Pedidos de Oração', '/prayer-requests'),

                const Divider(),
                _buildMobileSection(context, 'RELATÓRIOS'),
                _buildMobileMenuItem(context, Icons.analytics, 'Analytics & Relatórios', '/analytics'),

                const Divider(),
                _buildMobileSection(context, 'CONFIGURAÇÕES'),
                _buildMobileMenuItem(context, Icons.label, 'Tags', '/tags'),
                _buildMobileMenuItem(context, Icons.notifications, 'Notificações', '/notifications'),

                const Divider(),

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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
