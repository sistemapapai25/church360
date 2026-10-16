import 'package:flutter/material.dart';

import '../../core/widgets/app_tabs.dart';
import '../devotionals/presentation/screens/devotionals_list_screen.dart';
import '../reading_plans/presentation/screens/reading_plans_list_screen.dart';

/// C3 (roadmap Home/culto/Dashboard de 14/10/2026): Devocionais e Planos de
/// leitura numa tela só. `/devotionals` e `/reading-plans` redirecionam para
/// cá; cada aba é a tela de sempre, com as abas no rodapé do cabeçalho.
class EdificacaoScreen extends StatefulWidget {
  const EdificacaoScreen({super.key, this.initialTab = 0});

  /// 0 = Devocionais, 1 = Planos.
  final int initialTab;

  @override
  State<EdificacaoScreen> createState() => _EdificacaoScreenState();
}

class _EdificacaoScreenState extends State<EdificacaoScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final tabs = PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: AppTabs(
          tabs: const [AppTab(label: 'Devocionais'), AppTab(label: 'Planos')],
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
    return _tab == 0
        ? DevotionalsListScreen(tabs: tabs)
        : ReadingPlansListScreen(tabs: tabs);
  }
}
