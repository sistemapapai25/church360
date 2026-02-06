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
import '../../data/bible_repository.dart';
import '../../../../core/design/community_design.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
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
    final versesAsync = ref.watch(bibleChapterVersesProvider((bookId: bookId, chapter: chapter)));
    final bookAsync = ref.watch(bibleBookByIdProvider(bookId));
    final tokensAsync = ref.watch(bibleChapterVerseTokensProvider((bookId: bookId, chapter: chapter)));
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
            icon: const Icon(Icons.arrow_back),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.menu_book_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
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
                  loading: () => Text('Carregando...', style: CommunityDesign.titleStyle(context)),
                  error: (_, __) => Text('Erro', style: CommunityDesign.titleStyle(context)),
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
            icon: const Icon(Icons.text_fields),
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
          PermissionGate(
            permission: 'bible.manage_lexicon',
            showLoading: false,
            child: IconButton(
              tooltip: 'Editar léxico (Strong)',
              onPressed: () => context.push('/bible/lexicon'),
              icon: const Icon(Icons.translate_rounded),
            ),
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
                    Icons.menu_book_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum versículo encontrado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    ref.invalidate(bibleChapterVersesProvider((bookId: bookId, chapter: chapter)));
                    ref.invalidate(bibleChapterVerseTokensProvider((bookId: bookId, chapter: chapter)));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: verses.length,
                    itemBuilder: (context, index) {
                      final verse = verses[index];
                      final tokensByVerseId = tokensAsync.value ?? const <int, List<BibleVerseToken>>{};
                      return _VerseItem(
                        verse: verse,
                        fontSize: fontSize,
                        tokens: tokensByVerseId[verse.id] ?? const [],
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar versículos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(bibleChapterVersesProvider((bookId: bookId, chapter: chapter)));
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
      child: Container(
        decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: hasPrevious
                  ? () {
                      context.push('/bible/book/$bookId/chapter/${currentChapter - 1}');
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
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
                      context.push('/bible/book/$bookId/chapter/${currentChapter + 1}');
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
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

  const _VerseItem({
    required this.verse,
    required this.fontSize,
    required this.tokens,
  });

  void _showVerseOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${verse.reference}\n${verse.text}'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Versículo copiado!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartilhar'),
              onTap: () {
                Navigator.pop(context);
                Share.share('${verse.reference}\n\n${verse.text}\n\n- Bíblia Sagrada (ARC)');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Adicionar aos favoritos'),
              onTap: () async {
                Navigator.pop(context);
                final member = await ref.read(currentMemberProvider.future);
                if (member == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Faça login para favoritar versículos')),
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
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _showVerseOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${verse.verse}',
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
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
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveVerseText extends StatelessWidget {
  final String text;
  final List<BibleVerseToken> tokens;
  final TextStyle style;
  final void Function(BibleLexeme lexeme, String surface, Offset anchor) onOpenLexeme;

  const _InteractiveVerseText({
    required this.text,
    required this.tokens,
    required this.style,
    required this.onOpenLexeme,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...tokens]..sort((a, b) => a.startOffset.compareTo(b.startOffset));
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final token in sorted) {
      if (token.startOffset < 0 || token.endOffset > text.length) continue;
      if (token.startOffset < cursor) continue;

      if (token.startOffset > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, token.startOffset), style: style));
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
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final size = MediaQuery.sizeOf(overlayContext);
      final padding = 12.0;
      final width = math.min(340.0, size.width - (padding * 2));
      final isAbove = anchor.dy > (size.height * 0.6);
      final maxHeight = math.min(280.0, size.height * 0.45);

      final left = (anchor.dx - (width / 2)).clamp(padding, size.width - width - padding);
      final arrowX = (anchor.dx - left).clamp(18.0, width - 18.0);

      final top = isAbove
          ? (anchor.dy - maxHeight - 18).clamp(padding, size.height - maxHeight - padding)
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

class _LexemeCard extends StatelessWidget {
  final BibleLexeme lexeme;
  final String surface;
  final VoidCallback onClose;

  const _LexemeCard({
    required this.lexeme,
    required this.surface,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lemmaText = (lexeme.lemma ?? '').trim();
    final transliterationText = (lexeme.transliteration ?? '').trim();
    final glossText = (lexeme.ptGloss ?? '').trim();
    final definitionText = (lexeme.ptDefinition ?? '').trim();

    final hasLemma = lemmaText.isNotEmpty;
    final hasTransliteration = transliterationText.isNotEmpty;
    final hasGloss = glossText.isNotEmpty;
    final hasDefinition = definitionText.isNotEmpty;

    final headline = hasLemma ? lemmaText : (hasGloss ? glossText : '');
    final meaning = hasDefinition
        ? definitionText
        : (hasLemma && hasGloss ? glossText : null);

    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ).copyWith(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lexeme.strongCode,
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          surface,
                          style: CommunityDesign.metaStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headline.isNotEmpty)
                      Text(
                        headline,
                        style: CommunityDesign.titleStyle(context).copyWith(fontWeight: FontWeight.w800),
                      ),
                    if (headline.isNotEmpty) const SizedBox(height: 6),
                    if (hasTransliteration || (hasGloss && hasLemma))
                      Text(
                        [
                          if (hasTransliteration) transliterationText,
                          if (hasGloss && hasLemma) glossText,
                        ].join(' • '),
                        style: CommunityDesign.metaStyle(context),
                      ),
                    if (hasTransliteration || (hasGloss && hasLemma)) const SizedBox(height: 10),
                    Text(
                      meaning ?? 'Definição em PT ainda não cadastrada.',
                      style: CommunityDesign.contentStyle(context).copyWith(height: 1.45),
                    ),
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
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final outlineColor = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7);

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
    return oldDelegate.color != color || oldDelegate.outlineColor != outlineColor || oldDelegate.isDown != isDown;
  }
}
