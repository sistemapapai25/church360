import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/community/domain/models/community_post.dart';
import 'package:church360_app/features/community/presentation/providers/community_providers.dart';
import 'package:church360_app/features/community/presentation/screens/admin/community_admin_screen.dart';
import 'package:church360_app/features/community/presentation/screens/community_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';

void main() {
  testWidgets('mural vazio mantém estado e ícone semântico', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityPostsProvider.overrideWith((ref) async => const []),
          classifiedsProvider.overrideWith((ref) async => const []),
          birthdaysProvider.overrideWith((ref) async => const []),
          allMembersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Ainda não há publicações.'), findsOneWidget);
    expect(find.byIcon(AppIcons.article), findsOneWidget);
  });

  testWidgets('moderação usa GlassCard e catálogo de ações', (tester) async {
    final post = CommunityPost(
      id: 'post-1',
      authorId: 'author-1',
      content: 'Pedido de oração para a comunidade',
      type: 'prayer_request',
      status: 'pending_approval',
      likesCount: 0,
      createdAt: DateTime(2026, 9, 22, 10),
      updatedAt: DateTime(2026, 9, 22, 10),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingPostsProvider.overrideWith((ref) async => [post]),
          pendingClassifiedsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const CommunityAdminScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byIcon(AppIcons.pending), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.text('Pedido de oração para a comunidade'), findsOneWidget);
  });
}
