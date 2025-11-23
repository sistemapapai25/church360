import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';
import '../../domain/models/bible_book.dart';

/// Tela de Livros da Bíblia
class BibleBooksScreen extends ConsumerStatefulWidget {
  const BibleBooksScreen({super.key});

  @override
  ConsumerState<BibleBooksScreen> createState() => _BibleBooksScreenState();
}

class _BibleBooksScreenState extends ConsumerState<BibleBooksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bíblia Sagrada'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Antigo Testamento'),
              Tab(text: 'Novo Testamento'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                context.push('/bible/search');
              },
              tooltip: 'Buscar',
            ),
            IconButton(
              icon: const Icon(Icons.bookmark),
              onPressed: () {
                context.push('/bible/bookmarks');
              },
              tooltip: 'Favoritos',
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _TestamentBooksTab(testament: 'OT'),
            _TestamentBooksTab(testament: 'NT'),
          ],
        ),
      ),
    );
  }
}

/// Tab de livros de um testamento
class _TestamentBooksTab extends ConsumerWidget {
  final String testament;

  const _TestamentBooksTab({required this.testament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = testament == 'OT'
        ? ref.watch(oldTestamentBooksProvider)
        : ref.watch(newTestamentBooksProvider);

    return booksAsync.when(
      data: (books) {
        if (books.isEmpty) {
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
                  'Nenhum livro encontrado',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (testament == 'OT') {
              ref.invalidate(oldTestamentBooksProvider);
            } else {
              ref.invalidate(newTestamentBooksProvider);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _BookCard(book: book);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar livros: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (testament == 'OT') {
                  ref.invalidate(oldTestamentBooksProvider);
                } else {
                  ref.invalidate(newTestamentBooksProvider);
                }
              },
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de Livro
class _BookCard extends StatelessWidget {
  final BibleBook book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            book.abbrev.substring(0, book.abbrev.length > 3 ? 3 : book.abbrev.length),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          book.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${book.chapters} ${book.chapters == 1 ? 'capítulo' : 'capítulos'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/bible/book/${book.id}');
        },
      ),
    );
  }
}
