import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/dashboard_widget.dart';
import '../providers/dashboard_widget_provider.dart';

/// Tela de gerenciamento pessoal do Dashboard (CHU-308).
///
/// Diferente de [DashboardSettingsScreen] (`/dashboard-settings`), que é
/// restrita a quem tem `dashboard.configure` e liga/desliga widgets pro
/// tenant inteiro, esta tela é aberta pra qualquer usuário com acesso ao
/// Dashboard e só afeta a preferência pessoal dele — nunca lista um widget
/// que ele não tem permissão de ver ([myDashboardWidgetSettingsProvider]).
class UserDashboardSettingsScreen extends ConsumerWidget {
  const UserDashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(myDashboardWidgetSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Dashboard'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum card disponível para o seu perfil no momento.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Escolha quais cards aparecem no seu Dashboard, dentre '
                        'os que você tem permissão de ver.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final (widget, isVisible) in settings)
                _buildWidgetTile(context, ref, widget, isVisible),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildWidgetTile(
    BuildContext context,
    WidgetRef ref,
    DashboardWidget widget,
    bool isVisible,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        title: Text(
          widget.widgetName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: widget.description != null ? Text(widget.description!) : null,
        value: isVisible,
        onChanged: (value) => _toggleWidget(context, ref, widget.widgetKey, value),
      ),
    );
  }

  Future<void> _toggleWidget(
    BuildContext context,
    WidgetRef ref,
    String widgetKey,
    bool isVisible,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final setVisibility = ref.read(setMyDashboardWidgetVisibilityProvider);
      await setVisibility(widgetKey: widgetKey, isVisible: isVisible);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
