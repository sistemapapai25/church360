import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/members/presentation/screens/member_detail_screen.dart';
import '../../features/members/presentation/screens/member_form_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/group_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_detail_screen.dart';
import '../../features/ministries/presentation/screens/ministry_detail_screen.dart';
import '../../features/ministries/presentation/screens/ministry_form_screen.dart';
import '../../features/financial/presentation/screens/contribution_form_screen.dart';
import '../../features/financial/presentation/screens/expense_form_screen.dart';
import '../../features/financial/presentation/screens/financial_goal_form_screen.dart';
import '../../features/financial/presentation/screens/financial_reports_screen.dart';
import '../../features/worship/presentation/screens/worship_services_screen.dart';
import '../../features/worship/presentation/screens/worship_attendance_screen.dart';
import '../../features/worship/presentation/screens/worship_service_form_screen.dart';
import '../../features/worship/presentation/screens/worship_statistics_screen.dart';
import '../../features/visitors/presentation/screens/visitors_list_screen.dart';
import '../../features/visitors/presentation/screens/visitor_form_screen.dart';
import '../../features/visitors/presentation/screens/visitor_details_screen.dart';
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
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import 'route_guard.dart';

/// Configuração de rotas do aplicativo
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isAuthenticated = session != null;
    
    final isSplash = state.matchedLocation == '/splash';
    final isLogin = state.matchedLocation == '/login';
    
    // Se está na splash, deixa passar
    if (isSplash) {
      return null;
    }
    
    // Se não está autenticado e não está no login, redireciona para login
    if (!isAuthenticated && !isLogin) {
      return '/login';
    }
    
    // Se está autenticado e está no login, redireciona para home
    if (isAuthenticated && isLogin) {
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
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/members/new',
      builder: (context, state) => const MemberFormScreen(),
    ),
    GoRoute(
      path: '/members/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberFormScreen(memberId: id);
      },
    ),
    GoRoute(
      path: '/members/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberDetailScreen(memberId: id);
      },
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
    // Rotas de ministérios
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
    // Rotas Financeiras (Coordenador+)
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
      builder: (context, state) => const VisitorFormScreen(),
    ),
    GoRoute(
      path: '/visitors/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorDetailsScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorFormScreen(visitorId: id);
      },
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
      builder: (context, state) => const DevotionalsListScreen(),
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

    // Analytics Dashboard
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboardScreen(),
    ),
  ],
);

