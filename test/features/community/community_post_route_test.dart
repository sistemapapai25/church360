import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:church360_app/features/community/data/community_repository.dart';
import 'package:church360_app/features/community/domain/models/community_post.dart';
import 'package:church360_app/features/community/presentation/providers/community_providers.dart';
import 'package:church360_app/features/community/presentation/screens/community_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';

// Comunidade com gancho (D1): o push "Fulano disse…" leva a
// /community/post/:id?comment=1. A tela abre o Mural com a folha de
// comentários do post por cima, o texto do post no topo e a caixa focada.
class _FakeRepo extends CommunityRepository {
  _FakeRepo()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'test-anon-key',
            httpClient: MockClient(
              (request) async => http.Response('[]', 200, request: request),
            ),
            // CHU-321: evita timer pendente do GoTrue em flutter_test.
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<CommunityPost?> getPostById(String id) async => CommunityPost(
        id: id,
        authorId: 'a1',
        content: 'Que culto abençoado foi ontem!',
        type: 'general',
        status: 'approved',
        likesCount: 0,
        createdAt: DateTime(2026, 10, 14),
        updatedAt: DateTime(2026, 10, 14),
        authorName: 'Maria',
      );

  @override
  Future<List<Map<String, dynamic>>> getComments(String postId) async => [];
}

Widget _host({required bool openComment}) {
  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(_FakeRepo()),
      communityPostsProvider.overrideWith((ref) async => const []),
      classifiedsProvider.overrideWith((ref) async => const []),
      birthdaysProvider.overrideWith((ref) async => const []),
      allMembersProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      home: CommunityScreen(initialPostId: 'post-1', openComment: openComment),
    ),
  );
}

void main() {
  testWidgets('rota do post abre a folha com o texto do post e foca a caixa',
      (tester) async {
    await tester.pumpWidget(_host(openComment: true));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // as futures do fake resolvem depois do frame da folha

    expect(find.text('Comentários'), findsOneWidget);
    expect(find.text('Que culto abençoado foi ontem!'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.autofocus, isTrue);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNotNull);
  });

  testWidgets('sem ?comment=1 a folha abre sem focar a caixa', (tester) async {
    await tester.pumpWidget(_host(openComment: false));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // as futures do fake resolvem depois do frame da folha

    expect(find.text('Comentários'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.autofocus, isFalse);
  });
}
