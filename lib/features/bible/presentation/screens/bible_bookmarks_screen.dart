import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../members/presentation/providers/members_provider.dart';
import '../providers/bible_provider.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';

class BibleBookmarksScreen extends ConsumerWidget {
  const BibleBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text('Favoritos', style: CommunityDesign.titleStyle(context)),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: currentMemberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(
              child: Text('Faça login para ver seus favoritos.'),
            );
          }

          final bookmarksAsync = ref.watch(
            userBibleBookmarksProvider(member.id),
          );
          return bookmarksAsync.when(
            data: (bookmarks) {
              if (bookmarks.isEmpty) {
                return const Center(
                  child: Text('Você ainda não favoritou nenhum versículo.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: bookmarks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(AppIcons.bookmark),
                      title: Text(
                        bookmark.verseReference ?? 'Versículo',
                        style: CommunityDesign.titleStyle(context),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          bookmark.verseText ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: CommunityDesign.contentStyle(context),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(AppIcons.delete),
                        tooltip: 'Remover favorito',
                        onPressed: () async {
                          final repo = ref.read(bibleRepositoryProvider);
                          await repo.deleteBookmark(bookmark.id);
                          ref.invalidate(userBibleBookmarksProvider(member.id));
                        },
                      ),
                      onTap: () async {
                        final repo = ref.read(bibleRepositoryProvider);
                        final verse = await repo.getVerseById(bookmark.verseId);
                        if (verse == null || !context.mounted) return;
                        context.push(
                          '/bible/book/${verse.bookId}/chapter/${verse.chapter}',
                        );
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar favoritos: $error'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erro ao carregar usuário: $error'),
          ),
        ),
      ),
    );
  }
}
