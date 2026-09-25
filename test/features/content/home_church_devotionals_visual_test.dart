import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/church_info/domain/models/church_info.dart';
import 'package:church360_app/features/church_info/presentation/providers/church_info_provider.dart';
import 'package:church360_app/features/church_info/presentation/screens/church_info_screen.dart';
import 'package:church360_app/features/devotionals/domain/models/devotional.dart';
import 'package:church360_app/features/devotionals/presentation/providers/devotional_provider.dart';
import 'package:church360_app/features/devotionals/presentation/screens/devotional_detail_screen.dart';
import 'package:church360_app/features/devotionals/presentation/screens/devotionals_list_screen.dart';
import 'package:church360_app/features/home_content/domain/models/banner.dart';
import 'package:church360_app/features/home_content/presentation/providers/banners_provider.dart';
import 'package:church360_app/features/home_content/presentation/screens/banners_list_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

final _now = DateTime(2026, 9, 25, 19, 30);

HomeBanner _banner() => HomeBanner(
  id: 'banner-1',
  title: 'Culto de Celebração',
  description: 'Uma noite para toda a família.',
  imageUrl: 'https://example.com/banner.png',
  linkUrl: null,
  linkType: 'event',
  linkedId: 'event-1',
  orderIndex: 0,
  isActive: true,
  createdAt: _now,
);

ChurchInfo _churchInfo() => ChurchInfo(
  id: 'church-1',
  name: 'Igreja Church360',
  mission: 'Servir pessoas e anunciar o evangelho.',
  vision: 'Uma igreja viva e acolhedora.',
  values: const ['Fé', 'Amor'],
  address: 'Rua da Paz, 360',
  phone: '11999999999',
  createdAt: _now,
);

Devotional _devotional({bool published = true}) => Devotional(
  id: 'devotional-1',
  title: 'A fé que move montanhas',
  content: 'Deus permanece presente em cada passo da caminhada.',
  scriptureReference: 'Mateus 17:20',
  devotionalDate: _now,
  authorId: 'author-1',
  isPublished: published,
  category: 'domingo',
  preacher: 'Pastor João',
  createdAt: _now,
  updatedAt: _now,
  likesCount: 2,
);

Widget _host(Widget child, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: child),
);

void main() {
  testWidgets('banners usam GlassCard, StatusBadge e ações semânticas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const BannersListScreen(), [
        allBannersProvider.overrideWith((ref) async => [_banner()]),
        currentUserHasPermissionProvider(
          'banners.create',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'banners.edit',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'banners.delete',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.byIcon(AppIcons.eventFilled), findsOneWidget);
  });

  testWidgets('informações da igreja usam GlassCard e catálogo semântico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChurchInfoScreen(), [
        churchInfoProvider.overrideWith((ref) async => _churchInfo()),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(5));
    expect(find.text('Igreja Church360'), findsOneWidget);
    expect(find.byIcon(AppIcons.flag), findsOneWidget);
    expect(find.byIcon(AppIcons.location), findsOneWidget);
  });

  testWidgets('lista de devocionais usa GlassCard, status e AppIcons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DevotionalsListScreen(fromDashboard: true), [
        allDevotionalsIncludingDraftsProvider.overrideWith(
          (ref) async => [_devotional(published: false)],
        ),
        currentUserHasPermissionProvider(
          'devotionals.create',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('RASCUNHO'), findsOneWidget);
    expect(find.byIcon(AppIcons.book), findsAtLeastNWidgets(1));
  });

  testWidgets('detalhe do devocional organiza leitura e impacto em vidro', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DevotionalDetailScreen(devotionalId: 'devotional-1'), [
        devotionalByIdProvider(
          'devotional-1',
        ).overrideWith((ref) async => _devotional(published: false)),
        userDevotionalReadingProvider(
          'devotional-1',
        ).overrideWith((ref) async => null),
        devotionalStatsProvider('devotional-1').overrideWith(
          (ref) async => const DevotionalStats(totalReads: 8, uniqueReaders: 5),
        ),
        currentUserReadingStreakProvider.overrideWith((ref) async => 2),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('A fé que move montanhas'), findsOneWidget);
    expect(find.byIcon(AppIcons.copy), findsOneWidget);
  });
}
