import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';
import '../../../../core/design/community_design.dart';

/// Tela de Capítulos de um Livro da Bíblia
class BibleChaptersScreen extends ConsumerWidget {
  final int bookId;

  const BibleChaptersScreen({
    super.key,
    required this.bookId,
  });

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 6;
    if (width >= 900) return 5;
    if (width >= 700) return 4;
    if (width >= 520) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bibleBookByIdProvider(bookId));
    final verseCountsAsync = ref.watch(verseCountsByBookProvider(bookId));

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
                    book?.name ?? 'Livro',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  loading: () => Text(
                    'Carregando...',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  error: (_, __) => Text(
                    'Erro',
                    style: CommunityDesign.titleStyle(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Selecione um capítulo',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
      ),
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Livro não encontrado'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = _crossAxisCount(constraints.maxWidth);
              final counts = verseCountsAsync.valueOrNull ?? const <int, int>{};
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 90,
                ),
                itemCount: book.chapters,
                itemBuilder: (context, index) {
                  final chapterNumber = index + 1;
                  return _ChapterCard(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    verseCount: counts[chapterNumber],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar livro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(bibleBookByIdProvider(bookId));
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

/// Card de Capítulo
class _ChapterCard extends StatelessWidget {
  final int bookId;
  final int chapterNumber;
  final int? verseCount;

  const _ChapterCard({
    required this.bookId,
    required this.chapterNumber,
    this.verseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        onTap: () {
          context.push('/bible/book/$bookId/chapter/$chapterNumber');
        },
        child: Container(
          decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Capítulo $chapterNumber',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (verseCount != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      '$verseCount versículos',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                )
              else
                Text(
                  'Abrir leitura',
                  style: CommunityDesign.metaStyle(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
