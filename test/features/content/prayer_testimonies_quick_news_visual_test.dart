import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/prayer_requests/domain/models/prayer_request.dart';
import 'package:church360_app/features/prayer_requests/presentation/providers/prayer_request_provider.dart';
import 'package:church360_app/features/prayer_requests/presentation/screens/prayer_request_detail_screen.dart';
import 'package:church360_app/features/prayer_requests/presentation/screens/prayer_request_form_screen.dart';
import 'package:church360_app/features/prayer_requests/presentation/screens/prayer_requests_list_screen.dart';
import 'package:church360_app/features/quick_news/domain/models/quick_news.dart';
import 'package:church360_app/features/quick_news/presentation/providers/quick_news_provider.dart';
import 'package:church360_app/features/quick_news/presentation/screens/quick_news_form_screen.dart';
import 'package:church360_app/features/quick_news/presentation/screens/quick_news_list_screen.dart';
import 'package:church360_app/features/testimonies/domain/models/testimony.dart';
import 'package:church360_app/features/testimonies/presentation/providers/testimony_provider.dart';
import 'package:church360_app/features/testimonies/presentation/screens/testimonies_list_screen.dart';
import 'package:church360_app/features/testimonies/presentation/screens/testimony_form_screen.dart';

final _now = DateTime(2026, 9, 25, 19, 30);

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

QuickNews _quickNews() => QuickNews(
  id: 'quick-1',
  title: 'Aviso da comunidade',
  description: 'Uma atualização importante para a igreja.',
  priority: 2,
  isActive: true,
  expiresAt: _now.add(const Duration(days: 2)),
  createdBy: 'member-1',
  createdAt: _now,
  updatedAt: _now,
);

Testimony _testimony() => Testimony(
  id: 'testimony-1',
  title: 'Deus transformou minha vida',
  description:
      'Este é um testemunho suficientemente longo para aparecer no card.',
  authorId: 'member-1',
  isPublic: true,
  allowWhatsappContact: true,
  createdAt: _now,
  updatedAt: _now,
);

PrayerRequest _prayerRequest() => PrayerRequest(
  id: 'prayer-1',
  title: 'Oração pela família',
  description: 'Peço oração por minha família nesta semana.',
  category: PrayerCategory.family,
  status: PrayerStatus.praying,
  privacy: PrayerPrivacy.public,
  authorId: 'member-1',
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  testWidgets('avisos rápidos usam vidro, status e formulário compartilhados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const QuickNewsListScreen(), [
        allQuickNewsProvider.overrideWith((ref) async => [_quickNews()]),
        currentUserHasPermissionProvider(
          'quick_news.create',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'quick_news.edit',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'quick_news.delete',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.byIcon(AppIcons.flag), findsOneWidget);

    await tester.pumpWidget(
      _host(const QuickNewsFormScreen(), [
        currentUserHasPermissionProvider(
          'quick_news.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.byIcon(AppIcons.save), findsOneWidget);
    expect(find.byIcon(AppIcons.image), findsOneWidget);
  });

  testWidgets('testemunhos usam card e visibilidade semânticos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TestimoniesListScreen(), [
        allTestimoniesProvider.overrideWith((ref) async => [_testimony()]),
        currentUserHasPermissionProvider(
          'testimonies.create',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'testimonies.edit',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'testimonies.delete',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('PÚBLICO'), findsOneWidget);
    expect(find.byIcon(AppIcons.calendar), findsOneWidget);

    await tester.pumpWidget(
      _host(const TestimonyFormScreen(), [
        currentUserHasPermissionProvider(
          'testimonies.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(3));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.save), findsOneWidget);
    expect(find.byIcon(AppIcons.phoneInTalk), findsOneWidget);
  });

  testWidgets(
    'pedidos de oração usam filtros, status e formulários compartilhados',
    (tester) async {
      await tester.pumpWidget(
        _host(const PrayerRequestsListScreen(), [
          allPrayerRequestsProvider.overrideWith(
            (ref) async => [_prayerRequest()],
          ),
          prayerCountProvider('prayer-1').overrideWith((ref) async => 3),
          currentUserHasPermissionProvider(
            'prayer_requests.create',
          ).overrideWith((ref) async => false),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(find.text('EM ORAÇÃO'), findsOneWidget);
      expect(find.byIcon(AppIcons.filterOff), findsOneWidget);

      await tester.pumpWidget(
        _host(const PrayerRequestFormScreen(), [
          currentUserHasPermissionProvider(
            'prayer_requests.create',
          ).overrideWith((ref) async => true),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(2));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.save), findsOneWidget);
      expect(find.byIcon(AppIcons.category), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'detalhe de pedido de oração usa superfícies e ações semânticas',
    (tester) async {
      await tester.pumpWidget(
        _host(const PrayerRequestDetailScreen(prayerRequestId: 'prayer-1'), [
          prayerRequestByIdProvider(
            'prayer-1',
          ).overrideWith((ref) async => _prayerRequest()),
          prayerRequestStatsProvider('prayer-1').overrideWith(
            (ref) async => PrayerRequestStats(
              totalPrayers: 3,
              uniquePrayers: 2,
              hasTestimony: false,
            ),
          ),
          hasUserPrayedProvider('prayer-1').overrideWith((ref) async => false),
          currentMemberProvider.overrideWith((ref) async => null),
          currentUserHasPermissionProvider(
            'prayer_requests.edit',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'prayer_requests.delete',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'prayer_requests.moderate',
          ).overrideWith((ref) async => false),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(3));
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(find.byIcon(AppIcons.favorite), findsAtLeastNWidgets(1));
      expect(find.text('Oração pela família'), findsOneWidget);
    },
  );
}
