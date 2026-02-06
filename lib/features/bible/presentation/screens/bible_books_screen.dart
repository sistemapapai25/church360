import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';
import '../../domain/models/bible_book.dart';
import '../../../../core/design/community_design.dart';

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
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
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
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bíblia Sagrada',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Escolha um livro',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
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
        body: Column(
          children: [
            const _BibleTopShortcuts(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                tabs: const [
                  Tab(text: 'Antigo Testamento'),
                  Tab(text: 'Novo Testamento'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _TestamentBooksTab(testament: 'OT'),
                  _TestamentBooksTab(testament: 'NT'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BibleTopShortcuts extends StatelessWidget {
  const _BibleTopShortcuts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: const [
          Expanded(
            child: _BibleShortcutCard(
              icon: Icons.menu_book_outlined,
              label: 'Planos de Leitura',
              route: '/reading-plans',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _BibleShortcutCard(
              icon: Icons.auto_stories_outlined,
              label: 'Devocionais',
              route: '/devotionals',
            ),
          ),
        ],
      ),
    );
  }
}

class _BibleShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _BibleShortcutCard({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cs.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: CommunityDesign.contentStyle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab de livros de um testamento
class _TestamentBooksTab extends ConsumerWidget {
  final String testament;

  const _TestamentBooksTab({required this.testament});

  int _crossAxisCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 900) return 4;
    if (width >= 650) return 3;
    return 2;
  }

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _crossAxisCount(constraints.maxWidth);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 140,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final accent = Theme.of(context).colorScheme.primary;
                  return _BookCard(
                    book: book,
                    accent: accent,
                  );
                },
              );
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
  final Color accent;

  const _BookCard({required this.book, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        onTap: () {
          context.push('/bible/book/${book.id}');
        },
        child: Container(
          decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      book.abbrev.substring(0, book.abbrev.length > 3 ? 3 : book.abbrev.length).toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                book.name,
                style: CommunityDesign.titleStyle(context).copyWith(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.menu_book, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    '${book.chapters} ${book.chapters == 1 ? 'capítulo' : 'capítulos'}',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
