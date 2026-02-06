import 'package:flutter/material.dart';

import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../design/community_design.dart';

/// Tela de Agenda com tabs para Próximos Eventos e Calendário
class AgendaTabScreen extends StatefulWidget {
  const AgendaTabScreen({super.key});

  @override
  State<AgendaTabScreen> createState() => _AgendaTabScreenState();
}

class _AgendaTabScreenState extends State<AgendaTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false, // Remove botão de voltar
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.calendar_month,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Agenda', style: CommunityDesign.titleStyle(context)),
                Text(
                  'Sua programação',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Próximos Eventos'),
            Tab(text: 'Calendário'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Próximos Eventos
          _EventsTabContent(),
          // Tab 2: Agenda (Calendário)
          _ScheduleTabContent(),
        ],
      ),
    );
  }
}

/// Conteúdo da tab de Próximos Eventos
class _EventsTabContent extends StatelessWidget {
  const _EventsTabContent();

  @override
  Widget build(BuildContext context) {
    // Usa a tela de eventos existente, mas sem AppBar e sem CRUD (apenas visualização)
    return const EventsListScreen(showAppBar: false, enableCrud: false);
  }
}

/// Conteúdo da tab de Agenda (Calendário)
class _ScheduleTabContent extends StatelessWidget {
  const _ScheduleTabContent();

  @override
  Widget build(BuildContext context) {
    // Usa a tela de agenda existente, mas sem AppBar
    return const ScheduleScreen(showAppBar: false);
  }
}
