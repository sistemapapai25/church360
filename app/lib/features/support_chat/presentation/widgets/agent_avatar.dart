import 'package:flutter/material.dart';

import '../../domain/models/support_agent.dart';

class AgentAvatar extends StatelessWidget {
  final ResolvedAgent agent;
  final double size;

  const AgentAvatar({
    super.key,
    required this.agent,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = agent.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.grey.shade200,
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: agent.themeColor.withValues(alpha: 0.15),
      child: Icon(
        agent.icon,
        size: size * 0.6,
        color: agent.themeColor,
      ),
    );
  }
}

