import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/ministries/diaconato/data/diaconato_attendance_repository.dart';
import 'package:church360_app/features/ministries/diaconato/domain/models/diaconato_dashboard_stats.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/providers/diaconato_attendance_providers.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/screens/diaconato_home_screen.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/notifications/data/ministry_notification_config_repository.dart';
import 'package:church360_app/features/ministries/notifications/domain/models/ministry_notification_config.dart';
import 'package:church360_app/features/ministries/notifications/presentation/providers/ministry_notification_config_provider.dart';
import 'package:church360_app/features/ministries/notifications/presentation/screens/ministry_notification_config_screen.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeDiaconatoRepository extends DiaconatoAttendanceRepository {
  _FakeDiaconatoRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<int> dispatchCommunionAssignments() async => 0;
}

class _FakeNotificationRepository extends MinistryNotificationConfigRepository {
  _FakeNotificationRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<MinistryNotificationConfig?> getByMinistry(String ministryId) async =>
      null;
}

Ministry _ministry() {
  final now = DateTime(2026, 9, 21);
  return Ministry(
    id: 'm1',
    name: 'Diaconato',
    description: 'Cuidado e serviço',
    icon: 'church',
    color: '#2563EB',
    isActive: true,
    ministryType: MinistryType.diaconato,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('painel do Diaconato usa cards de vidro e ícones semânticos', (
    tester,
  ) async {
    // O painel é a primeira aba do workspace desde 24/09 (ver o teste do
    // Raízes): a tela não cabe na altura padrão do teste.
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaconatoAttendanceRepositoryProvider.overrideWithValue(
            _FakeDiaconatoRepository(),
          ),
          diaconatoDashboardStatsProvider(
            'm1',
          ).overrideWith((ref) async => DiaconatoDashboardStats.empty),
          ministryByIdProvider('m1').overrideWith((ref) async => _ministry()),
          ministriesCanSeeAllProvider.overrideWith((ref) async => true),
          ministryAccessProvider('m1').overrideWith((ref) async => true),
          currentUserHasPermissionProvider(
            'diaconato.view',
          ).overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DiaconatoHomeScreen(ministryId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.byIcon(AppIcons.factCheck), findsOneWidget);
    expect(find.byIcon(AppIcons.checklist), findsOneWidget);
    expect(find.byIcon(AppIcons.callMissed), findsOneWidget);
    expect(find.byIcon(AppIcons.communion), findsAtLeastNWidgets(2));
  });

  testWidgets('configuração de notificações usa seções de vidro', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ministryNotificationConfigRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MinistryNotificationConfigScreen(
            ministryId: 'm1',
            ministryName: 'Diaconato',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.byIcon(AppIcons.notificationsActive), findsOneWidget);
    expect(find.byIcon(AppIcons.save), findsOneWidget);
    expect(find.text('Ministério: Diaconato'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.tune), findsOneWidget);
  });
}
