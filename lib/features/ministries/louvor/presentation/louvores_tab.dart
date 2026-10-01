import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../data/praise_repository.dart';
import 'praise_setlists_view.dart';
import 'providers/praise_providers.dart';

/// Aba Louvores: repertórios do ministério e a biblioteca da igreja (que é
/// do tenant, não do ministério — qualquer ministério de tipo louvor abre a
/// mesma lista). Os dois lados num `SegmentedButton`: abas aqui dentro a
/// régua do padrão de ministério não aceita.
class LouvoresTab extends ConsumerStatefulWidget {
  final String ministryId;

  const LouvoresTab({super.key, required this.ministryId});

  @override
  ConsumerState<LouvoresTab> createState() => _LouvoresTabState();
}

class _LouvoresTabState extends ConsumerState<LouvoresTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _setlists = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Título, artista ou trecho da letra (sem os acordes).
  bool _matches(PraiseSong s) {
    final q = _searchQuery.trim().toLowerCase();
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Repertórios')),
                    ButtonSegment(value: false, label: Text('Biblioteca')),
                  ],
                  selected: {_setlists},
                  onSelectionChanged: (v) =>
                      setState(() => _setlists = v.first),
                ),
              ),
            ),
            Expanded(
              child: _setlists
                  ? PraiseSetlistsView(ministryId: widget.ministryId)
                  : _library(access.canManage),
            ),
          ],
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
        final visible = songs.where(_matches).toList();
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
              if (songs.isEmpty)
                PraiseMessage(
                  title: 'A biblioteca ainda está vazia',
                  message: canManage
                      ? 'Cadastre a primeira música em "Nova música". '
                            'Dá para colar a cifra direto do site.'
                      : 'Quando a liderança cadastrar as músicas, elas aparecem aqui.',
                )
              else if (visible.isEmpty)
                const PraiseMessage(
                  title: 'Nenhuma música encontrada',
                  message:
                      'Tente outro título, artista ou trecho da letra.',
                ),
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
                            ],
                          ),
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
