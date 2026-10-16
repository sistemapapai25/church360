import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/ministries/diaconato/data/diaconato_attendance_repository.dart';
import 'package:church360_app/features/ministries/diaconato/domain/models/worship_attendance.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/providers/diaconato_attendance_providers.dart';
import 'package:church360_app/features/ministries/diaconato/presentation/screens/diaconato_checklist_screen.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/shared/domain/ministry_type_catalog.dart';
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
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _now = DateTime(2026, 9, 21);

Ministry _ministry(String type) {
  return Ministry(
    id: 'm1',
    name: type == MinistryTypeCodes.raizes ? 'Raízes' : 'Diaconato',
    description: 'Cuidado e serviço',
    icon: 'church',
    color: '#2563EB',
    isActive: true,
    ministryTypeCode: type,
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

  Map<String, DiaconatoPersonType>? saved;

  @override
  Future<WorshipAttendanceCount> saveChecklist({
    required String attendanceCountId,
    required Map<String, DiaconatoPersonType> presentByUser,
    required int totalUnregisteredVisitors,
    int totalChildren = 0,
    String? notes,
  }) async {
    saved = presentByUser;
    return count;
  }

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

  /// Maria fez check-in pelo GPS e ainda não foi validada.
  final validated = <(String, bool)>[];

  @override
  Future<List<WorshipAttendance>> getWorshipAttendance(
    String worshipServiceId,
  ) async => [
    if (validated.isEmpty)
      WorshipAttendance(
        id: 'wa-1',
        worshipServiceId: 'service-1',
        memberId: 'member-1',
        memberName: 'Maria Membro',
        checkedInAt: _now,
        createdAt: _now,
        source: 'geo',
        distanceM: 12,
      ),
  ];

  @override
  Future<void> validateCheckin(
    String worshipServiceId,
    String memberId, {
    required bool ok,
  }) async => validated.add((memberId, ok));

  @override
  Future<WorshipService?> getWorshipServiceById(String id) async =>
      WorshipService(
        id: 'service-1',
        serviceDate: _now,
        serviceTime: '19:00',
        serviceType: WorshipType.sunday,
        theme: 'Culto de celebração',
        speaker: null,
        totalAttendance: 0,
        notes: null,
        createdAt: _now,
        updatedAt: _now,
      );
}

List<Override> _accessOverrides(String permission, String type) {
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
    await tester.binding.setSurfaceSize(const Size(1200, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raizesRepositoryProvider.overrideWithValue(_FakeRaizesRepository()),
          raizesDashboardStatsProvider(
            'm1',
          ).overrideWith((ref) async => RaizesDashboardStats.empty),
          ..._accessOverrides('raizes.view', MinistryTypeCodes.raizes),
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
    'checklist do Diaconato abre em cartas; no fim mostra a lista e o salvar valida o GPS',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final diaconato = _FakeDiaconatoRepository();
      final worship = _FakeWorshipRepository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const DiaconatoChecklistScreen(
              ministryId: 'm1',
              worshipServiceId: 'service-1',
            ),
          ),
          GoRoute(
            path: '/ministries/:id/diaconato/absentees/:eventId',
            builder: (_, _) => const Text('tela de ausentes'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diaconatoAttendanceRepositoryProvider.overrideWithValue(diaconato),
            worshipRepositoryProvider.overrideWithValue(worship),
            ..._accessOverrides(
              'diaconato.manage_attendance',
              MinistryTypeCodes.diaconato,
            ),
            currentUserHasPermissionProvider(
              'worship.attendance',
            ).overrideWith((ref) async => true),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Culto sem checklist salvo abre em cartas; quem fez check-in vem 1º.
      expect(find.textContaining('1 de 2'), findsOneWidget);
      expect(find.textContaining('Check-in pelo GPS'), findsOneWidget);

      await tester.tap(find.byTooltip('Não está aqui')); // Maria, por engano
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Presente')); // Maria
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Presente')); // João
      await tester.pumpAndSettle();
      expect(find.text('2 presentes · 0 ausentes'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsAtLeastNWidgets(4));
      expect(find.byIcon(AppIcons.eventFilled), findsOneWidget);
      expect(find.byIcon(AppIcons.groups), findsWidgets); // Membros e Crianças
      expect(find.byIcon(AppIcons.visitor), findsOneWidget);
      expect(find.text('Check-in pelo celular'), findsOneWidget);
      expect(find.text('Conferir em cartas'), findsOneWidget);

      await tester.tap(find.text('Salvar e ver ausentes'));
      await tester.pumpAndSettle();

      expect(diaconato.saved?.keys.toSet(), {'member-1', 'visitor-1'});
      expect(worship.validated, [('member-1', true)]);
      expect(find.text('tela de ausentes'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // SnackBar sai
    },
  );
}
