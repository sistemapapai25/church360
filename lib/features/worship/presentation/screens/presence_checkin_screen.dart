import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../widgets/presence_reaction_panel.dart';

/// `/presenca`: aberta pelo aviso "Chegou bem? / O que está achando do
/// culto?". O miolo é o [PresenceReactionPanel], o mesmo que entra no bloco
/// do culto na Home.
class PresenceCheckinScreen extends StatelessWidget {
  const PresenceCheckinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Bom culto!'),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: const PresenceReactionPanel(),
            ),
          ),
        ),
      ),
    );
  }
}
