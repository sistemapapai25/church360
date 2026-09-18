import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_tabs.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Uma aba do workspace de um ministério.
///
/// O [builder] só é chamado quando a aba está ativa: com sete abas, montar
/// todas de uma vez dispararia o carregamento de dados de telas que o
/// usuário talvez nunca abra.
class MinistryWorkspaceTab {
  final String label;

  /// Contador opcional ao lado do rótulo (texto livre, como em [AppTab]).
  final String? count;

  final WidgetBuilder builder;

  const MinistryWorkspaceTab({
    required this.label,
    this.count,
    required this.builder,
  });
}

/// Um indicador da linha logo abaixo do título.
class MinistryWorkspaceStat {
  final String label;
  final String value;
  final IconData icon;

  const MinistryWorkspaceStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

/// Esqueleto do "app dentro do app" de um ministério: cabeçalho com o nome,
/// linha de indicadores, barra de sub-abas e o corpo da aba ativa.
///
/// É genérico de propósito. O que faz do Batismo um módulo próprio são as
/// abas que a tela dele passa aqui; Raízes e Diaconato, ao migrar, trocam
/// só essa lista. Nada aqui conhece batismo.
class MinistryWorkspaceShell extends ConsumerStatefulWidget {
  final String ministryId;

  /// Título usado enquanto o ministério carrega, ou se ele não for
  /// encontrado. Não é o nome exibido no caso normal — esse vem do banco.
  final String fallbackTitle;

  final List<MinistryWorkspaceTab> tabs;
  final List<MinistryWorkspaceStat> stats;
  final int initialIndex;

  const MinistryWorkspaceShell({
    super.key,
    required this.ministryId,
    required this.fallbackTitle,
    required this.tabs,
    this.stats = const [],
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MinistryWorkspaceShell> createState() =>
      _MinistryWorkspaceShellState();
}

class _MinistryWorkspaceShellState
    extends ConsumerState<MinistryWorkspaceShell> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex.clamp(0, widget.tabs.length - 1);
  }

  @override
  void didUpdateWidget(MinistryWorkspaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A lista de abas pode encurtar entre builds (uma aba que depende de
    // permissão, por exemplo). Sem isto o índice guardado apontaria para
    // fora da lista e o build estouraria.
    if (_selected >= widget.tabs.length) {
      _selected = widget.tabs.isEmpty ? 0 : widget.tabs.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ministryAsync = ref.watch(ministryByIdProvider(widget.ministryId));
    final name = ministryAsync.maybeWhen(
      data: (m) => m?.name ?? widget.fallbackTitle,
      orElse: () => widget.fallbackTitle,
    );

    final tabs = widget.tabs;
    final active = tabs.isEmpty ? null : tabs[_selected];

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkspaceTitle(name: name),
                if (widget.stats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StatsRow(stats: widget.stats),
                ],
                const SizedBox(height: 16),
                AppTabs(
                  tabs: [
                    for (final tab in tabs)
                      AppTab(label: tab.label, count: tab.count),
                  ],
                  selectedIndex: _selected,
                  onChanged: (i) => setState(() => _selected = i),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: active == null
                ? const SizedBox.shrink()
                : KeyedSubtree(
                    key: ValueKey(active.label),
                    child: active.builder(context),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Nome do ministério com a última palavra em destaque (itálico, `primary`),
/// como no desenho de referência.
///
/// Só destaca quando há mais de uma palavra: em "Raízes" o destaque cairia
/// sobre o nome inteiro e viraria ruído.
class _WorkspaceTitle extends StatelessWidget {
  final String name;

  const _WorkspaceTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final base = CommunityDesign.titleStyle(context).copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return Text(name, style: base);
    }

    final head = words.sublist(0, words.length - 1).join(' ');
    final tail = words.last;

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: '$head '),
          TextSpan(
            text: tail,
            style: base.copyWith(
              color: accent,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<MinistryWorkspaceStat> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    // Wrap, não Row: com quatro indicadores a linha não cabe em 360px e o
    // Row estouraria — foi exatamente o que aconteceu na barra de filtros
    // da Etapa 3.
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final stat in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stat.icon, size: 15, color: muted),
              const SizedBox(width: 6),
              Text(
                stat.value,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(stat.label, style: CommunityDesign.metaStyle(context)),
            ],
          ),
      ],
    );
  }
}
