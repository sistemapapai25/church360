import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/members/presentation/screens/members_list_screen.dart';
import '../../features/members/presentation/screens/member_form_screen.dart';
import '../../features/members/presentation/screens/member_profile_screen.dart';
import '../../features/members/domain/models/member.dart';
import '../../features/members/presentation/screens/profile_screen.dart';
import '../../features/qr_scanner/presentation/screens/qr_scanner_screen.dart';
import '../../features/groups/presentation/screens/groups_list_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/group_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_detail_screen.dart';
import '../../features/ministries/presentation/screens/ministries_list_screen.dart';
import '../../features/ministries/presentation/screens/ministry_detail_screen.dart';
import '../../features/ministries/presentation/screens/ministry_form_screen.dart';
import '../../features/financial/presentation/screens/financial_screen.dart';
import '../../features/financial/presentation/screens/contribution_form_screen.dart';
import '../../features/financial/presentation/screens/expense_form_screen.dart';
import '../../features/financial/presentation/screens/financial_goal_form_screen.dart';
import '../../features/financial/presentation/screens/financial_reports_screen.dart';
import '../../features/contribution/presentation/screens/manage_contribution_screen.dart';
import '../../features/worship/presentation/screens/worship_services_screen.dart';
import '../../features/worship/presentation/screens/worship_attendance_screen.dart';
import '../../features/worship/presentation/screens/worship_service_form_screen.dart';
import '../../features/worship/presentation/screens/worship_statistics_screen.dart';
import '../../features/visitors/presentation/screens/visitors_list_screen.dart';
import '../../features/visitors/presentation/screens/visitor_visit_form_screen.dart';
import '../../features/visitors/presentation/screens/visitor_followup_form_screen.dart';
import '../../features/visitors/presentation/screens/visitors_statistics_screen.dart';
import '../../features/access_levels/presentation/screens/access_levels_list_screen.dart';
import '../../features/access_levels/presentation/screens/access_level_history_screen.dart';
import '../../features/devotionals/presentation/screens/devotionals_list_screen.dart';
import '../../features/devotionals/presentation/screens/devotional_detail_screen.dart';
import '../../features/devotionals/presentation/screens/devotional_form_screen.dart';
import '../../features/prayer_requests/presentation/screens/prayer_requests_list_screen.dart';
import '../../features/prayer_requests/presentation/screens/prayer_request_detail_screen.dart';
import '../../features/prayer_requests/presentation/screens/prayer_request_form_screen.dart';
import '../../features/notifications/presentation/screens/notifications_list_screen.dart';
import '../../features/notifications/presentation/screens/notification_preferences_screen.dart';
import '../../features/study_groups/presentation/screens/study_groups_list_screen.dart';
import '../../features/study_groups/presentation/screens/study_group_detail_screen.dart';
import '../../features/study_groups/presentation/screens/study_group_form_screen.dart';
import '../../features/study_groups/presentation/screens/lesson_detail_screen.dart';
import '../../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/schedule/presentation/screens/auto_schedule_generator_screen.dart';
import '../../features/dispatch/presentation/screens/dispatch_config_screen.dart';
import '../../features/schedule/presentation/screens/scale_history_screen.dart';
import '../../features/schedule/presentation/screens/schedule_rules_preferences_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/custom_reports/presentation/screens/custom_reports_list_screen.dart';
import '../../features/custom_reports/presentation/screens/custom_report_builder_screen.dart';
import '../../features/custom_reports/presentation/screens/custom_report_view_screen.dart';
import '../../features/events/presentation/screens/event_form_screen.dart';
import '../../features/events/presentation/screens/event_registration_screen.dart';
import '../../features/church_schedule/presentation/screens/church_schedule_list_screen.dart';
import '../../features/church_schedule/presentation/screens/church_schedule_form_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/courses/presentation/screens/course_form_screen.dart';
import '../../features/courses/presentation/screens/course_lessons_screen.dart';
import '../../features/courses/presentation/screens/course_lesson_form_screen.dart';
import '../../features/courses/presentation/screens/course_viewer_screen.dart';
import '../../features/courses/presentation/screens/lesson_viewer_screen.dart';
import '../../features/church_info/presentation/screens/church_info_screen.dart';
import '../../features/church_info/presentation/screens/church_info_form_screen.dart';
import '../../features/news/presentation/screens/news_screen.dart';
import '../../features/reading_plans/presentation/screens/reading_plans_list_screen.dart';
import '../../features/reading_plans/presentation/screens/reading_plan_detail_screen.dart';
import '../../features/bible/presentation/screens/bible_books_screen.dart';
import '../../features/bible/presentation/screens/bible_chapters_screen.dart';
import '../../features/bible/presentation/screens/bible_reader_screen.dart';
import '../../features/home_content/presentation/screens/banners_list_screen.dart';
import '../../features/home_content/presentation/screens/banner_form_screen.dart';
import '../../features/quick_news/presentation/screens/quick_news_list_screen.dart';
import '../../features/quick_news/presentation/screens/quick_news_form_screen.dart';
import '../../features/testimonies/presentation/screens/testimonies_list_screen.dart';
import '../../features/testimonies/presentation/screens/testimony_form_screen.dart';
import '../../features/support_materials/presentation/screens/support_materials_screen.dart';
import '../../features/support_materials/presentation/screens/support_material_form_screen.dart';
import '../../features/support_materials/presentation/screens/material_modules_screen.dart';
import '../../features/support_materials/presentation/screens/material_viewer_screen.dart';
import '../../features/support_materials/presentation/screens/module_viewer_screen.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/community/presentation/screens/admin/community_admin_screen.dart';
import '../screens/reports/members_report.dart';
import '../screens/reports/events_report_screen.dart';
import '../screens/reports/groups_report_screen.dart';
import '../screens/reports/attendance_report_screen.dart';
import '../screens/reports/upcoming_expenses_report.dart';
import '../screens/reports/upcoming_events_report.dart';
import '../screens/reports/member_growth_report.dart';
import '../screens/reports/events_analysis_report.dart';
import '../screens/reports/active_groups_report.dart';
import '../screens/dashboard_settings_screen.dart';
import '../screens/developer_settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import 'route_guard.dart';
import '../../features/permissions/presentation/widgets/dashboard_access_gate.dart';
import '../../features/permissions/presentation/screens/permissions_screen.dart';
import '../../features/permissions/presentation/screens/roles_list_screen.dart';
import '../../features/permissions/presentation/screens/role_form_screen.dart';
import '../../features/permissions/presentation/screens/role_permissions_screen.dart';
import '../../features/permissions/presentation/screens/contexts_list_screen.dart';
import '../../features/permissions/presentation/screens/context_form_screen.dart';
import '../../features/permissions/presentation/screens/user_roles_list_screen.dart';
import '../../features/permissions/presentation/screens/assign_role_screen.dart';
import '../../features/permissions/presentation/screens/audit_log_screen.dart';
import '../../features/permissions/presentation/screens/permissions_catalog_screen.dart';
import '../../features/permissions/presentation/screens/user_permissions_screen.dart';
import '../../features/kids/presentation/screens/kids_registration_screen.dart';
import '../../features/kids/presentation/screens/kids_admin_dashboard_screen.dart';
import '../../features/kids/presentation/screens/kids_select_child_screen.dart';
import '../../features/support_chat/presentation/screens/agents_center_screen.dart';

/// Configuração de rotas do aplicativo
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    bool isAuthenticated = false;
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      isAuthenticated = session != null;
    } catch (_) {
      isAuthenticated = false;
    }

    final isSplash = state.matchedLocation == '/splash';
    final isLogin = state.matchedLocation == '/login';
    final isSignup = state.matchedLocation == '/signup';

    // Se está na splash, deixa passar
    if (isSplash) {
      return null;
    }

    // Se não está autenticado e não está no login ou signup, redireciona para login
    if (!isAuthenticated && !isLogin && !isSignup) {
      return '/login';
    }

    // Se está autenticado e está no login ou signup, redireciona para home
    if (isAuthenticated && (isLogin || isSignup)) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => const CommunityScreen(),
    ),
    GoRoute(
      path: '/community/admin',
      builder: (context, state) => const DashboardAccessGate(
        child: CommunityAdminScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardAccessGate(
        child: DashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/agents-center',
      builder: (context, state) => const DashboardAccessGate(
        child: AgentsCenterScreen(),
      ),
    ),
    GoRoute(
      path: '/members',
      builder: (context, state) => const MembersListScreen(),
    ),
    GoRoute(
      path: '/members/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final userEmail = extra?['userEmail'] as String?;
        final type = state.uri.queryParameters['type'];
        final status = state.uri.queryParameters['status'];
        return MemberFormScreen(
          initialEmail: userEmail, 
          initialMemberType: type,
          initialStatus: status,
        );
      },
    ),
    GoRoute(
      path: '/members/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberFormScreen(memberId: id);
      },
    ),
    GoRoute(
      path: '/members/:id/profile',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberProfileScreen(memberId: id);
      },
    ),
    GoRoute(
      path: '/members/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        // Padronizando para usar o MemberProfileScreen que é mais completo
        return MemberProfileScreen(memberId: id);
      },
    ),
    // Rota de perfil do usuário
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    // Rota de edição de perfil
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) {
        final member = state.extra as Member;
        // Padronizando para usar o MemberFormScreen que é mais completo
        return MemberFormScreen(memberId: member.id);
      },
    ),
    // Lista de grupos de comunhão
    GoRoute(
      path: '/groups',
      builder: (context, state) => const GroupsListScreen(),
    ),
    GoRoute(
      path: '/groups/new',
      builder: (context, state) => const GroupFormScreen(),
    ),
    GoRoute(
      path: '/groups/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GroupFormScreen(groupId: id);
      },
    ),
    GoRoute(
      path: '/groups/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GroupDetailScreen(groupId: id);
      },
    ),
    // Rotas de reuniões
    GoRoute(
      path: '/groups/:groupId/meetings/new',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MeetingFormScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/meetings/:meetingId/edit',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final meetingId = state.pathParameters['meetingId']!;
        return MeetingFormScreen(groupId: groupId, meetingId: meetingId);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/meetings/:meetingId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final meetingId = state.pathParameters['meetingId']!;
        return MeetingDetailScreen(groupId: groupId, meetingId: meetingId);
      },
    ),
    // Novo visitante de reunião
    GoRoute(
      path: '/groups/:groupId/meetings/:meetingId/visitors/new',
      builder: (context, state) {
        return MemberFormScreen(
          initialStatus: 'visitor',
        );
      },
    ),
    // Rotas de ministérios
    GoRoute(
      path: '/ministries',
      builder: (context, state) => const MinistriesListScreen(),
    ),
    GoRoute(
      path: '/ministries/new',
      builder: (context, state) => const MinistryFormScreen(),
    ),
    GoRoute(
      path: '/ministries/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MinistryFormScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/ministries/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MinistryDetailScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/ministries/:id/auto-scheduler',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AutoScheduleGeneratorScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/ministries/:id/schedule-rules',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ScheduleRulesPreferencesScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/ministries/:id/scale-history',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ScaleHistoryScreen(ministryId: id);
      },
    ),
    // =====================================================
    // ROTAS: FINANCEIRO
    // =====================================================
    GoRoute(
      path: '/financial',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: FinancialScreen(),
      ),
    ),
    GoRoute(
      path: '/contributions/new',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: ContributionFormScreen(),
      ),
    ),
    GoRoute(
      path: '/contributions/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: ContributionFormScreen(contributionId: id),
        );
      },
    ),
    GoRoute(
      path: '/expenses/new',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: ExpenseFormScreen(),
      ),
    ),
    GoRoute(
      path: '/expenses/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: ExpenseFormScreen(expenseId: id),
        );
      },
    ),
    GoRoute(
      path: '/financial-goals/new',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: FinancialGoalFormScreen(),
      ),
    ),
    GoRoute(
      path: '/financial-goals/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: FinancialGoalFormScreen(goalId: id),
        );
      },
    ),
    GoRoute(
      path: '/financial-reports',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: FinancialReportsScreen(),
      ),
    ),
    // Gerenciar Contribuição
    GoRoute(
      path: '/manage-contribution',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: ManageContributionScreen(),
      ),
    ),
    GoRoute(
      path: '/worship-services',
      builder: (context, state) => const WorshipServicesScreen(),
    ),
    GoRoute(
      path: '/worship-services/:id/attendance',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WorshipAttendanceScreen(worshipServiceId: id);
      },
    ),
    GoRoute(
      path: '/worship-services/new',
      builder: (context, state) => const WorshipServiceFormScreen(),
    ),
    GoRoute(
      path: '/worship-services/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WorshipServiceFormScreen(worshipServiceId: id);
      },
    ),
    GoRoute(
      path: '/worship-statistics',
      builder: (context, state) => const WorshipStatisticsScreen(),
    ),
    GoRoute(
      path: '/visitors',
      builder: (context, state) => const VisitorsListScreen(),
    ),
    GoRoute(
      path: '/visitors/statistics',
      builder: (context, state) => const VisitorsStatisticsScreen(),
    ),
    GoRoute(
      path: '/visitors/new',
      builder: (context, state) => const MemberFormScreen(initialStatus: 'visitor'),
    ),
    GoRoute(
      path: '/visitors/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberFormScreen(memberId: id, initialStatus: 'visitor');
      },
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QRScannerScreen(),
    ),
    GoRoute(
      path: '/visitors/:id/visit/new',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorVisitFormScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/followup/new',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorFollowupFormScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/followup/:followupId/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final followupId = state.pathParameters['followupId']!;
        return VisitorFollowupFormScreen(
          visitorId: id,
          followupId: followupId,
        );
      },
    ),

    // =====================================================
    // ROTAS: NÍVEIS DE ACESSO (Apenas Admin)
    // =====================================================
    GoRoute(
      path: '/access-levels',
      builder: (context, state) => const AdminOnlyRoute(
        child: AccessLevelsListScreen(),
      ),
    ),
    GoRoute(
      path: '/access-levels/history',
      builder: (context, state) => const AdminOnlyRoute(
        child: AccessLevelHistoryScreen(),
      ),
    ),
    GoRoute(
      path: '/access-levels/history/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return AdminOnlyRoute(
          child: AccessLevelHistoryScreen(userId: userId),
        );
      },
    ),

    // =====================================================
    // ROTAS: DEVOCIONAIS
    // =====================================================
    GoRoute(
      path: '/devotionals',
      builder: (context, state) {
        final from = state.uri.queryParameters['from'];
        final fromDashboard = from == 'dashboard';
        return DevotionalsListScreen(fromDashboard: fromDashboard);
      },
    ),
    // Gestão (colocar ANTES de '/devotionals/:id' para evitar colisão)
    GoRoute(
      path: '/devotionals/admin',
      builder: (context, state) => CoordinatorOnlyRoute(
        child: const DevotionalsListScreen(fromDashboard: true),
      ),
    ),
    GoRoute(
      path: '/devotionals/new',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: DevotionalFormScreen(),
      ),
    ),
    GoRoute(
      path: '/devotionals/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DevotionalDetailScreen(devotionalId: id);
      },
    ),
    GoRoute(
      path: '/devotionals/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: DevotionalFormScreen(devotionalId: id),
        );
      },
    ),

    // =====================================================
    // ROTAS: PEDIDOS DE ORAÇÃO
    // =====================================================
    GoRoute(
      path: '/prayer-requests',
      builder: (context, state) => const PrayerRequestsListScreen(),
    ),
    GoRoute(
      path: '/prayer-requests/new',
      builder: (context, state) => const PrayerRequestFormScreen(),
    ),
    GoRoute(
      path: '/prayer-requests/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PrayerRequestDetailScreen(prayerRequestId: id);
      },
    ),
    GoRoute(
      path: '/prayer-requests/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PrayerRequestFormScreen(prayerRequestId: id);
      },
    ),

    // =====================================================
    // NOTIFICATIONS ROUTES
    // =====================================================

    // Lista de notificações
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsListScreen(),
    ),

    // Preferências de notificações
    GoRoute(
      path: '/notifications/preferences',
      builder: (context, state) => const NotificationPreferencesScreen(),
    ),

    // ===== STUDY GROUPS =====

    // Lista de grupos de estudo
    GoRoute(
      path: '/study-groups',
      builder: (context, state) => const StudyGroupsListScreen(),
    ),

    // Novo grupo de estudo
    GoRoute(
      path: '/study-groups/new',
      builder: (context, state) => const StudyGroupFormScreen(),
    ),

    // Detalhes do grupo de estudo
    GoRoute(
      path: '/study-groups/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StudyGroupDetailScreen(groupId: id);
      },
    ),

    // Editar grupo de estudo
    GoRoute(
      path: '/study-groups/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StudyGroupFormScreen(groupId: id);
      },
    ),

    // Detalhes da lição
    GoRoute(
      path: '/study-groups/:groupId/lessons/:lessonId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final lessonId = state.pathParameters['lessonId']!;
        return LessonDetailScreen(groupId: groupId, lessonId: lessonId);
      },
    ),

    // ===== SUPPORT MATERIALS =====

    // Lista de materiais de apoio
    GoRoute(
      path: '/support-materials',
      builder: (context, state) => const SupportMaterialsScreen(),
    ),

    // Novo material
    GoRoute(
      path: '/support-materials/new',
      builder: (context, state) => const SupportMaterialFormScreen(),
    ),

    // Editar material
    GoRoute(
      path: '/support-materials/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return SupportMaterialFormScreen(materialId: id);
      },
    ),

    // Visualizar material
    GoRoute(
      path: '/support-materials/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MaterialViewerScreen(materialId: id);
      },
    ),

    // Gerenciar módulos de um material
    GoRoute(
      path: '/support-materials/:id/modules',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final title = state.uri.queryParameters['title'] ?? 'Material';
        return MaterialModulesScreen(materialId: id, materialTitle: title);
      },
    ),

    // Visualizar módulo individual
    GoRoute(
      path: '/support-materials/:materialId/modules/:moduleId',
      builder: (context, state) {
        final materialId = state.pathParameters['materialId']!;
        final moduleId = state.pathParameters['moduleId']!;
        return ModuleViewerScreen(
          materialId: materialId,
          moduleId: moduleId,
        );
      },
    ),

    // Analytics Dashboard
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboardScreen(),
    ),

    // =====================================================
    // ROTAS: AGENDA
    // =====================================================
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
    ),

    // =====================================================
    // ROTAS: AGENDA DA IGREJA
    // =====================================================
    GoRoute(
      path: '/church-schedule',
      builder: (context, state) => const ChurchScheduleListScreen(),
    ),
    GoRoute(
      path: '/church-schedule/new',
      builder: (context, state) => const ChurchScheduleFormScreen(),
    ),
    GoRoute(
      path: '/church-schedule/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ChurchScheduleFormScreen(scheduleId: id);
      },
    ),

    // =====================================================
    // ROTAS: EVENTOS
    // =====================================================
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsListScreen(),
    ),
    GoRoute(
      path: '/events/types',
      builder: (context, state) => const EventTypesManageScreen(),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventDetailScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/new',
      builder: (context, state) => const EventFormScreen(),
    ),
    GoRoute(
      path: '/events/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventFormScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:id/register',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventRegistrationScreen(eventId: id);
      },
    ),

    // =====================================================
    // ROTAS: CURSOS
    // =====================================================
    GoRoute(
      path: '/courses',
      builder: (context, state) {
        // Verifica se veio do Dashboard (query parameter)
        final fromDashboard = state.uri.queryParameters['from'] == 'dashboard';
        return CoursesListScreen(showFab: fromDashboard);
      },
    ),

    // Criar curso
    GoRoute(
      path: '/courses/new',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: CourseFormScreen(),
      ),
    ),

    // Editar curso
    GoRoute(
      path: '/courses/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: CourseFormScreen(courseId: id),
        );
      },
    ),

    // Gerenciar aulas do curso
    GoRoute(
      path: '/courses/:id/lessons',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CoordinatorOnlyRoute(
          child: CourseLessonsScreen(courseId: id),
        );
      },
    ),

    // Criar aula
    GoRoute(
      path: '/courses/:courseId/lessons/new',
      builder: (context, state) {
        final courseId = state.pathParameters['courseId']!;
        return CoordinatorOnlyRoute(
          child: CourseLessonFormScreen(courseId: courseId),
        );
      },
    ),

    // Editar aula
    GoRoute(
      path: '/courses/:courseId/lessons/:lessonId/edit',
      builder: (context, state) {
        final courseId = state.pathParameters['courseId']!;
        final lessonId = state.pathParameters['lessonId']!;
        return CoordinatorOnlyRoute(
          child: CourseLessonFormScreen(
            courseId: courseId,
            lessonId: lessonId,
          ),
        );
      },
    ),

    // Visualizar curso (para alunos)
    GoRoute(
      path: '/courses/:id/view',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CourseViewerScreen(courseId: id);
      },
    ),

    // Visualizar aula (para alunos)
    GoRoute(
      path: '/courses/:courseId/lessons/:lessonId/view',
      builder: (context, state) {
        final courseId = state.pathParameters['courseId']!;
        final lessonId = state.pathParameters['lessonId']!;
        return LessonViewerScreen(
          courseId: courseId,
          lessonId: lessonId,
        );
      },
    ),

    // =====================================================
    // ROTAS: INFORMAÇÕES DA IGREJA
    // =====================================================
    GoRoute(
      path: '/church-info',
      builder: (context, state) => const ChurchInfoScreen(),
    ),
    GoRoute(
      path: '/church-info/manage',
      builder: (context, state) => const ChurchInfoFormScreen(),
    ),

    // =====================================================
    // ROTAS: NOTÍCIAS
    // =====================================================
    GoRoute(
      path: '/news',
      builder: (context, state) => const NewsScreen(),
    ),

    // =====================================================
    // ROTAS: PLANOS DE LEITURA
    // =====================================================
    GoRoute(
      path: '/reading-plans',
      builder: (context, state) => const ReadingPlansListScreen(),
    ),
    GoRoute(
      path: '/reading-plans/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ReadingPlanDetailScreen(planId: id);
      },
    ),

    // =====================================================
    // ROTAS: BANNERS DA HOME
    // =====================================================
    GoRoute(
      path: '/home/banners',
      builder: (context, state) => const BannersListScreen(),
    ),
    GoRoute(
      path: '/home/banners/new',
      builder: (context, state) => const BannerFormScreen(),
    ),
    GoRoute(
      path: '/home/banners/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BannerFormScreen(bannerId: id);
      },
    ),

    // =====================================================
    // ROTAS: FIQUE POR DENTRO (QUICK NEWS)
    // =====================================================
    GoRoute(
      path: '/home/quick-news',
      builder: (context, state) => const QuickNewsListScreen(),
    ),
    GoRoute(
      path: '/home/quick-news/new',
      builder: (context, state) => const QuickNewsFormScreen(),
    ),
    GoRoute(
      path: '/home/quick-news/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return QuickNewsFormScreen(newsId: id);
      },
    ),

    // =====================================================
    // ROTAS: TESTEMUNHOS
    // =====================================================
    GoRoute(
      path: '/home/testimonies',
      builder: (context, state) => const TestimoniesListScreen(),
    ),
    GoRoute(
      path: '/home/testimonies/new',
      builder: (context, state) => const TestimonyFormScreen(),
    ),
    GoRoute(
      path: '/home/testimonies/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TestimonyFormScreen(testimonyId: id);
      },
    ),

    // =====================================================
    // ROTAS: PEDIDOS DE ORAÇÃO (ADMIN - /home/prayer-requests)
    // =====================================================
    GoRoute(
      path: '/home/prayer-requests',
      builder: (context, state) => const PrayerRequestsListScreen(),
    ),
    GoRoute(
      path: '/home/prayer-requests/new',
      builder: (context, state) => const PrayerRequestFormScreen(),
    ),
    GoRoute(
      path: '/home/prayer-requests/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PrayerRequestFormScreen(prayerRequestId: id);
      },
    ),

    // =====================================================
    // ROTAS: BÍBLIA
    // =====================================================
    GoRoute(
      path: '/bible',
      builder: (context, state) => const BibleBooksScreen(),
    ),
    GoRoute(
      path: '/bible/book/:bookId',
      builder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        return BibleChaptersScreen(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/bible/book/:bookId/chapter/:chapter',
      builder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        final chapter = int.parse(state.pathParameters['chapter']!);
        return BibleReaderScreen(bookId: bookId, chapter: chapter);
      },
    ),

    // =====================================================
    // ROTAS: RELATÓRIOS
    // =====================================================
    GoRoute(
      path: '/reports/members',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return MembersReportScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: '/reports/events',
      builder: (context, state) => const EventsReportScreen(),
    ),
    GoRoute(
      path: '/reports/groups',
      builder: (context, state) => const GroupsReportScreen(),
    ),
    GoRoute(
      path: '/reports/attendance',
      builder: (context, state) => const AttendanceReportScreen(),
    ),

    // =====================================================
    // ROTAS: CONFIGURAÇÕES DA DASHBOARD
    // =====================================================
    GoRoute(
      path: '/dashboard-settings',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: DashboardSettingsScreen(),
      ),
    ),

    GoRoute(
      path: '/developer-settings',
      builder: (context, state) => const OwnerOnlyRoute(
        child: DeveloperSettingsScreen(),
      ),
    ),

    // Configuração de Disparos (WhatsApp/Uazapi)
    GoRoute(
      path: '/dispatch-config',
      builder: (context, state) => const CoordinatorOnlyRoute(
        child: DispatchConfigScreen(),
      ),
    ),

    // =====================================================
    // ROTAS: SISTEMA DE PERMISSÕES
    // =====================================================
    GoRoute(
      path: '/permissions',
      builder: (context, state) => const PermissionsScreen(),
    ),
    GoRoute(
      path: '/permissions/roles',
      builder: (context, state) => const RolesListScreen(),
    ),
    GoRoute(
      path: '/permissions/roles/create',
      builder: (context, state) => const RoleFormScreen(),
    ),
    GoRoute(
      path: '/permissions/roles/edit/:roleId',
      builder: (context, state) => RoleFormScreen(
        roleId: state.pathParameters['roleId'],
      ),
    ),
    GoRoute(
      path: '/permissions/roles/:roleId/permissions',
      builder: (context, state) => RolePermissionsScreen(
        roleId: state.pathParameters['roleId']!,
        initialLevel: int.tryParse(state.uri.queryParameters['level'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/permissions/contexts',
      builder: (context, state) => const ContextsListScreen(),
    ),
    GoRoute(
      path: '/permissions/context-form',
      builder: (context, state) {
        final contextId = state.uri.queryParameters['id'];
        return ContextFormScreen(contextId: contextId);
      },
    ),
    GoRoute(
      path: '/permissions/user-roles',
      builder: (context, state) => const UserRolesListScreen(),
    ),
    GoRoute(
      path: '/permissions/users/:userId/permissions',
      builder: (context, state) => UserPermissionsScreen(
        userId: state.pathParameters['userId']!,
      ),
    ),
    GoRoute(
      path: '/permissions/assign-role',
      builder: (context, state) => const AssignRoleScreen(),
    ),
    GoRoute(
      path: '/permissions/audit-log',
      builder: (context, state) => const AuditLogScreen(),
    ),
    GoRoute(
      path: '/permissions/catalog',
      builder: (context, state) => const PermissionsCatalogScreen(),
    ),

    // =====================================================
    // ROTAS: RELATÓRIO DE PRÓXIMAS DESPESAS
    // =====================================================
    GoRoute(
      path: '/upcoming-expenses-report',
      builder: (context, state) => const UpcomingExpensesReportScreen(),
    ),

    // =====================================================
    // ROTAS: RELATÓRIO DE PRÓXIMOS EVENTOS
    // =====================================================
    GoRoute(
      path: '/upcoming-events-report',
      builder: (context, state) => const UpcomingEventsReportScreen(),
    ),

    // =====================================================
    // ROTAS: RELATÓRIO DE CRESCIMENTO DE MEMBROS
    // =====================================================
    GoRoute(
      path: '/member-growth-report',
      builder: (context, state) => const MemberGrowthReportScreen(),
    ),

    // =====================================================
    // ROTAS: RELATÓRIO DE ANÁLISE DE EVENTOS
    // =====================================================
    GoRoute(
      path: '/events-analysis-report',
      builder: (context, state) => const EventsAnalysisReportScreen(),
    ),

    // =====================================================
    // ROTAS: RELATÓRIO DE GRUPOS ATIVOS
    // =====================================================
    GoRoute(
      path: '/active-groups-report',
      builder: (context, state) => const ActiveGroupsReportScreen(),
    ),

    // =====================================================
    // ROTAS: MÓDULO KIDS
    // =====================================================
    GoRoute(
      path: '/kids-registration',
      builder: (context, state) => const KidsSelectChildScreen(),
    ),
    GoRoute(
      path: '/kids',
      builder: (context, state) => const KidsAdminDashboardScreen(),
    ),
    GoRoute(
      path: '/kids/:childId/registration',
      builder: (context, state) {
        final childId = state.pathParameters['childId']!;
        final childName = state.uri.queryParameters['name'] ?? 'Criança';
        return KidsRegistrationScreen(
          childId: childId,
          childName: childName,
        );
      },
    ),

    // =====================================================
    // ROTAS: RELATÓRIOS CUSTOMIZADOS
    // =====================================================
    GoRoute(
      path: '/custom-reports',
      builder: (context, state) => const CustomReportsListScreen(),
    ),
    GoRoute(
      path: '/custom-reports/new',
      builder: (context, state) => const CustomReportBuilderScreen(),
    ),
    GoRoute(
      path: '/custom-reports/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomReportBuilderScreen(reportId: id);
      },
    ),
    GoRoute(
      path: '/custom-reports/:id/view',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomReportViewScreen(reportId: id);
      },
    ),
  ],
);
