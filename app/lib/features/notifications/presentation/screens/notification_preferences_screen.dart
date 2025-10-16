import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final actions = ref.read(notificationActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferências de Notificações'),
      ),
      body: preferencesAsync.when(
        data: (preferences) {
          if (preferences == null) {
            return const Center(
              child: Text('Erro ao carregar preferências'),
            );
          }

          return ListView(
            children: [
              // Seção: Devocionais
              _SectionHeader(
                icon: Icons.book,
                title: 'Devocionais',
                color: Colors.blue,
              ),
              _PreferenceTile(
                title: 'Devocional Diário',
                subtitle: 'Notificar quando um novo devocional for publicado',
                value: preferences.devotionalDaily,
                onChanged: (value) async {
                  await actions.updatePreferences(devotionalDaily: value);
                },
              ),
              const Divider(),

              // Seção: Pedidos de Oração
              _SectionHeader(
                icon: Icons.favorite,
                title: 'Pedidos de Oração',
                color: Colors.red,
              ),
              _PreferenceTile(
                title: 'Alguém orou por você',
                subtitle: 'Notificar quando alguém orar pelo seu pedido',
                value: preferences.prayerRequestPrayed,
                onChanged: (value) async {
                  await actions.updatePreferences(prayerRequestPrayed: value);
                },
              ),
              _PreferenceTile(
                title: 'Oração respondida',
                subtitle: 'Notificar quando um pedido for marcado como respondido',
                value: preferences.prayerRequestAnswered,
                onChanged: (value) async {
                  await actions.updatePreferences(prayerRequestAnswered: value);
                },
              ),
              const Divider(),

              // Seção: Eventos e Reuniões
              _SectionHeader(
                icon: Icons.event,
                title: 'Eventos e Reuniões',
                color: Colors.green,
              ),
              _PreferenceTile(
                title: 'Lembrete de Evento',
                subtitle: 'Notificar 24 horas antes de um evento',
                value: preferences.eventReminder,
                onChanged: (value) async {
                  await actions.updatePreferences(eventReminder: value);
                },
              ),
              _PreferenceTile(
                title: 'Lembrete de Reunião',
                subtitle: 'Notificar 1 hora antes de uma reunião',
                value: preferences.meetingReminder,
                onChanged: (value) async {
                  await actions.updatePreferences(meetingReminder: value);
                },
              ),
              _PreferenceTile(
                title: 'Lembrete de Culto',
                subtitle: 'Notificar 1 hora antes de um culto',
                value: preferences.worshipReminder,
                onChanged: (value) async {
                  await actions.updatePreferences(worshipReminder: value);
                },
              ),
              const Divider(),

              // Seção: Grupos e Comunidade
              _SectionHeader(
                icon: Icons.group,
                title: 'Grupos e Comunidade',
                color: Colors.purple,
              ),
              _PreferenceTile(
                title: 'Novo membro no grupo',
                subtitle: 'Notificar quando um novo membro entrar no grupo',
                value: preferences.groupNewMember,
                onChanged: (value) async {
                  await actions.updatePreferences(groupNewMember: value);
                },
              ),
              const Divider(),

              // Seção: Financeiro
              _SectionHeader(
                icon: Icons.attach_money,
                title: 'Financeiro',
                color: Colors.orange,
              ),
              _PreferenceTile(
                title: 'Meta financeira atingida',
                subtitle: 'Notificar quando uma meta financeira for atingida',
                value: preferences.financialGoalReached,
                onChanged: (value) async {
                  await actions.updatePreferences(financialGoalReached: value);
                },
              ),
              const Divider(),

              // Seção: Outros
              _SectionHeader(
                icon: Icons.notifications,
                title: 'Outros',
                color: Colors.grey,
              ),
              _PreferenceTile(
                title: 'Aniversários',
                subtitle: 'Notificar sobre aniversários de membros',
                value: preferences.birthdayReminder,
                onChanged: (value) async {
                  await actions.updatePreferences(birthdayReminder: value);
                },
              ),
              _PreferenceTile(
                title: 'Notificações gerais',
                subtitle: 'Notificações gerais da igreja',
                value: preferences.general,
                onChanged: (value) async {
                  await actions.updatePreferences(general: value);
                },
              ),
              const Divider(),

              // Seção: Horário de Silêncio
              _SectionHeader(
                icon: Icons.bedtime,
                title: 'Horário de Silêncio',
                color: Colors.indigo,
              ),
              _PreferenceTile(
                title: 'Ativar horário de silêncio',
                subtitle: 'Não receber notificações em horários específicos',
                value: preferences.quietHoursEnabled,
                onChanged: (value) async {
                  await actions.updatePreferences(quietHoursEnabled: value);
                },
              ),
              
              if (preferences.quietHoursEnabled) ...[
                ListTile(
                  title: const Text('Início'),
                  subtitle: Text(preferences.quietHoursStart ?? '22:00'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(preferences.quietHoursStart?.split(':')[0] ?? '22'),
                        minute: int.parse(preferences.quietHoursStart?.split(':')[1] ?? '00'),
                      ),
                    );
                    if (time != null) {
                      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      await actions.updatePreferences(quietHoursStart: timeString);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Fim'),
                  subtitle: Text(preferences.quietHoursEnd ?? '07:00'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(preferences.quietHoursEnd?.split(':')[0] ?? '7'),
                        minute: int.parse(preferences.quietHoursEnd?.split(':')[1] ?? '00'),
                      ),
                    );
                    if (time != null) {
                      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      await actions.updatePreferences(quietHoursEnd: timeString);
                    }
                  },
                ),
              ],
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
              Text('Erro ao carregar preferências: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget: Cabeçalho de seção
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget: Tile de preferência
class _PreferenceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

