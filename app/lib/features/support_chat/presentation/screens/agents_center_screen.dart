import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/support_agent.dart';
import '../providers/agents_providers.dart';
import '../widgets/universal_support_chat.dart';

class AgentsCenterScreen extends ConsumerWidget {
  const AgentsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAgentsAsync = ref.watch(visibleAgentsForCurrentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentes IA'),
      ),
      body: visibleAgentsAsync.when(
        data: (agents) {
          // Show all agents regardless of ID validity (backend handles fallbacks)
          final visible = agents;

          if (visible.isEmpty) {
            return const Center(
              child: Text('Nenhum agente disponível para você.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final agent = visible[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: _buildAvatar(agent),
                  title: Text(agent.name),
                  subtitle: Text(agent.subtitle ?? agent.role),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UniversalSupportChat(
                          agentKey: agent.key,
                          accentColor: agent.themeColor,
                          showAppBar: true,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Erro ao carregar agentes: $err'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(visibleAgentsForCurrentUserProvider);
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(ResolvedAgent agent) {
    final avatarUrl = agent.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      backgroundColor: agent.themeColor.withValues(alpha: 0.15),
      child: Icon(agent.icon, color: agent.themeColor),
    );
  }
}
