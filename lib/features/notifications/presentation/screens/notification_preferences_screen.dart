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
              // Só as chaves que têm quem gere aviso. Devocional, oração,
              // reunião, culto, grupo, meta financeira e aniversário nunca
              // tiveram gerador (backend-scripts/176a) e saíram da tela.
              _SectionHeader(
                icon: Icons.event,
                title: 'Eventos',
                color: Colors.green,
              ),
              // Fase 4 — NOTIF-01 (D-04): anúncio e lembrete são preferências
              // independentes, em colunas distintas. Quem quer saber de evento
              // novo sem ser lembrado antes (ou o contrário) consegue.
              _PreferenceTile(
                title: 'Anúncio de novo evento',
                subtitle:
                    'Avisar quando um evento for publicado, se você puder vê-lo',
                value: preferences.eventAnnouncement,
                onChanged: (value) async {
                  await actions.updatePreferences(eventAnnouncement: value);
                },
              ),
              // Fase 4 — D-02/D-03: o texto não promete offset fixo. O
              // responsável cadastra quantos lembretes quiser no evento, ou
              // nenhum; a preferência só liga/desliga o recebimento.
              _PreferenceTile(
                title: 'Lembrete de Evento',
                subtitle:
                    'Receber os lembretes configurados no evento antes da data',
                value: preferences.eventReminder,
                onChanged: (value) async {
                  await actions.updatePreferences(eventReminder: value);
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
                title: 'Notificações gerais',
                subtitle: 'Notificações gerais da igreja',
                value: preferences.general,
                onChanged: (value) async {
                  await actions.updatePreferences(general: value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phonelink_ring),
                title: const Text('Registrar push neste dispositivo'),
                subtitle: const Text(
                  'Solicita permissao e sincroniza token FCM no backend',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final result = await actions.registerCurrentDeviceForPush();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? Colors.green : Colors.orange,
                    ),
                  );
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
