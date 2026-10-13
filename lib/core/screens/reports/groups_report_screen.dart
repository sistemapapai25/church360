import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_icons.dart';
import '../../providers/dashboard_stats_provider.dart';
import '../../widgets/glass_card.dart';

/// Tela de relatório de grupos
class GroupsReportScreen extends ConsumerWidget {
  const GroupsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(topActiveGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de Grupos')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topActiveGroupsProvider);
        },
        child: groupsAsync.when(
          data: (groups) {
            if (groups.isEmpty) {
              return const Center(child: Text('Nenhum grupo cadastrado'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final name = group['group_name'] as String;
                final meetingCount = group['meeting_count'] as int;
                const color = Colors.blue;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: const Icon(AppIcons.groupsFilled, color: color),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
