import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../../core/widgets/glass_card.dart';
import '../data/praise_repository.dart';
import 'praise_received_view.dart';
import 'praise_setlists_view.dart';
import 'providers/praise_providers.dart';

/// Aba Louvores: repertórios do ministério e a biblioteca da igreja (que é
/// do tenant, não do ministério — qualquer ministério de tipo louvor abre a
/// mesma lista). Os lados são sub-navegação em `AppTabs`, a mesma pílula de
/// Cursos e Turma (exceção registrada na régua do padrão de ministério).
class LouvoresTab extends ConsumerStatefulWidget {
  final String ministryId;

  const LouvoresTab({super.key, required this.ministryId});

  @override
  ConsumerState<LouvoresTab> createState() => _LouvoresTabState();
}

class _LouvoresTabState extends ConsumerState<LouvoresTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// 0 = Repertórios, 1 = Biblioteca, 2 = Recebidos (de outro ministério).
  int _side = 0;

  /// Filtro da Biblioteca (contrato do leitor §7).
  _Shelf _shelf = _Shelf.all;
  List<String> _favorites = const [];
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _favorites = p.getStringList(praiseFavoritesPref) ?? const [];
        _recent = p.getStringList(praiseRecentPref) ?? const [];
      });
    } catch (_) {}
  }

  void _toggleFavorite(String id) {
    setState(
      () => _favorites = _favorites.contains(id)
          ? [..._favorites.where((f) => f != id)]
          : [id, ..._favorites],
    );
    togglePraiseFavorite(id).ignore();
  }

  /// Músicas do filtro, na ordem dele.
  List<PraiseSong> _shelve(List<PraiseSong> songs, Map<String, int> usage) {
    switch (_shelf) {
      case _Shelf.all:
        return songs;
      case _Shelf.favorites:
        return songs.where((s) => _favorites.contains(s.id)).toList();
      case _Shelf.recent:
        final byId = {for (final s in songs) s.id: s};
        return [
          for (final id in _recent)
            if (byId[id] != null) byId[id]!,
        ];
      case _Shelf.mostUsed:
        return songs.where((s) => (usage[s.id] ?? 0) > 0).toList()
          ..sort((a, b) => usage[b.id]!.compareTo(usage[a.id]!));
      case _Shelf.changes:
        return const []; // é o feed do ministério, desenhado à parte
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(PraiseSong s) => praiseSongMatches(s, _searchQuery);

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(praiseAccessProvider);

    return accessAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PraiseMessage(
        title: 'Não deu para verificar seu acesso',
        message: '$e',
        onRetry: () => ref.invalidate(praiseAccessProvider),
      ),
      data: (access) {
        if (!access.canView) {
          return const PraiseMessage(
            title: 'Biblioteca de louvores fechada para você',
            message:
                'Quem faz parte de um ministério de louvor vê as cifras. '
                'Fora dele, é preciso a permissão "Ver louvores".',
          );
        }
        final received =
            ref
                .watch(praiseReceivedProvider(widget.ministryId))
                .valueOrNull
                ?.isNotEmpty ??
            false;
        final side = !received && _side == 2 ? 0 : _side;
        return Align(
          alignment: Alignment.topCenter,
          // §10.4 S3: em tela larga o conteúdo não estica de ponta a ponta.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: AppTabs(
                    tabs: [
                      const AppTab(label: 'Repertórios'),
                      const AppTab(label: 'Biblioteca'),
                      if (received) const AppTab(label: 'Recebidos'),
                    ],
                    selectedIndex: side,
                    onChanged: (i) => setState(() => _side = i),
                  ),
                ),
                Expanded(
                  child: switch (side) {
                    0 => PraiseSetlistsView(ministryId: widget.ministryId),
                    1 => _library(access.canManage),
                    _ => PraiseReceivedView(ministryId: widget.ministryId),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _library(bool canManage) {
    final songsAsync = ref.watch(praiseSongsProvider);
    return songsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PraiseMessage(
        title: 'Não deu para carregar a biblioteca',
        message: '$e',
        onRetry: () => ref.invalidate(praiseSongsProvider),
      ),
      data: (songs) {
        final usage =
            ref.watch(praiseUsageProvider(widget.ministryId)).valueOrNull ??
            const {};
        final visible = _shelve(songs, usage).where(_matches).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(praiseSongsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _searchController,
                searchHint: 'Buscar por título, artista ou trecho...',
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                primaryAction: canManage
                    ? AppFilterAction(
                        label: 'Nova música',
                        icon: AppIcons.add,
                        onPressed: () => context.push(
                          '/ministries/${widget.ministryId}/louvores/musicas/nova',
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _Shelf.values)
                    ChoiceChip(
                      shape: const StadiumBorder(),
                      label: Text(f.label),
                      selected: _shelf == f,
                      onSelected: (_) {
                        setState(() => _shelf = f);
                        // Recentes muda ao abrir músicas: relê ao voltar.
                        if (f == _Shelf.recent) _loadLocal();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_shelf == _Shelf.changes)
                ..._activity()
              else if (songs.isEmpty)
                PraiseMessage(
                  title: 'A biblioteca ainda está vazia',
                  message: canManage
                      ? 'Cadastre a primeira música em "Nova música". '
                            'Dá para colar a cifra direto do site.'
                      : 'Quando a liderança cadastrar as músicas, elas aparecem aqui.',
                )
              else if (visible.isEmpty)
                PraiseMessage(
                  title: _shelf.emptyTitle,
                  message: _searchQuery.trim().isNotEmpty
                      ? 'Tente outro título, artista ou trecho da letra.'
                      : _shelf.emptyMessage,
                ),
              if (_shelf != _Shelf.changes)
                for (final s in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      onTap: () => context.push(
                        '/ministries/${widget.ministryId}/louvores/musicas/${s.id}',
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: CommunityDesign.titleStyle(
                                    context,
                                  ).copyWith(fontSize: 15),
                                ),
                                if (s.artist != null && s.artist!.isNotEmpty)
                                  Text(
                                    s.artist!,
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                                if (_shelf == _Shelf.mostUsed)
                                  Text(
                                    'Em ${usage[s.id]} repertório(s)',
                                    style: CommunityDesign.metaStyle(context),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _favorites.contains(s.id)
                                ? 'Tirar das favoritas'
                                : 'Favoritar',
                            icon: Icon(
                              _favorites.contains(s.id)
                                  ? AppIcons.star
                                  : AppIcons.starOutline,
                            ),
                            onPressed: () => _toggleFavorite(s.id),
                          ),
                          Text(
                            s.latest?.originalKey ??
                                (s.latest == null ? 'sem cifra' : ''),
                            style: CommunityDesign.metaStyle(
                              context,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

extension on _LouvoresTabState {
  /// "O que mudou" do ministério inteiro (decisão de 01/10): músicas novas
  /// e versões da biblioteca + repertórios publicados deste ministério,
  /// com quem fez. A busca vale para o título.
  List<Widget> _activity() {
    final async = ref.watch(praiseActivityProvider(widget.ministryId));
    final q = _searchQuery.trim().toLowerCase();
    return async.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        PraiseMessage(
          title: 'Não deu para carregar o que mudou',
          message: '$e',
          onRetry: () =>
              ref.invalidate(praiseActivityProvider(widget.ministryId)),
        ),
      ],
      data: (all) {
        final items = [
          for (final a in all)
            if (q.isEmpty || a.title.toLowerCase().contains(q)) a,
        ];
        if (items.isEmpty) {
          return [
            PraiseMessage(
              title: _Shelf.changes.emptyTitle,
              message: q.isNotEmpty
                  ? 'Tente outro título.'
                  : _Shelf.changes.emptyMessage,
            ),
          ];
        }
        final base = '/ministries/${widget.ministryId}/louvores';
        return [
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: () => context.push(
                  a.setlistId != null
                      ? '$base/repertorios/${a.setlistId}'
                      : '$base/musicas/${a.songId}',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTitle(a),
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 15),
                    ),
                    Text(
                      activityLine(a),
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),
              ),
            ),
        ];
      },
    );
  }
}

/// "Nova música: Escape", "Escape · versão 3", "Repertório publicado:
/// Culto de domingo (rev. 2)".
String activityTitle(PraiseActivity a) => switch (a.kind) {
  'song_new' => 'Nova música: ${a.title}',
  'song_version' => '${a.title} · versão ${a.number}',
  _ =>
    'Repertório publicado: ${a.title}'
        '${a.number > 1 ? ' (rev. ${a.number})' : ''}',
};

/// "Debora · troquei o tom · 01/10 14:30".
String activityLine(PraiseActivity a) => [
  ?a.who,
  if (a.note != null && a.note!.isNotEmpty) a.note!,
  DateFormat('dd/MM HH:mm').format(a.at.toLocal()),
].join(' · ');

/// Aviso centralizado das telas de Louvores (vazio, erro, sem acesso).
class PraiseMessage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const PraiseMessage({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Favoritas e recentes ficam no aparelho (cada pessoa no seu celular),
/// como as preferências do leitor.
const praiseFavoritesPref = 'praise_favorites';
const praiseRecentPref = 'praise_recent';

/// Liga/desliga a estrela da música (Biblioteca e ⋮ do leitor).
Future<void> togglePraiseFavorite(String songId) async {
  try {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(praiseFavoritesPref) ?? const [];
    await p.setStringList(
      praiseFavoritesPref,
      list.contains(songId)
          ? [...list.where((id) => id != songId)]
          : [songId, ...list],
    );
  } catch (_) {}
}

/// Busca da Biblioteca e do seletor do repertório: título, artista ou
/// trecho da letra (sem os acordes).
bool praiseSongMatches(PraiseSong s, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final lyrics = s.latest == null
      ? ''
      : s.latest!.chordpro.replaceAll(RegExp(r'\[[^\]]*\]|\{[^}]*\}'), '');
  return [
    s.title,
    s.artist ?? '',
    lyrics,
  ].any((t) => t.toLowerCase().contains(q));
}

/// O leitor chama ao abrir: a música vai para o topo de "Recentes" (20).
Future<void> rememberRecentSong(String songId) async {
  try {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(praiseRecentPref) ?? const [];
    await p.setStringList(praiseRecentPref, [
      songId,
      ...list.where((id) => id != songId).take(19),
    ]);
  } catch (_) {}
}

enum _Shelf {
  all('Todas', 'Nenhuma música encontrada', ''),
  favorites(
    'Favoritas',
    'Nenhuma favorita ainda',
    'Toque na estrela de uma música para ela aparecer aqui.',
  ),
  recent(
    'Recentes',
    'Nenhuma música aberta ainda',
    'As músicas que você abrir aparecem aqui.',
  ),
  mostUsed(
    'Mais usadas',
    'Nenhuma música em repertório',
    'As músicas que entram nos repertórios aparecem aqui.',
  ),
  changes(
    'O que mudou',
    'Nada mudou ainda',
    'Músicas novas, versões novas e repertórios publicados do ministério '
        'aparecem aqui, do mais recente.',
  );

  const _Shelf(this.label, this.emptyTitle, this.emptyMessage);
  final String label;
  final String emptyTitle;
  final String emptyMessage;
}
