import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/design/app_icons.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_tabs.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../domain/models/ministry.dart';
import '../../domain/ministry_type_catalog.dart';
import '../../../notifications/presentation/screens/ministry_notification_config_screen.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../presentation/utils/ministry_visuals.dart';

/// Uma aba do workspace de um ministério.
///
/// O [builder] só é chamado quando a aba está ativa: com oito abas, montar
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

/// O que uma tela sabe montar para uma chave de aba do catálogo.
///
/// A tela declara os widgets que tem; o catálogo (`public.ministry_type`)
/// decide quais entram, em que ordem e com que rótulo. Ver
/// [ministryTabsFromCatalog].
class MinistryTabSlot {
  /// Rótulo usado quando o catálogo não tem o que dizer sobre este tipo.
  final String defaultLabel;

  final String? count;
  final WidgetBuilder builder;

  const MinistryTabSlot({
    required this.defaultLabel,
    this.count,
    required this.builder,
  });
}

/// Monta a lista de abas cruzando o que a tela sabe construir ([slots]) com o
/// que o catálogo manda para [typeCode].
///
/// As duas falhas possíveis têm saída pelo lado seguro:
///
/// - **tipo fora do catálogo** (ou catálogo que não chegou): usa todos os
///   slots, na ordem em que a tela os declarou. É exatamente o comportamento
///   de antes da Fase 2;
/// - **chave que o app não conhece**: ignorada. Uma aba sem widget nasceria
///   vazia, e uma tela com aba vazia é pior que uma aba a menos.
///
/// O caso que **não** tem rede é o inverso: chave que a tela tem e o catálogo
/// não lista sai da tela. É o preço de o catálogo mandar de verdade, e é por
/// isso que a tabela só muda por migration e que o fallback embutido é travado
/// por teste. Em debug, cada slot descartado vira aviso no console.
List<MinistryWorkspaceTab> ministryTabsFromCatalog({
  required MinistryTypeCatalog catalog,
  required String typeCode,
  required Map<String, MinistryTabSlot> slots,
}) {
  List<MinistryWorkspaceTab> allSlots() => [
    for (final entry in slots.entries)
      MinistryWorkspaceTab(
        label: entry.value.defaultLabel,
        count: entry.value.count,
        builder: entry.value.builder,
      ),
  ];

  final spec = catalog.specFor(typeCode);
  if (spec == null || spec.tabs.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'ministry_type: tipo "$typeCode" não está no catálogo; '
        'a tela usou as abas que ela mesma declara.',
      );
    }
    return allSlots();
  }

  final used = <String>{};
  final tabs = <MinistryWorkspaceTab>[];
  for (final tab in spec.tabs) {
    final slot = slots[tab.key];
    if (slot == null) {
      if (kDebugMode) {
        debugPrint(
          'ministry_type[$typeCode]: aba "${tab.key}" está no catálogo mas '
          'não tem widget registrado nesta tela — ignorada.',
        );
      }
      continue;
    }
    used.add(tab.key);
    tabs.add(
      MinistryWorkspaceTab(
        label: tab.label,
        count: slot.count,
        builder: slot.builder,
      ),
    );
  }

  if (kDebugMode) {
    for (final key in slots.keys) {
      if (!used.contains(key)) {
        debugPrint(
          'ministry_type[$typeCode]: a tela sabe montar a aba "$key", mas o '
          'catálogo não a lista — ela não vai aparecer.',
        );
      }
    }
  }

  // Catálogo que não casou com nada (todas as chaves desconhecidas) deixaria a
  // tela sem aba nenhuma. Nesse caso a tela ganha de volta o que ela declara.
  if (tabs.isEmpty) return allSlots();

  return tabs;
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

/// Esqueleto do "app dentro do app" de um ministério: cabeçalho com ícone,
/// nome e descrição, linha de indicadores, barra de sub-abas e o corpo da
/// aba ativa.
///
/// É genérico de propósito. O que faz do Batismo um módulo próprio são as
/// abas que a tela dele passa aqui; Raízes e Diaconato, ao migrar, trocam
/// só essa lista. Nada aqui conhece batismo.
///
/// O nome fica na barra de navegação, ao lado do voltar, com o ícone do
/// ministério à frente — é a linha mais alta da tela, e é dela que a pessoa
/// lê onde está. A descrição e os indicadores vêm abaixo, e a barra de abas
/// ocupa a largura toda, com a engrenagem de edição fechando a trilha.
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

  void _openNotifications(String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MinistryNotificationConfigScreen(
          ministryId: widget.ministryId,
          ministryName: name,
        ),
      ),
    );
  }

  void _openEdit() => context.push('/ministries/${widget.ministryId}/edit');

  @override
  Widget build(BuildContext context) {
    final ministryAsync = ref.watch(ministryByIdProvider(widget.ministryId));
    final ministry = ministryAsync.maybeWhen(
      data: (m) => m,
      orElse: () => null,
    );
    final name = ministry?.name ?? widget.fallbackTitle;
    final description = ministry?.description?.trim();

    // Notificações e edição eram as duas ações que só existiam na ficha, e
    // lá as duas pediam `ministries.edit`. A régua continua a mesma para
    // não abrir no workspace quem a ficha bloqueava.
    final canEdit = ref
        .watch(currentUserHasPermissionProvider('ministries.edit'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    final tabs = widget.tabs;
    final active = tabs.isEmpty ? null : tabs[_selected];
    final headerColor = CommunityDesign.headerColor(context);
    final hasDescription = description != null && description.isNotEmpty;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        // Sem respiro entre o voltar e o título: o nome do ministério começa
        // colado no botão, e não no meio da barra.
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            _MinistryGlyph(ministry: ministry),
            const SizedBox(width: 10),
            Expanded(child: _WorkspaceTitle(name: name)),
          ],
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(AppIcons.notificationsActive),
              tooltip: 'Notificações de mudança',
              onPressed: () => _openNotifications(name),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mesma cor da barra: a descrição é a última linha do cabeçalho,
          // não o começo do corpo.
          if (hasDescription)
            Container(
              color: headerColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                description,
                style: CommunityDesign.metaStyle(context),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, hasDescription ? 14 : 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.stats.isNotEmpty) ...[
                  _StatsRow(stats: widget.stats),
                  const SizedBox(height: 14),
                ],
                AppTabs(
                  tabs: [
                    for (final tab in tabs)
                      AppTab(label: tab.label, count: tab.count),
                  ],
                  selectedIndex: _selected,
                  onChanged: (i) => setState(() => _selected = i),
                  trailing: canEdit ? _SettingsButton(onTap: _openEdit) : null,
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

/// Ícone do ministério, ao lado do nome na barra de navegação. Usa o ícone e
/// a cor escolhidos no cadastro — os mesmos do card na lista, para a tela ser
/// reconhecível como "aquele ministério" e não como uma tela genérica.
class _MinistryGlyph extends StatelessWidget {
  final Ministry? ministry;

  const _MinistryGlyph({required this.ministry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = dark ? AppTheme.darkRing : AppTheme.primary;
    final color = ministry == null ? fallback : ministryColor(ministry!.color);

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(ministryIconData(ministry?.icon), color: color, size: 18),
    );
  }
}

/// Botão de configuração do ministério, fechando a trilha de abas — o último
/// ícone da barra, logo depois da última aba.
///
/// Fica fora da parte rolável da trilha de propósito: no celular, onde as
/// oito abas não cabem, dentro dela ele só apareceria depois de arrastar
/// tudo até o fim.
class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    // Sem fundo próprio: dentro da pílula, um círculo na cor da trilha só
    // somaria uma borda no meio da barra. A altura acompanha a das abas para
    // não engordar a trilha.
    return Tooltip(
      message: 'Editar ministério',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(AppIcons.settings, size: 18, color: foreground),
        ),
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
    final base = CommunityDesign.titleStyle(
      context,
    ).copyWith(fontSize: 18, fontWeight: FontWeight.w800, height: 1.15);

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return Text(
        name,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final head = words.sublist(0, words.length - 1).join(' ');
    final tail = words.last;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: '$head '),
          TextSpan(
            text: tail,
            style: base.copyWith(color: accent, fontStyle: FontStyle.italic),
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
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

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
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Text(stat.label, style: CommunityDesign.metaStyle(context)),
            ],
          ),
      ],
    );
  }
}
