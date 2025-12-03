import 'package:flutter/material.dart';

import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';

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
      appBar: AppBar(
        title: const Text('Agenda'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove botão de voltar
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Próximos Eventos'),
            Tab(text: 'Agenda'),
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
    return const EventsListScreen(
      showAppBar: false,
      enableCrud: false,
    );
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

