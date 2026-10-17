import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/bible_provider.dart';
import '../../domain/models/bible_verse.dart';
import '../../domain/models/bible_lexeme.dart';
import '../../domain/models/bible_verse_token.dart';
import '../../domain/models/bible_word_study.dart';
import '../../data/bible_repository.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Provider para tamanho de fonte
final fontSizeProvider = StateProvider<double>((ref) => 16.0);

/// Tela de Leitura da Bíblia
class BibleReaderScreen extends ConsumerWidget {
  final int bookId;
  final int chapter;

  const BibleReaderScreen({
    super.key,
    required this.bookId,
    required this.chapter,
  });

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(
      bibleChapterVersesProvider((bookId: bookId, chapter: chapter)),
    );
    final bookAsync = ref.watch(bibleBookByIdProvider(bookId));
    final tokensAsync = ref.watch(
      bibleChapterVerseTokensProvider((bookId: bookId, chapter: chapter)),
    );
    final studiesAsync = ref.watch(
      bibleChapterWordStudiesProvider((bookId: bookId, chapter: chapter)),
    );
    final fontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () => _handleBack(context),
            icon: const Icon(AppIcons.back),
          ),
        ),
        titleSpacing: 0,
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
                AppIcons.book,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bookAsync.when(
                  data: (book) => Text(
                    '${book?.name ?? 'Livro'} $chapter',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  loading: () => Text(
                    'Carregando...',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  error: (_, __) =>
                      Text('Erro', style: CommunityDesign.titleStyle(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Leitura diária',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(AppIcons.textFields),
            tooltip: 'Tamanho da fonte',
            onSelected: (value) {
              ref.read(fontSizeProvider.notifier).state = value;
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 14.0, child: Text('Pequeno')),
              PopupMenuItem(value: 16.0, child: Text('Médio')),
              PopupMenuItem(value: 18.0, child: Text('Grande')),
              PopupMenuItem(value: 20.0, child: Text('Muito Grande')),
            ],
          ),
          // Só o Owner edita léxico e estudos; nenhum cargo recebe isso (17/10/2026).
          if (ref.watch(currentUserIsOwnerProvider).valueOrNull ?? false)
            IconButton(
              tooltip: 'Editar léxico (Strong)',
              onPressed: () => context.push('/bible/lexicon'),
              icon: const Icon(AppIcons.translate),
            ),
        ],
      ),
      body: versesAsync.when(
        data: (verses) {
          if (verses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.book,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum versículo encontrado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _ChapterNavigation(
                bookId: bookId,
                currentChapter: chapter,
                totalChapters: bookAsync.value?.chapters ?? chapter,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(
                      bibleChapterVersesProvider((
                        bookId: bookId,
                        chapter: chapter,
                      )),
                    );
                    ref.invalidate(
                      bibleChapterVerseTokensProvider((
                        bookId: bookId,
                        chapter: chapter,
                      )),
                    );
                    ref.invalidate(
                      bibleChapterWordStudiesProvider((
                        bookId: bookId,
                        chapter: chapter,
                      )),
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: verses.length,
                    itemBuilder: (context, index) {
                      final verse = verses[index];
                      final tokensByVerseId =
                          tokensAsync.value ??
                          const <int, List<BibleVerseToken>>{};
                      return _VerseItem(
                        verse: verse,
                        fontSize: fontSize,
                        tokens: tokensByVerseId[verse.id] ?? const [],
                        studies: studiesAsync.value?[verse.id] ?? const [],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar versículos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    bibleChapterVersesProvider((
                      bookId: bookId,
                      chapter: chapter,
                    )),
                  );
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navegação entre capítulos
class _ChapterNavigation extends StatelessWidget {
  final int bookId;
  final int currentChapter;
  final int totalChapters;

  const _ChapterNavigation({
    required this.bookId,
    required this.currentChapter,
    required this.totalChapters,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrevious = currentChapter > 1;
    final hasNext = currentChapter < totalChapters;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: hasPrevious
                  ? () {
                      context.push(
                        '/bible/book/$bookId/chapter/${currentChapter - 1}',
                      );
                    }
                  : null,
              icon: const Icon(AppIcons.chevronLeft),
              label: const Text('Anterior'),
            ),
            Column(
              children: [
                Text(
                  'Capítulo $currentChapter',
                  style: CommunityDesign.titleStyle(context),
                ),
                Text(
                  'de $totalChapters',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: hasNext
                  ? () {
                      context.push(
                        '/bible/book/$bookId/chapter/${currentChapter + 1}',
                      );
                    }
                  : null,
              icon: const Icon(AppIcons.forward),
              label: const Text('Próximo'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de Versículo
class _VerseItem extends ConsumerWidget {
  final BibleVerse verse;
  final double fontSize;
  final List<BibleVerseToken> tokens;
  final List<BibleWordStudy> studies;

  const _VerseItem({
    required this.verse,
    required this.fontSize,
    required this.tokens,
    this.studies = const [],
  });

  void _showVerseOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: '${verse.reference}\n${verse.text}'),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Versículo copiado!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.share),
              title: const Text('Compartilhar'),
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  '${verse.reference}\n\n${verse.text}\n\n- Bíblia Sagrada (ARC)',
                );
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.bookmarkOutline),
              title: const Text('Adicionar aos favoritos'),
              onTap: () async {
                Navigator.pop(context);
                final member = await ref.read(currentMemberProvider.future);
                if (member == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Faça login para favoritar versículos'),
                    ),
                  );
                  return;
                }

                final repo = BibleRepository(Supabase.instance.client);
                try {
                  final exists = await repo.isBookmarked(member.id, verse.id);
                  if (exists) {
                    await repo.removeBookmark(member.id, verse.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removido dos favoritos')),
                    );
                  } else {
                    await repo.addBookmark(member.id, verse.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adicionado aos favoritos')),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar favorito: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      color: cs.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GlassCard(
        radius: 14,
        onLongPress: () => _showVerseOptions(context, ref),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12, top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${verse.verse}',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            Expanded(
              child: tokens.isEmpty
                  ? Text(verse.text, style: baseStyle)
                  : _InteractiveVerseText(
                      text: verse.text,
                      tokens: tokens,
                      style: baseStyle,
                      onOpenLexeme: (lexeme, surface, anchor) {
                        _showLexemeOverlay(
                          context: context,
                          anchor: anchor,
                          lexeme: lexeme,
                          surface: surface,
                          study: studies
                              .where(
                                (s) => s.matches(
                                  strongCode: lexeme.strongCode,
                                  surface: surface,
                                ),
                              )
                              .firstOrNull,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveVerseText extends StatelessWidget {
  final String text;
  final List<BibleVerseToken> tokens;
  final TextStyle style;
  final void Function(BibleLexeme lexeme, String surface, Offset anchor)
  onOpenLexeme;

  const _InteractiveVerseText({
    required this.text,
    required this.tokens,
    required this.style,
    required this.onOpenLexeme,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...tokens]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final token in sorted) {
      if (token.startOffset < 0 || token.endOffset > text.length) continue;
      if (token.startOffset < cursor) continue;

      if (token.startOffset > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, token.startOffset),
            style: style,
          ),
        );
      }

      final tokenText = text.substring(token.startOffset, token.endOffset);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final lexeme = token.lexeme;
              if (lexeme != null) {
                onOpenLexeme(lexeme, tokenText, details.globalPosition);
              }
            },
            child: Text(tokenText, style: style),
          ),
        ),
      );

      cursor = token.endOffset;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

void _showLexemeOverlay({
  required BuildContext context,
  required Offset anchor,
  required BibleLexeme lexeme,
  required String surface,
  BibleWordStudy? study,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final size = MediaQuery.sizeOf(overlayContext);
      const padding = 12.0;
      final hasStudy = study != null;
      // Com estudo o pop-up cresce; o resto rola dentro dele.
      final width = math.min(hasStudy ? 460.0 : 360.0, size.width - (padding * 2));
      final isAbove = anchor.dy > size.height * (hasStudy ? 0.5 : 0.6);
      final room = isAbove
          ? anchor.dy - 18 - padding
          : size.height - anchor.dy - 18 - padding;
      final desired = hasStudy
          ? math.min(680.0, size.height * 0.82)
          : math.min(320.0, size.height * 0.5);
      final maxHeight = math.min(desired, math.max(room, 240.0));

      final left = (anchor.dx - (width / 2)).clamp(
        padding,
        size.width - width - padding,
      );
      final arrowX = (anchor.dx - left).clamp(18.0, width - 18.0);

      final top = isAbove
          ? (anchor.dy - maxHeight - 18).clamp(
              padding,
              size.height - maxHeight - padding,
            )
          : (anchor.dy + 18).clamp(padding, size.height - maxHeight - padding);

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => entry?.remove(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              type: MaterialType.transparency,
              child: _AnchoredPopup(
                isAbove: isAbove,
                arrowX: arrowX,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: _LexemeCard(
                    lexeme: lexeme,
                    surface: surface,
                    study: study,
                    onClose: () => entry?.remove(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
}

const _ubsCredit =
    'Dicionário Semântico do Hebraico Bíblico, © Sociedades Bíblicas Unidas, CC BY-SA 4.0';

String _languageLabel(String language) => switch (language) {
  'hebrew' => 'Hebraico',
  'aramaic' => 'Aramaico',
  'greek' => 'Grego',
  _ => language,
};

class _LexemeCard extends StatelessWidget {
  final BibleLexeme lexeme;
  final String surface;
  final BibleWordStudy? study;
  final VoidCallback onClose;

  const _LexemeCard({
    required this.lexeme,
    required this.surface,
    required this.onClose,
    this.study,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = CommunityDesign.metaStyle(context);
    final lemmaText = (lexeme.lemma ?? '').trim();
    final transliterationText = (lexeme.transliteration ?? '').trim();
    final glossText = (lexeme.ptGloss ?? '').trim();
    final definitionText = (lexeme.ptDefinition ?? '').trim();

    final hasLemma = lemmaText.isNotEmpty;
    final hasGloss = glossText.isNotEmpty;

    final headline = hasLemma ? lemmaText : (hasGloss ? glossText : '');
    final meaning = definitionText.isNotEmpty
        ? definitionText
        : (hasLemma && hasGloss ? glossText : null);
    final outline = cs.outlineVariant.withValues(alpha: 0.65);

    return Container(
      decoration: CommunityDesign.feedCardDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        border: Border.all(color: outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                border: Border(bottom: BorderSide(color: outline)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      lexeme.strongCode,
                      style: meta.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_languageLabel(lexeme.language)} · “$surface”',
                      style: meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headline.isNotEmpty)
                      Text(
                        headline,
                        style: CommunityDesign.titleStyle(context).copyWith(
                          fontSize: hasLemma ? 28 : null,
                          fontWeight: hasLemma ? FontWeight.w600 : FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    if (transliterationText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transliterationText,
                        style: meta.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (hasGloss && hasLemma) ...[
                      const SizedBox(height: 8),
                      Text(
                        glossText,
                        style: CommunityDesign.contentStyle(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      meaning ?? 'Definição em PT ainda não cadastrada.',
                      style: CommunityDesign.contentStyle(context).copyWith(height: 1.5),
                    ),
                    if (lexeme.ptSource == 'UBS SDBH pt') ...[
                      const SizedBox(height: 8),
                      Text(_ubsCredit, style: meta.copyWith(fontSize: 11)),
                    ],
                    if (study != null) _WordStudyView(study: study!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estudo palavra por palavra no padrão de backend-scripts/lexico/MODELO-ESTUDO.md.
class _WordStudyView extends StatelessWidget {
  final BibleWordStudy study;

  const _WordStudyView({required this.study});

  static const _defaultTitles = {
    'etimologia': 'Etimologia',
    'pictografia': 'Análise pictórica',
    'sintese': 'Síntese pictórica',
    'contexto': 'Contexto',
    'peso_teologico': 'Peso teológico',
    'conclusao': 'Conclusão',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = CommunityDesign.metaStyle(context);
    final original = [
      if ((study.palavraOriginal ?? '').isNotEmpty) study.palavraOriginal!,
      if ((study.transliteracao ?? '').isNotEmpty) study.transliteracao!,
    ].join(' · ');
    final raiz = [
      if ((study.raiz ?? '').isNotEmpty) study.raiz!,
      if ((study.raizTransliteracao ?? '').isNotEmpty) '(${study.raizTransliteracao})',
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'ESTUDO DA PALAVRA',
                    style: meta.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                study.titulo,
                style: CommunityDesign.titleStyle(context).copyWith(fontWeight: FontWeight.w800),
              ),
              if (original.isNotEmpty) Text(original, style: meta),
              if (raiz.isNotEmpty) Text('Raiz: $raiz', style: meta),
            ],
          ),
        ),
        for (final secao in study.secoes) _section(context, secao),
      ],
    );
  }

  Widget _section(BuildContext context, Map<String, dynamic> secao) {
    final cs = Theme.of(context).colorScheme;
    final tipo = secao['tipo'] as String? ?? '';
    final titulo = (secao['titulo'] as String?)?.trim();
    final blocos = (secao['blocos'] as List? ?? const []).whereType<Map<String, dynamic>>();
    final children = <Widget>[
      Text(
        (titulo == null || titulo.isEmpty) ? (_defaultTitles[tipo] ?? '') : titulo,
        style: CommunityDesign.titleStyle(context).copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      for (final bloco in blocos) _block(context, bloco),
    ];

    if (tipo == 'conclusao') {
      return Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: cs.primary, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _block(BuildContext context, Map<String, dynamic> bloco) {
    final cs = Theme.of(context).colorScheme;
    final content = CommunityDesign.contentStyle(context).copyWith(height: 1.55);
    switch (bloco['tipo']) {
      case 'subtitulo':
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            bloco['texto'] as String? ?? '',
            style: content.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      case 'lista':
        final itens = (bloco['itens'] as List? ?? const []).whereType<String>();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: content.copyWith(color: cs.primary)),
                      Expanded(child: _listItem(item, content)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'letras':
        final letras = (bloco['letras'] as List? ?? const []).whereType<Map<String, dynamic>>();
        return Column(
          children: [
            for (final letra in letras)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letra['glifo'] as String? ?? '',
                        style: TextStyle(fontSize: 26, color: cs.primary, height: 1.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            letra['nome'] as String? ?? '',
                            style: content.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(letra['descricao'] as String? ?? '', style: content),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(bloco['texto'] as String? ?? '', style: content),
        );
    }
  }

  /// "Significado Original: o verbo..." -> trecho antes de ":" em negrito.
  static Widget _listItem(String item, TextStyle style) {
    final i = item.indexOf(':');
    if (i <= 0 || i > 60) return Text(item, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: item.substring(0, i + 1),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: item.substring(i + 1)),
        ],
      ),
    );
  }
}

class _AnchoredPopup extends StatelessWidget {
  final bool isAbove;
  final double arrowX;
  final Widget child;

  const _AnchoredPopup({
    required this.isAbove,
    required this.arrowX,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.brightness == Brightness.light
        ? Colors.white
        : colorScheme.surface;
    final outlineColor = colorScheme.outlineVariant.withValues(alpha: 0.7);

    final arrow = CustomPaint(
      painter: _TrianglePainter(
        color: surfaceColor,
        outlineColor: outlineColor,
        isDown: isAbove,
      ),
      size: const Size(18, 10),
    );

    if (isAbove) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          Padding(
            padding: EdgeInsets.only(left: arrowX - 9),
            child: arrow,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: arrowX - 9),
          child: arrow,
        ),
        child,
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color outlineColor;
  final bool isDown;

  _TrianglePainter({
    required this.color,
    required this.outlineColor,
    required this.isDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.isDown != isDown;
  }
}
