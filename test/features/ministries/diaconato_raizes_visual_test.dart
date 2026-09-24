import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/ministries/diaconato/data/diaconato_attendance_repository.dart';
import 'package:church360_app/features/ministries/diaconato/domain/models/worship_attendance.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/providers/diaconato_attendance_providers.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/screens/diaconato_checklist_screen.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/raizes/data/raizes_repository.dart';
import 'package:church360_app/features/ministries/raizes/domain/models/raizes_dashboard_stats.dart';
import 'package:church360_app/features/ministries/raizes/presentation/providers/raizes_dashboard_provider.dart';
import 'package:church360_app/features/ministries/raizes/presentation/screens/raizes_home_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/worship/data/worship_repository.dart';
import 'package:church360_app/features/worship/domain/models/worship_service.dart';
import 'package:church360_app/features/worship/presentation/providers/worship_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _now = DateTime(2026, 9, 21);

Ministry _ministry(MinistryType type) {
  return Ministry(
    id: 'm1',
    name: type == MinistryType.raizes ? 'Raízes' : 'Diaconato',
    description: 'Cuidado e serviço',
    icon: 'church',
    color: '#2563EB',
    isActive: true,
    ministryType: type,
    createdAt: _now,
    updatedAt: _now,
  );
}

class _FakeRaizesRepository extends RaizesRepository {
  _FakeRaizesRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<int> dispatchVisitReminders() async => 0;
}

class _FakeDiaconatoRepository extends DiaconatoAttendanceRepository {
  _FakeDiaconatoRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final count = WorshipAttendanceCount(
    id: 'count-1',
    tenantId: 'tenant-1',
    worshipServiceId: 'service-1',
    ministryId: 'm1',
    serviceDate: _now,
    totalMembersPresent: 0,
    totalRegisteredVisitorsPresent: 0,
    totalUnregisteredVisitors: 0,
    totalPeople: 0,
    createdAt: _now,
    updatedAt: _now,
  );

  @override
  Future<WorshipAttendanceCount> getOrCreateAttendanceCount({
    required String worshipServiceId,
    required String ministryId,
  }) async => count;

  @override
  Future<List<WorshipAttendancePerson>> getPersonRows(
    String attendanceCountId,
  ) async => const [];

  @override
  Future<List<DiaconatoEligiblePerson>> getEligiblePeople() async => const [
    DiaconatoEligiblePerson(
      userId: 'member-1',
      firstName: 'Maria',
      lastName: 'Membro',
      personType: DiaconatoPersonType.member,
    ),
    DiaconatoEligiblePerson(
      userId: 'visitor-1',
      firstName: 'João',
      lastName: 'Visitante',
      personType: DiaconatoPersonType.visitor,
    ),
  ];
}

class _FakeWorshipRepository extends WorshipRepository {
  _FakeWorshipRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<WorshipService?> getWorshipServiceById(String id) async =>
      WorshipService(
        id: 'service-1',
        serviceDate: _now,
        serviceTime: '19:00',
        serviceType: WorshipType.sundayEvening,
        theme: 'Culto de celebração',
        speaker: null,
        totalAttendance: 0,
        notes: null,
        createdAt: _now,
        updatedAt: _now,
      );
}

List<Override> _accessOverrides(String permission, MinistryType type) {
  return [
    ministryByIdProvider('m1').overrideWith((ref) async => _ministry(type)),
    ministriesCanSeeAllProvider.overrideWith((ref) async => true),
    ministryAccessProvider('m1').overrideWith((ref) async => true),
    currentUserHasPermissionProvider(
      permission,
    ).overrideWith((ref) async => true),
  ];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('painel de Raízes usa cards de vidro e ações semânticas', (
    tester,
  ) async {
    // O painel é a primeira aba do workspace desde 24/09: a tela inteira
    // não cabe na altura padrão do teste, e sem isto o `ListView` nem
    // constrói os cards de baixo.
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raizesRepositoryProvider.overrideWithValue(_FakeRaizesRepository()),
          raizesDashboardStatsProvider(
            'm1',
          ).overrideWith((ref) async => RaizesDashboardStats.empty),
          ..._accessOverrides('raizes.view', MinistryType.raizes),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RaizesHomeScreen(ministryId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(7));
    expect(find.byIcon(AppIcons.eventAvailable), findsOneWidget);
    expect(find.byIcon(AppIcons.sponsors), findsOneWidget);
    expect(find.byIcon(AppIcons.recommendations), findsOneWidget);
  });

  testWidgets(
    'checklist do Diaconato usa card, cabeçalho e catálogo semântico',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diaconatoAttendanceRepositoryProvider.overrideWithValue(
              _FakeDiaconatoRepository(),
            ),
            worshipRepositoryProvider.overrideWithValue(
              _FakeWorshipRepository(),
            ),
            ..._accessOverrides(
              'diaconato.manage_attendance',
              MinistryType.diaconato,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DiaconatoChecklistScreen(
              ministryId: 'm1',
              worshipServiceId: 'service-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsAtLeastNWidgets(4));
      expect(find.byIcon(AppIcons.eventFilled), findsOneWidget);
      expect(find.byIcon(AppIcons.groups), findsOneWidget);
      expect(find.byIcon(AppIcons.visitor), findsOneWidget);
    },
  );
}
