import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';

/// Tela de Capítulos de um Livro da Bíblia
class BibleChaptersScreen extends ConsumerWidget {
  final int bookId;

  const BibleChaptersScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bibleBookByIdProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: bookAsync.when(
          data: (book) => Text(book?.name ?? 'Livro'),
          loading: () => const Text('Carregando...'),
          error: (_, __) => const Text('Erro'),
        ),
        centerTitle: true,
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: book.chapters,
            itemBuilder: (context, index) {
              final chapterNumber = index + 1;
              return _ChapterCard(
                bookId: bookId,
                chapterNumber: chapterNumber,
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

  const _ChapterCard({
    required this.bookId,
    required this.chapterNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/bible/book/$bookId/chapter/$chapterNumber');
        },
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            '$chapterNumber',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ),
    );
  }
}

