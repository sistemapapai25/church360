import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_stats_provider.dart';

/// Tela de relatório de grupos
class GroupsReportScreen extends ConsumerWidget {
  const GroupsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(topActiveGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Grupos'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topActiveGroupsProvider);
        },
        child: groupsAsync.when(
          data: (groups) {
            if (groups.isEmpty) {
              return const Center(
                child: Text('Nenhum grupo cadastrado'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final name = group['name'] as String;
                final meetingCount = group['meeting_count'] as int;
                final type = group['type'] as String?;

                // Determinar ícone e cor baseado no tipo
                IconData icon;
                Color color;
                String typeLabel;

                switch (type) {
                  case 'communion':
                    icon = Icons.groups;
                    color = Colors.blue;
                    typeLabel = 'Comunhão';
                    break;
                  case 'study':
                    icon = Icons.menu_book;
                    color = Colors.green;
                    typeLabel = 'Estudo';
                    break;
                  case 'ministry':
                    icon = Icons.volunteer_activism;
                    color = Colors.purple;
                    typeLabel = 'Ministério';
                    break;
                  default:
                    icon = Icons.group;
                    color = Colors.grey;
                    typeLabel = 'Outro';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(typeLabel),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$meetingCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          meetingCount == 1 ? 'reunião' : 'reuniões',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        ),
      ),
    );
  }
}

