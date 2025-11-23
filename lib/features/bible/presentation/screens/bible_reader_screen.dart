import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/bible_provider.dart';
import '../../domain/models/bible_verse.dart';
import '../../data/bible_repository.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(bibleChapterVersesProvider((bookId: bookId, chapter: chapter)));
    final bookAsync = ref.watch(bibleBookByIdProvider(bookId));
    final fontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: bookAsync.when(
          data: (book) => Text('${book?.name ?? 'Livro'} $chapter'),
          loading: () => const Text('Carregando...'),
          error: (_, __) => const Text('Erro'),
        ),
        centerTitle: true,
        actions: [
          // Botão de ajuste de fonte
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Tamanho da fonte',
            onSelected: (value) {
              ref.read(fontSizeProvider.notifier).state = value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 14.0, child: Text('Pequeno')),
              const PopupMenuItem(value: 16.0, child: Text('Médio')),
              const PopupMenuItem(value: 18.0, child: Text('Grande')),
              const PopupMenuItem(value: 20.0, child: Text('Muito Grande')),
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
              // Navegação entre capítulos
              _ChapterNavigation(
                bookId: bookId,
                currentChapter: chapter,
                totalChapters: bookAsync.value?.chapters ?? chapter,
              ),

              // Lista de versículos
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(bibleChapterVersesProvider((bookId: bookId, chapter: chapter)));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão anterior
          TextButton.icon(
            onPressed: hasPrevious
                ? () {
                    context.push('/bible/book/$bookId/chapter/${currentChapter - 1}');
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
          ),

          // Indicador de capítulo
          Text(
            'Capítulo $currentChapter de $totalChapters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          // Botão próximo
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
    );
  }
}

/// Item de Versículo
class _VerseItem extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;

  const _VerseItem({
    required this.verse,
    required this.fontSize,
  });

  void _showVerseOptions(BuildContext context) {
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
              onTap: () {
                Navigator.pop(context);
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Faça login para favoritar versículos')),
                  );
                  return;
                }

                final repo = BibleRepository(Supabase.instance.client);
                repo.isBookmarked(userId, verse.id).then((exists) async {
                  if (exists) {
                    await repo.removeBookmark(userId, verse.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removido dos favoritos')),
                    );
                  } else {
                    await repo.addBookmark(userId, verse.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adicionado aos favoritos')),
                    );
                  }
                }).catchError((e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar favorito: $e')),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => _showVerseOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número do versículo
            Container(
              margin: const EdgeInsets.only(right: 12, top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${verse.verse}',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            // Texto do versículo
            Expanded(
              child: Text(
                verse.text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
