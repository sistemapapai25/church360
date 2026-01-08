import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/bible_provider.dart';
import '../../domain/models/bible_verse.dart';
import '../../data/bible_repository.dart';
import '../../../../core/design/community_design.dart';
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
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: verses.length,
                    itemBuilder: (context, index) {
                      final verse = verses[index];
                      return _VerseItem(
                        verse: verse,
                        fontSize: fontSize,
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

  const _VerseItem({
    required this.verse,
    required this.fontSize,
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
                child: Text(
                  verse.text,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
